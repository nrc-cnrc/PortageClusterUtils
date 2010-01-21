#!/usr/bin/perl
# $Id$

# @file process-memory-usage.pl 
# @brief Sums the virtual memory usage and resident set size of a process tree.
#
# @author Samuel Larkin
#
# COMMENTS:
#
# Samuel Larkin
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2007, Sa Majeste la Reine du Chef du Canada /
# Copyright 2007, Her Majesty in Right of Canada

use strict;
use warnings;

sub usage {
   local $, = "\n";
   print STDERR @_, "";
   $0 =~ s#.*/##;
   print STDERR "
Usage: $0 [-h(elp)] [-v(erbose)] [-s stop_after] SLEEP PID

  Sums the virtual memory usage and resident set size of the tree rooted in PID
  every SLEEP seconds.

Options:

  -s stop_after Stop monitoring if process is not found after stop_after
                iterations [unlimited].
  -h(elp):      print this help message
  -v(erbose):   increment the verbosity level by 1 (may be repeated)

Note:
  To silently kill this process, send it signal 10 (SIGUSR1).  The signal will
  be caught and will cause the process to exit without any further output.

";
   exit 1;
}

$SIG{USR1} = sub { exit(0); };

my $Gigabytes = 1024 * 1024;  # Kb to Gb
use Getopt::Long;
# Note to programmer: Getopt::Long automatically accepts unambiguous
# abbreviations for all options.
my $verbose = 1;
GetOptions(
   "s=i"           => \my $stop_after,
   "help|h"        => sub { usage },
   "verbose|v"     => sub { ++$verbose },
   "debug|d"       => \my $debug,
) or usage;

my $sleep_time = shift || die "Missing SLEEP";
my $mainpid    = shift || die "Missing PID";
#print "$sleep_time  $mainpid\n";

0 == @ARGV or usage "Superfluous parameter(s): @ARGV";


local $| = 1; # autoflush

my $i = 0;
my $not_present = 0;
while (1) {
   my %PIDS = ();
   my $total_vsz = 0;
   my $total_rss = 0;
   my $total_pcpu = 0;
   foreach my $process_info (split /\n/, `ps xo ppid,pid,vsz,rss,pcpu,comm`) {
      print "<V> $process_info\n" if ($verbose > 1);

      next if ($process_info =~ /PPID/);  # Skip the header

      chomp($process_info);        # Remove newline
      $process_info =~ s/^\s+//;   # Remove leading spaces
      my ($ppid, $pid, $vsz, $rss, $pcpu, $comm) = split(/\s+/, $process_info);

      # Is this process part of the process tree
      if (exists $PIDS{$ppid} or $pid == $mainpid) {
         print "<D> $ppid $pid $vsz $rss $pcpu $comm\n" if(defined($debug));

         $PIDS{$pid} = 1;
         $total_vsz  += $vsz;
         $total_rss  += $rss;
         $total_pcpu += $pcpu;
      }
   }
   printf("<D> num sub p: %d\n", scalar(keys %PIDS)) if (defined($debug));
   if ($stop_after and scalar(keys %PIDS) == 0) {
      ++$not_present;
      exit 0 if ($not_present > $stop_after);
   }

   my $date = `date "+%F %T"`;
   chomp($date);
   $total_vsz = $total_vsz / $Gigabytes;
   $total_rss = $total_rss / $Gigabytes;
   printf "$date Total vsz: %.3fG rss: %.3fG pcpu: %.1f%% ", $total_vsz , $total_rss, $total_pcpu;
   printf "%d Processes\n", scalar (keys (%PIDS));

   sleep $sleep_time;
}
