#!/usr/bin/env perl

# @file jobsig-test.pl
# @brief Test script for a job signal mechanism, in Perl
#
# @author Eric Joanis
#
# Traitement multilingue de textes / Multilingual Text Processing
# Tech. de l'information et des communications / Information and Communications Tech.
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2016, Sa Majeste la Reine du Chef du Canada /
# Copyright 2016, Her Majesty in Right of Canada

use strict;
use warnings;

sub usage {
   local $, = "\n";
   print STDERR @_, "";
   $0 =~ s#.*/##;
   print STDERR "
Usage: $0 [-s SIGNAL] JOB_ID

  Send SIGNAL to the processes of cluster job JOB_ID.

Options:

  -h(elp)        print this help message
  -s SIGNAL      send signal SIGNAL [15]
  -n(otreally)   Just show what we would do, but do not send the signal
";
   exit 1;
}

use Getopt::Long;
Getopt::Long::Configure("no_ignore_case");
# Note to programmer: Getopt::Long automatically accepts unambiguous
# abbreviations for all options.
my $verbose = 1;
GetOptions(
   help        => sub { usage },
   verbose     => sub { ++$verbose },
   quiet       => sub { $verbose = 0 },
   debug       => \my $debug,
   notreally   => \my $notreally,
   "s=i"       => \my $signal,
) or usage "Error: Invalid option(s).";
defined $signal or $signal = 15;

0 == @ARGV and usage "Error: missing job ID.";
my $jobid = shift;
0 == @ARGV or usage "Error: superfluous argument(s): @ARGV";

sub getPIDs {
   open PS, "sshj -j $jobid -- ps fjxaww |"
      or die "Error: cannot open sshj pipe to get process IDs";
   my ($job_pgid, $job_main_pid, @job_other_pids);
   my @PS_output;
   while (<PS>) {
      push @PS_output, $_;
      if (m#^\s*(\d+)\s+(\d+)\s+(\d+)\s*(\S+).*/tmp/$jobid\..*/job#
            && ! /rudial/ && ! /rustart/) {
         # We found the main job process, normally immediate child of rustart process
         # runnning the job
         $debug and do { print $PS_output[-2] || ""; print; };
         my ($ppid, $pid, $pgid, $sid) = ($1, $2, $3, $4);
         $job_pgid = $pgid;
         $job_main_pid = $pid;
         while (<PS>) {
            $debug and print;
            if (m#^\s*(\d+)\s+(\d+)\s+$pgid\s#) {
               push @job_other_pids, $2;
            } else {
               last;
            }
         }
         last;
      }
   }
   if (!close PS) {
      warn "Error: problem closing sshj pipe to job node, command probably did not work";
      @PS_output && print STDERR "ps fjxaww output was:\n", @PS_output;
      exit 1;
   }

   defined $job_pgid
      or die "Error: could not find process information for job $jobid";

   return ($job_pgid, $job_main_pid, @job_other_pids);
}

my ($job_pgid, $job_main_pid, @job_other_pids) = getPIDs();

print "PGID = $job_pgid\nMain PID = $job_main_pid\nOther PIDs = @job_other_pids\n";

# Send the signal
my $cmd = "sshj -j $jobid -- kill -$signal -$job_pgid";
print $cmd, "\n";
system($cmd) unless $notreally;
