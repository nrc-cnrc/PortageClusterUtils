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
Usage: $0 [-s SIGNAL] JOB_ID ...

  Send SIGNAL to the processes of cluster job(s) JOB_ID ...

Options:

  -h(elp)        print this help message
  -s SIGNAL      send signal SIGNAL [15=TERM=SIGTERM]
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
   "s=s"       => \my $signal,
) or usage "Error: Invalid option(s).";
defined $signal or $signal = 15;
system("/bin/kill -l $signal > /dev/null") == 0 or die "Error: unknown signal $signal.\n";

0 == @ARGV and usage "Error: missing job ID.";
my @jobids = @ARGV;

my $cluster_type = `on-cluster.sh -type`;
chomp $cluster_type;
if ($cluster_type eq "qsub") {
   my $cmd = "qsig -s $signal @jobids";
   print $cmd, "\n";
   if ($notreally) {
      exit;
   } else {
      exit(system $cmd);
   }
}

if (@jobids > 1) {
   my $rc = 0;
   my $cmd = "$0 -s $signal";
   $cmd .= " -debug" if $debug;
   $cmd .= " -notreally" if $notreally;
   my $script = "";
   for my $jobid (@jobids) {
      $script .= "$cmd $jobid & ";
      #if (0 != system("$cmd $jobid")) {
      #   $rc = 1;
      #}
   }
   $script .= "wait ; date";
   $rc = system($script);
   exit($rc);
}

my $jobid = $jobids[0];

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
      @PS_output && print STDERR @PS_output;
      warn "Error: problem with sshj cmd to find job processes on the job node\n";
      exit 1;
   }

   if (! defined $job_pgid) {
      $debug && print STDERR @PS_output;
      die "Error: could not find process information for job $jobid\n";
   }

   return ($job_pgid, $job_main_pid, @job_other_pids);
}

print localtime() . "\n";
my ($job_pgid, $job_main_pid, @job_other_pids) = getPIDs();

print "PGID = $job_pgid\nMain PID = $job_main_pid\nOther PIDs = @job_other_pids\n";

# Send the signal
my $cmd = "sshj -j $jobid -- kill -$signal -$job_pgid";
print $cmd, "\n";
if (! $notreally) {
   my $rc = system($cmd);
   print $cmd . " finished at " . localtime() . ($rc ? " with rc=$rc" : "") . "\n";
   exit($rc);
}
