#!/usr/bin/env perl

# @file r-parallel-worker.pl 
# @brief Worker script for run-parallel.sh.
#
# This is a generic worker program that requests a command and executes
# it when done exits
#
# @author Patrick Paul and Eric Joanis
#
# COMMENTS:
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2005, Sa Majeste la Reine du Chef du Canada /
# Copyright 2005, Her Majesty in Right of Canada

# We don't bother printing a Copyright here because this script is inherently
# internal -- it is never called on its own.

use strict;
use warnings;

use Getopt::Long;
require 5.002;
use Socket;
use File::Temp qw(tempfile);

# validate parameters
my $host = '';
my $port = '';
my $help = '';
my $quota = 30; # in minutes
my $primary = 0;
my $netcat_mode = 0;
my $silent = 0;
my $subst;
my $mon;
my $mon_period;

GetOptions ("host=s"   => \$host,
            "port=i"   => \$port,
            help       => \$help,
            h          => \$help,
            silent     => \$silent,
            "quota=i"  => \$quota,
            primary    => \$primary,
            netcat     => \$netcat_mode,
            "subst=s"  => \$subst,
            "mon=s"    => \$mon,
            "period=i" => \$mon_period,
            );

$primary and $quota = 0;

if($help ne ''){
    PrintHelp();
    exit (0);
}

my $me = `uname -n`;
chomp $me;
$me =~ s/(.)\..*/$1/; # Remove domain qualifier - unqualified host name is enough info
$me .= ":" . ($ENV{JOB_ID} || "");
my $need_sleep = ($me =~ /balzac/);
$me =~ s/(\d)\..*/$1/; # Remove domain qualifier from job number too, superfluous

if ( $primary ) { $me = "Primary $me"; }

sub exit_with_error{
   my $error_string = shift;
   print STDERR "[" . localtime() . "] ($me) ", $error_string, "\n";
   exit(-1);
}

sub log_msg(@) {
   if ( !$silent ) {
      print STDERR "[" . localtime() . "] ($me) ", @_, "\n";
   }
}

# Return a random integer in the range [$min, $max).
#srand(0); # predictable for testing
srand(time() ^ ($$ + ($$ << 15))); # less predictable, for normal use
sub rand_in_range($$) {
   my ($min, $max) = @_;
   return int(rand ($max-$min)) + $min;
}

exit_with_error("Missing mandatory argument 'host' see --help") unless $host ne '';
exit_with_error("Missing mandatory argument 'port' see --help") unless $port ne '';

# Replace netcat by a regular Perl socket
my $iaddr = inet_aton($host) or exit_with_error("No such host: $host");
my $paddr = sockaddr_in($port, $iaddr);
my $proto = getprotobyname('tcp');
# send_recv($message) send $message to the daemon.  daemon's reply is returned
# by send_recv.
sub send_recv($) {
   my $message = shift;
   socket(SOCK, PF_INET, SOCK_STREAM, $proto)
      or exit_with_error("Can't create socket: $!");
   connect(SOCK, $paddr) or do {
      if ( $message =~ /^(GET|SIGNALED)/ ) { return ""; }
      exit_with_error("Can't send message \"$message\" to daemon (daemon probably exited): $!");
   };
   select SOCK; $| = 1; select STDOUT; # set autoflush on SOCK
   print SOCK $message, "\n";
   local $/; undef $/;
   my $reply = <SOCK>;
   close SOCK;
   defined $reply or $reply = "";
   return $reply;
}

#
# Special case: in -netcat mode, we just send and read one line and exit
#
if ( $netcat_mode ) {
   my $line = <STDIN>;
   if ( defined $line ) {
      print send_recv $line;
   } else {
      exit_with_error("No message to send!");
   }
   exit;
}

#
# User requested a systematic substitution on commands before running them
#
my ($subst_match, $subst_replacement);
if ( defined $subst ) {
   ($subst_match, $subst_replacement) = split "/", $subst, 2;
   if ( ! defined $subst_replacement ) {
      exit_with_error("Illegal value for -subst option: $subst");
   }
}

#
# Algorithm: Until we receive "***EMPTY***" request a command, run it,
#            acknowledge completion
#

log_msg "Starting $0";

my $start_time = time;
my $reply_rcvd = send_recv "GET ($me)";
chomp $reply_rcvd;

my $sleeping = 0;
sub report_signal($) {
   log_msg "Caught signal $_[0].";
   if ($sleeping) {
      log_msg "Currently sleeping, ignoring repeated signal";
   } else {
      send_recv "SIGNALED ($me) ***(rc=$_[0])*** (signal=$_[0]) $reply_rcvd";
      if (1) {
         log_msg "Sleeping 20 seconds to give children time to clean up.";
         $sleeping = 1;
         sleep 20;
         $sleeping = 0;
      } elsif ( $_[0] == 10 ) {
         my $delay = int(rand(5));
         log_msg "Caught signal USR1 (10); sleeping $delay seconds and aborting job";
         $sleeping = 1;
         sleep $delay;
         $sleeping = 0;
      } elsif ( $_[0] == 12 ) {
         my $delay = int(rand(10));
         log_msg "Caught signal USR2 (12); sleeping $delay seconds and aborting job";
         $sleeping = 1;
         sleep $delay;
         $sleeping = 0;
      }
      log_msg "Caught signal $_[0]. Aborting job";
      exit;
   }
}

my $mon_pid;
if ( $mon ) {
   # EJJ June 2010: not so elegant to write the child PID to a temp file, but
   # this solution is reliable even when /bin/sh is not bash.
   my ($fh, $filename) = tempfile();
   system("/bin/bash", "-c", "set -m; process-memory-usage.pl -s 1 $mon_period $$ > $mon & echo -n \$! > $filename");
   $mon_pid = `cat $filename`;
   close($fh);
   unlink($filename);

   # EJJ June 2010: this solution is more elegant at first glance, but then we
   # have to worry about reaping the child process and various other problems.
   # It's simplest to have bash handle these things, since it does it so well
   # already.
   #my $parent_pid = $$;
   #my $child_pid = fork();
   #if ( $child_pid != 0 ) {
   #   # In parent process
   #   $mon_pid = $child_pid;
   #} else {
   #   # In child process
   #   exec("/bin/bash", "-c", "process-memory-usage.pl -s 1 60 $parent_pid > $mon");
   #}

   # EJJ June 2010: this solution works find when /bin/sh is bash, but not when
   # it's dash, such as with Debian and Ubuntu.
   #$mon_pid = `set -m; process-memory-usage.pl -s 1 60 $$ > $mon & echo -n \$!`;
   #log_msg "Monitor PID $mon_pid";
}

$SIG{INT} = sub { report_signal(2) };
$SIG{QUIT} = sub { report_signal(3) };
$SIG{USR1} = sub { report_signal(10) };
$SIG{USR2} = sub { report_signal(12) };
$SIG{TERM} = sub { report_signal(15) };

while(defined $reply_rcvd and $reply_rcvd !~ /^\*\*\*EMPTY\*\*\*/i
         and $reply_rcvd ne ""){
   log_msg "Executing $reply_rcvd";
   my ($job_id, $job_command) = split / /, $reply_rcvd, 2;
   my $exit_status;
   if (!defined $job_id or $job_id !~ /^\(\d+\)$/ or !defined $job_command) {
      log_msg "Received ill-formatted command: $reply_rcvd";
      $exit_status = -2;
   } else {
      if ( defined $subst ) {
         $job_command =~ s/\Q$subst_match\E/\Q$subst_replacement\E/go;
         log_msg "Substitued command: $job_command";
      }
      # EJJ June 2010: explicitly use /bin/bash, in case sh!=bash (e.g., on
      # Ubuntu and Debian)
      my $rc = system("/bin/bash", "-c", $job_command);
      #my $rc = system($job_command);
      if ( $rc == -1 ) {
         log_msg "System return code = $rc, means couldn't start job: $!";
         $exit_status = -1;
      } elsif ( $rc & 127 ) {
         log_msg "System return code = $rc, ",
                 "means job died with signal ", ($rc & 127), ". ",
                 ($rc & 128 ? 'with' : 'without'), " coredump";
         $exit_status = -1;
      } else {
         # regular exit status from program is $rc >> 8, as documented in
         # "perldoc -f system"
         $exit_status = $rc >> 8;
         log_msg "Exit status $exit_status";
      }
   }
   my $error_string = $exit_status ? "***" : "";
   if ( $quota > 0 and (time - $start_time) > $quota*60 ) {
      # Done my share of work, request a relaunch
      send_recv "DONE-STOPPING ($me) $error_string(rc=$exit_status)$error_string $reply_rcvd";
      last;
   } else {
      my $response = send_recv "DONE ($me) $error_string(rc=$exit_status)$error_string $reply_rcvd";
      if ($response =~ /^ALLSTARTED/) {
         log_msg "Server said ALLSTARTED; stopping.";
         last;
      }
      $reply_rcvd = send_recv "GET ($me)";
   }
}

if ($need_sleep and !$primary and (time - $start_time) < 60) {
   # Super short jobs are not cluster friendly, especially not arrays of them
   my $seconds = rand_in_range 5, 30;
   log_msg "Job too short - sleeping $seconds seconds before exiting.";
   sleep $seconds;
}

if ( $mon_pid ) {
   kill(10, $mon_pid);
   #log_msg("Killed monitor process $mon_pid");
}

log_msg "Done.";



sub PrintHelp{
print <<'EOF';
  r-parallel-worker.pl

  This script is a generic worker script. It is meant to be used in
  conjunction with:
    - /utils/run-parallel.sh (script invoked by user)
    - /utils/r-parallel-d.sh (daemon invoked by run-parallel.sh)

  The motivation for this trio of scripts is to allow exclusive access to a
  file to guarantee consistent lock of a file while using NFS as the underlying
  filesystem. The problem with NFS is the caching feature of the clients and
  the delay between a write request completion and the actual write to physical
  disk in conjunction with another read access while the data is still not
  available.

  When multiple process tries to lock a file on an NFS mounted file, it seems
  that the locking mechanism guarantees consistency of the file being accessed.

  The idea is that r-parallel-d.pl prepares things so that when a "GET" message
  arrives on given TCP port, the next instruction is sent back for execution.

  Prerequesite: having a server on a host listening on a port that reply an
                executable command when it receives the message "GET". This
                same server should accept a command of the form
                "DONE WithSOmeSortOfMessageHere".

  Behaviour: When the program receives ***EMPTY*** this means that the server
             has nothing else to dispatch so we gracefully exits.

 syntax:
    r-parallel-worker.pl [options] --host=SomeHost --port=SomePort
 arguments:
    host=SomeHost: hostname to contact to get an instruction
    port=SomePort: The port on which to send requests
 options:
    -help     print this help message
    -silent   don't print log messages
    -quota T  The number of minutes this worker should work before
              requesting a relaunch from the daemon [30] (0 means never
              relaunch, i.e., work until there is no more work.)
    -primary  Indicates this worker is the primary one and should not be
              stopped on a quench request (implies -quota 0)
    -netcat   Just act like a simple netcat, sending the first line from STDIN
              to host:port and printing the response to STDOUT.
    -subst MATCH/REPLACEMENT replaces MATCH by REPLACEMENT in every command
              received before executing it.
    -mon FILE Run process-memory-usage.pl on self, saving output into FILE
    -period P Sleep for P seconds between monitoring samples. [60]

EOF
}

