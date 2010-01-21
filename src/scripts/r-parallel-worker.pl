#!/usr/bin/perl -w
# $Id$

# @file r-parallel-worker.pl 
# @brief This is a generic worker program that requests a command and executes
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

use strict;

use Getopt::Long;
require 5.002;
use Socket;

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
            );

$primary and $quota = 0;

if($help ne ''){
    PrintHelp();
    exit (-1);
}

my $me = `uname -n`;
chomp $me;
$me .= ":" . ($ENV{PBS_JOBID} || "");
$me =~ s/balzac.iit.nrc.ca/balzac/;

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

exit_with_error("Missing mandatory argument 'host' see --help") unless $host ne '';
exit_with_error("Missing mandatory argument 'port' see --help") unless $port ne '';

# Replace netcat by a regular Perl socket
my $iaddr = inet_aton($host) or exit_with_error("No such host: $host");
my $paddr = sockaddr_in($port, $iaddr);
my $proto = getprotobyname('tcp');
# send_recv($message) send $message to the deamon.  deamon's reply is returned
# by send_recv.
sub send_recv($) {
   my $message = shift;
   socket(SOCK, PF_INET, SOCK_STREAM, $proto)
      or exit_with_error("Can't create socket: $!");
   connect(SOCK, $paddr) or exit_with_error("Can't connect to socket: $!");
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

my $start_time = time;
my $reply_rcvd = send_recv "GET ($me)";
chomp $reply_rcvd;

sub report_signal($) {
   log_msg "Caught signal $_[0], Aborting job";
   send_recv "SIGNALED ($me) (rc=$_[0]) $reply_rcvd";
   exit;
}

my $mon_pid;
if ( $mon ) {
   $mon_pid = `set -m; process-memory-usage.pl -s 1 60 $$ > $mon & echo -n \$!`;
   log_msg "Monitor PID $mon_pid";
}

while(defined $reply_rcvd and $reply_rcvd !~ /^\*\*\*EMPTY\*\*\*/i
         and $reply_rcvd ne ""){
   log_msg "Executing $reply_rcvd";
   my ($job_id, $job_command) = split / /, $reply_rcvd, 2;
   my $exit_status;
   if (!defined $job_id or $job_id !~ /^\(\d+\)$/ or !defined $job_command) {
      log_msg "Received ill-formatted command: $reply_rcvd";
      $exit_status = -2;
   } else {
      $SIG{INT} = sub { report_signal(2) };
      $SIG{QUIT} = sub { report_signal(3) };
      $SIG{TERM} = sub { report_signal(15) };
      if ( defined $subst ) {
         $job_command =~ s/\Q$subst_match\E/\Q$subst_replacement\E/go;
         log_msg "Substitued command: $job_command";
      }
      my $rc = system($job_command);
      $SIG{INT} = $SIG{QUIT} = $SIG{TERM} = 'ignore_signal';
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
   if ( $quota > 0 and (time - $start_time) > $quota*60 ) {
      # Done my share of work, request a relaunch
      send_recv "DONE-STOPPING ($me) (rc=$exit_status) $reply_rcvd";
      last;
   } else {
      send_recv "DONE ($me) (rc=$exit_status) $reply_rcvd";
      $reply_rcvd = send_recv "GET ($me)";
   }
}

if ( $mon_pid ) {
   system("kill $mon_pid");
   log_msg("Killed monitor process $mon_pid");
}

log_msg "Done.";



sub PrintHelp{
print <<'EOF';
  This script is a generic worker script. It is meant to be used in
  conjunction with:
    - /utils/run-parallel.sh (script invoked by user)
    - /utils/r-parallel-d.sh (deamon invoked by run-parallel.sh)

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
              requesting a relaunch from the deamon [30] (0 means never
              relaunch, i.e., work until there is no more work.)
    -primary  Indicates this worker is the primary one and should not be
              stopped on a quench request (implies -quota 0)
    -netcat   Just act like a simple netcat, sending the first line from STDIN
              to host:port and printing the response to STDOUT.
    -subst MATCH/REPLACEMENT replaces MATCH by REPLACEMENT in every command
              received before executing it.
    -mon FILE Run process-memory-usage.pl on self, saving output into FILE

EOF
}

