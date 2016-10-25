#!/usr/bin/env perl

# @file process-memory-usage.pl 
# @brief Sum the virtual memory usage and resident set size of a process tree.
#
# @author Samuel Larkin
#
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

  Sum the virtual memory usage and resident set size of the tree rooted in PID
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
   exit $_ ? 1 : 0;
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
) or usage "Invalid option(s).";

my $sleep_time = shift || die "Error: Missing SLEEP";
my $mainpid    = shift || die "Error: Missing PID";
#print "$sleep_time  $mainpid\n";

0 == @ARGV or usage "Error: Superfluous argument(s): @ARGV";


local $| = 1; # autoflush

my $i = 0;
my $not_present = 0;
my $use_smem = system("which-test.sh smem") == 0;
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
   my $total_uss_smem = 0;
   my $total_rss_smem = 0;
   my $total_vss_smem = 0;
   my $total_swap_smem = 0;
   if ($use_smem) {
      foreach my $process_info (split /\n/, `smem -c "pid uss rss vss swap name" 2> /dev/null`) {
         print "<V> $process_info\n" if ($verbose > 1);
   
         next if ($process_info =~ /PID/);  # Skip the header
   
         chomp($process_info);        # Remove newline
         $process_info =~ s/^\s+//;   # Remove leading spaces
         my ($pid, $uss, $rss, $vss, $swap, $name) = split(/\s+/, $process_info);
   
         # Is this process part of the process tree
         if (exists $PIDS{$pid}) {
            print "<D> $pid $uss $rss $vss $swap $name\n" if(defined($debug));
            $total_uss_smem += $uss;
            $total_rss_smem += $rss;
            $total_vss_smem += $vss;
            $total_swap_smem += $swap;
         }
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
   if ($use_smem) {
      $total_uss_smem = $total_uss_smem / $Gigabytes;
      $total_rss_smem = $total_rss_smem / $Gigabytes;
      $total_vss_smem = $total_vss_smem / $Gigabytes;
      $total_swap_smem = $total_swap_smem / $Gigabytes;
      printf "uss(smem): %.3fG ", $total_uss_smem;
      if ($verbose > 1) {
         printf "rss(smem): %.3fG vss(smem): %.3fG swap(smem): %.3fG ",
                $total_rss_smem, $total_vss_smem, $total_swap_smem;
      }
   }
   printf "%d Processes\n", scalar (keys (%PIDS));

   sleep $sleep_time;
}
