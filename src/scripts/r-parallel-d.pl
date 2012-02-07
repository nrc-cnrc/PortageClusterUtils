#!/usr/bin/env perl
# $Id$
#
# @file r-parallel-d.pl 
# @brief This script is used in conjuction with r-parallel-worker.pl, and
# run-parallel.sh.  It accepts connections on a specific port and returns
# commands to executed when asked.
#
# This script replaces our former faucet/faucet.pl: r-parallel-d.pl is the
# full daemon, receiving requests via a socket and handling them directly,
# without forking (an exclusive lock would be required around the whole fork,
# so there is no gain in speed and only a cost in complication) and without
# launching a new process.  Another big advantage of this daemon is that its
# variables will be in memory rather than on disk, as had to be the case with
# faucet.pl.  Turn around time for workers requesting jobs should now be
# measures in milliseconds rather than in seconds.
#
# @author Eric Joanis, based on faucet.pl and faucet_launcher.sh, written
# by Patrick Paul and Eric Joanis
#
# COMMENTS:
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2005-2007, Sa Majeste la Reine du Chef du Canada /
# Copyright 2005-2007, Her Majesty in Right of Canada

# We don't bother printing a Copyright here because this script is inherently
# internal -- it is never called on its own.

use strict;
use warnings;
use threads;  # We need threads to monitor a pid;
use Getopt::Long;
use Socket;
use IO::Handle;
# Extract the debugging flag from the environment.
use Env qw(R_PARALLEL_D_PL_DEBUG);  # For easier debugging
use Env qw(R_PARALLEL_D_PL_SLEEP_TIME);  # Allows to change the sleep time from 60 to whatever the user wants.
STDERR->autoflush(1);

#FILE_PREFIX=$1;
#JOBS_FILENAME=$FILE_PREFIX.jobs;

$0 =~ s#.*/##;

sub log_msg(@) {
   print STDERR "[" . localtime() . "] @_\n";
}

my $port_file;
sub exit_with_error(@) {
   log_msg "$0 FATAL ERROR:", @_;
   if ( $port_file ) {
      open PORT_FILE, ">$port_file" and
      print PORT_FILE "FAIL\n";
      close PORT_FILE;
   }
   exit(1);
}

# Function for a thread that monitors the presence of PPID and exits if that
# PPID disappears.
sub look_for_process {
   my $process_id = shift || die "You need to provide a PPID!";
   my $sleep_time = shift || 60;
   print STDERR "Starting monitoring thread for ppid: $process_id sleep=$sleep_time\n" if(defined($R_PARALLEL_D_PL_DEBUG));
   while (1) {
      print STDERR "Checking for PPID: $process_id\n" if(defined($R_PARALLEL_D_PL_DEBUG));
      unless(kill 0, $process_id) {
         print STDERR "PPID: $process_id is no longer available, quitting...";
         exit 55;
      }
      sleep($sleep_time);
   }
}

GetOptions (
   "help"               => sub { PrintHelp() },
   "on-error=s"         => \my $on_error,
   "bind=i"             => \my $process_id,
) or exit_with_error "Type -help for help.\n";

my $stop_on_error = defined $on_error && $on_error eq "stop";
my $killall_on_error = defined $on_error && $on_error eq "killall";

# validation: number of command line arguments
if ( @ARGV < 1 ) {
   exit_with_error "Missing mandatory arguments InitNumWorkers and FilePrefix.";
} elsif ( @ARGV < 2 ) {
   exit_with_error "Missing mandatory argument InitNumWorkers or FilePrefix.";
} elsif ( @ARGV > 2 ) {
   exit_with_error "Extraneous arguments.";
}

my $num_workers = shift;
my $file_prefix = shift;
$port_file = "$file_prefix/port";

# validation: num_workers must be a number > 0
if ( ($num_workers + 0) ne $num_workers or $num_workers <= 0 ) {
   exit_with_error "Invalid value for InitNumWorkers: $num_workers; must be a positive integer.";
}

# Return a random integer in the range [$min, $max).
#srand(0); # predictable for testing
srand(time() ^ ($$ + ($$ << 15))); # less predictable, for normal use
sub rand_in_range($$) {
   my ($min, $max) = @_;
   return int(rand ($max-$min)) + $min;
}

# Read job file and store in an array.
open JOBFILE, "$file_prefix/jobs"
   or exit_with_error "Can't open $file_prefix/jobs: $!";
my @jobs = <JOBFILE>;
close JOBFILE;

# State variables
my $add_count = 0;      # gets used when an ADD request comes in
my $quench_count = 0;   # gets used when a QUENCH request comes in
my $job_no = 0;         # next job number to launch, as an index into @jobs
my $done_count = 0;     # number of jobs done so far
my $num = @jobs;        # job count in a conveniently scalar variable
my @return_codes;       # return codes from all the jobs

# File that will contain all the return codes from the jobs
open (RCFILE, "> $file_prefix/rc")
   or exit_with_error("can't open $file_prefix/rc: $!");
select RCFILE; $| = 1; select STDOUT;

# If required, monitor the existence of PPID.
# We don't need any result from the thread thus we will detach from it and
# ignore it.
threads->create('look_for_process', $process_id, $R_PARALLEL_D_PL_SLEEP_TIME)->detach if (defined($process_id));

# This while(1) loop tries to open the listening socket until it succeeds
while ( 1 ) {
   my $port = rand_in_range 10000, 25000;
   my $proto = getprotobyname('tcp');
   socket(Server, PF_INET, SOCK_STREAM, $proto) or exit_with_error "$0 socket: $!";
   setsockopt(Server, SOL_SOCKET, SO_REUSEADDR, pack("l", 1))
      or exit_with_error "$0 setsockopt: $!";
   bind(Server, sockaddr_in($port, INADDR_ANY)) or do {
      if ( $!{"EADDRINUSE"} ) {
         log_msg "port $port already in use,", "trying another one";
         next;
      }
      exit_with_error "$0 bind: $!";
   };
   listen(Server, SOMAXCONN) or exit_with_error "$0 listen: $!";

   log_msg "started listening on port $port";

   open PORT_OUT, ">$port_file"
      or exit_with_error "$0 can't open port file $port_file: $!";
   print PORT_OUT "$port\n";
   close PORT_OUT or exit_with_error "$0 can't close port file $port_file: $!";
   last;
}

# This for loop receives and handles connections until all work is done
my $paddr;
for ( ; $paddr = accept(Client, Server); close Client) {

   # Add one worker now if an add request is in progress
   if ( $add_count > 0 ) {
      log_msg "adding workers ($add_count)";
      LaunchOneMoreWorker();
      --$add_count;
   }

   my ($port, $iaddr) = sockaddr_in($paddr);
   my $name = gethostbyaddr($iaddr, AF_INET) || "localhost";
   my $string_address = inet_ntoa($iaddr) || "LOCAL";
   log_msg "rcvd conn from $name [" . $string_address . ":$port]";

   my $cmd_rcvd = <Client>;
   select Client; # Make the socket the default "file" to write to.
   if (defined $cmd_rcvd) {
      chomp $cmd_rcvd;
      if ($cmd_rcvd =~ /^PING/i) {
         log_msg $cmd_rcvd;
         print "PONG\n";
      } elsif ($cmd_rcvd =~ /^ADD (\d+)/i) {
         log_msg $cmd_rcvd;
         $add_count += $1;
         if ( $add_count > 0 ) {
            log_msg "adding workers ($add_count)";
            LaunchOneMoreWorker();
            --$add_count;
         }
         print "ADDED\n";
      } elsif ($cmd_rcvd =~ /^QUENCH (\d+)/i) {
         log_msg $cmd_rcvd;
         $quench_count += $1;
         print "QUENCHED\n";
      } elsif ($cmd_rcvd =~ /^KILL/i) {
         log_msg $cmd_rcvd;
         print "KILLED\n";
         close Client;
         exit 2;
      } elsif ($cmd_rcvd =~ /^GET/i) {
         log_msg $cmd_rcvd;
         if ( $cmd_rcvd !~ /GET \(PRIMARY/i and $quench_count > 0 ) {
            # dynamic quench in progress, stop this (non-primary) worker
            --$quench_count;
            log_msg "quenching ($quench_count)";
            --$num_workers
         } else {
            # send the next command for execution
            if ( $job_no < $num ) {
               ++$job_no;
               print "($job_no) $jobs[$job_no-1]";
               my $trimmed_job = $jobs[$job_no-1];
               $trimmed_job =~ s/\s+/ /g;
               #if ( length($trimmed_job) > 38 ) {
               #   $trimmed_job = substr($trimmed_job, 0, 35) . "...";
               #}
               my $worker_id = $cmd_rcvd;
               $worker_id =~ s/\s*GET\s*//i;
               log_msg "starting $worker_id ($job_no) $trimmed_job";
            } else {
               print "***EMPTY***\n";
               log_msg "returning: ***EMPTY***";
               --$num_workers
            }
         }
      } elsif ($cmd_rcvd =~ /^DONE|^SIGNALED/i) {
         if ( $cmd_rcvd =~ /^DONE-STOPPING|^SIGNALED/i ) {
            --$num_workers;
         }
         ++$done_count;
         my $trimmed_cmd_rcvd = $cmd_rcvd;
         $trimmed_cmd_rcvd =~ s/\s+/ /g;
         log_msg "$done_count/$num $trimmed_cmd_rcvd";

         if ( $job_no < $done_count ) {
            log_msg "Something strange is going on: more jobs done",
                    "($done_count/$num) than started ($job_no)..."
         }

         # Write the return code of the job (shown as "(rc=NN)" on the "DONE"
         # command) to the .rc file
         my ($rc) = ($cmd_rcvd =~ /\(rc=(-?\d+)\)/);
         defined $rc or $rc = -127;
         push @return_codes, $rc;
         print RCFILE "$rc\n";

         if ( $rc != 0 ) {
            if ( $stop_on_error ) {
               # Don't laurch any further jobs, accomplished by pretending
               # the jobs that aren't launched yet never existed.
               $num=$job_no;
               log_msg "Non-zero exit status, not launching any further jobs.";
            } elsif ( $killall_on_error ) {
               # Abort now, all workers will get killed
               log_msg "Non-zero exit status, aborting and killing workers.";
               close Client;
               exit 0;
            }
         }
         if ( $done_count >= $num ) {
            # If all done, exit
            log_msg "ALL_DONE ($done_count/$num): Killing daemon";
            if ( $num_workers > 0 ) {
               log_msg "$num_workers remaining workers will be killed.";
            }
            close Client;
            exit 0;
         } elsif ($cmd_rcvd =~ /^DONE-STOPPING/i and $job_no < $num) {
            # We're not done, but the worker is stopping, so launch
            # another one
            LaunchOneMoreWorker();
         }
      } else {
         #report as an error
         print "UNKNOWN COMMAND\n";
         log_msg "UNKNOWN COMMAND received: $cmd_rcvd";
      }
   } else {
      print "NO COMMAND\n";
      log_msg "EMPTY: received nothing";
   }

   if ( $num_workers < 1 ) {
      log_msg "No more workers, exiting.";
      if ( $job_no < $num ) {
         log_msg "Some jobs were not submitted for execution.";
         exit 0;
      } elsif ( $done_count < $num ) {
         log_msg "Mysteriously, there are no workers left but some jobs are apparently still running.";
         exit 1;
      } else {
         log_msg "Mysteriously, all jobs are done but we didn't exit yet.";
         exit 1;
      }
   }
}


my $psub_cmd;
my $worker_id;
sub LaunchOneMoreWorker {
   if ( ! defined $psub_cmd || ! defined $worker_id ) {
      # Read the psub command and the next worker id, needed to launch
      # more workers.  But do so only the first time needed, after that
      # reuse the values kept in memory.
      $psub_cmd = `cat $file_prefix/psub_cmd`; chomp $psub_cmd;
      $worker_id = `cat $file_prefix/next_worker_id`; chomp $worker_id;
   }
   my $psub_cmd_copy = $psub_cmd;
   $psub_cmd_copy =~ s/__WORKER__ID__/$worker_id/g;
   log_msg "Launching worker $worker_id";
   my $rc = system($psub_cmd_copy);
   $rc == 0 or log_msg "Error launching worker.  RC = $rc.  ",
                       "Command was:\n    $psub_cmd_copy";
   ++$worker_id;
   ++$num_workers;
}

sub PrintHelp {
   print <<'EOF';
Usage: r-parallel-d.pl [-bind <PPID>] [-on-error <action>]
           InitNumWorkers FilePrefix

  This daemon accepts connections on a randomly selected port and hands
  out the jobs in FilePrefix.jobs one at a time when GET requests are
  received.

Argument:

  InitNumWorkers - numbers of workers to be launched by run-parallel.sh

     Used to manage errors - if at some point there are still jobs to execute,
     but all workers have died or have been killed, the daemon will exit.

  FilePrefix - prefix of various argument files:

     FilePrefix.jobs - list of jobs to run, one per line
     Must exist before this script is called.

     FilePrefix.psub_cmd - command to run to launch more workers, with
     __WORKER__ID__ as a placeholder for the worker number.
     FilePrefix.worker - next worker number
     These two files may be created after this script has started, but must
     exist before requests involving new workers are made to this daemon.

     FilePrefix.port - will be created by this script and contain the port
     it listens on, as soon as this port is open for connections.

     FilePrefix.rc - will be created by this script, it will contain the
     return code from each job, in the order they finished (which is not
     necessarily the order they started).

Option:

  -bind <PPID>       - monitors the presence of PPID and exits if PPID is no
                       longer present.

  -on-error <action> - see run-parallel.sh for valid actions and their meaning.

Notes:
  You can define some environment variables to change r-parallel-d.pl's behavior.
  - Define R_PARALLEL_D_PL_SLEEP_TIME=<seconds> to change the default 60
    seconds for the watchdog thread;
  - Define R_PARALLEL_D_PL_DEBUG to add some debugging statement.

Return status:

  0 - success
  1 - problem
  2 - exited because a KILL message was received

Valid messages -- response:

  GET  -- The first job not started yet is written back on the socket, or
          ***EMPTY*** if all jobs have started, to tell the worker to quit.

  DONE -- Increments the jobs-done counter.  When all jobs are done, exits and
          let run-parallel.sh clean up and exit.

  DONE-STOPPING -- Same as DONE, but the worker is exiting, a new worker is
          launched to replace it, and will find itself at the end of the PBS
          queue, thus allowing other jobs to run in between.  The new
          worker is launched using the command in FilePrefix.psub_cmd.

  ADD <N> -- Request to add more workers, results in the command in
          FilePrefix.psub_cmd being executed <N> times.

  QUENCH <N> -- Request to quench workers, results in the next <N> workers
          requesting jobs being told there are none left.

  KILL -- Request to stop the daemon, makes it exit now, letting
          run-parallel.sh clean up.

  PING -- PONG

EOF

   exit 0;
}

