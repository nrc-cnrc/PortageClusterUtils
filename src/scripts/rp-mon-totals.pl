#!/usr/bin/env perl
#
# @file rp-mon-totals.pl
# @brief Summarize run-parallel.sh totals from mon.worker-* files.
#
# @author Darlene Stewart
#
# Technologies langagieres interactives / Interactive Language Technologies
# Tech. de l'information et des communications / Information and Communications Tech.
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2013, Sa Majeste la Reine du Chef du Canada /
# Copyright 2013, Her Majesty in Right of Canada

use strict;
use warnings;

use Time::Piece;
use File::Basename;

sub usage {
   local $, = "\n";
   print STDERR @_, "";
   $0 =~ s#.*/##;
   print STDERR "
Usage: $0 MONFILE(S)

  Summarize run-parallel.sh totals from mon.worker-* files.

";
   exit @_ ? 1 : 0;
}

use Getopt::Long;
# Note to programmer: Getopt::Long automatically accepts unambiguous
# abbreviations for all options.
my $verbose = 0;
GetOptions(
   help        => sub { usage },
   verbose     => sub { ++$verbose },
   debug       => \my $debug,
) or usage "Error: Invalid option(s).";


my $max_vsz = 0.0;
my $max_rss = 0.0;
my $total_pcpu = 0.0;
my $pcpu_cnt = 0;
my $max_shr = 0.0;
my $uss_for_max_shr = 0.0;
my $max_uss = 0.0;
my $shr_for_max_uss = 0.0;

sub processlog($) {
   my $logfile = shift;

   open LOG, $logfile or die "Error: Can't open $logfile: $!\n";

   my $threshold = 0.20;
   my $first_line = 1;

   while (<LOG>) {
      if ( /^([\d\-]+ [\d:]+) Total vsz: ([\d.]+)G rss: ([\d.]+)G pcpu: ([\d.]+)%/ ) {
         my $tm = $1;
         my $vsz = $2;
         my $rss = $3;
         my $pcpu = $4;

         $max_vsz = $vsz if $vsz > $max_vsz;
         $max_rss = $rss if $rss > $max_rss;

         if ($pcpu > 0.0 or !$first_line) {
            $total_pcpu += $pcpu;
            ++$pcpu_cnt;
         }
         $first_line = 0;
         
         if ( /uss\(smem\): ([\d.]+)G/ ) {
            my $uss = $1;
            my $shr = $rss - $uss;
            # We consider only USS values close to the maximum share value.
            if ($shr > $max_shr) {
               # Consider the old max_uss to be invalid if its shr is not close
               # enough to the new max_shr
               if ($shr - $shr_for_max_uss > $threshold * $shr) {
                  $max_uss = $uss;
                  $shr_for_max_uss = $shr;
                  # Consider the old max_shr for max_uss if close enough to the new max_shr
                  if ($shr - $max_shr <= $threshold * $shr && $uss_for_max_shr > $max_uss) {
                     $max_uss = $uss_for_max_shr;
                     $shr_for_max_uss = $max_shr;
                  }
               }
               $max_shr = $shr;
               $uss_for_max_shr = $uss;
            } elsif ($shr == $max_shr) {
               $uss_for_max_shr = $uss if $uss > $uss_for_max_shr;
            }
            # Consider the new shr for max_uss if close enough to the max_shr
            if ($max_shr - $shr <= $threshold * $max_shr && $uss > $max_uss) {
               $max_uss = $uss;
               $shr_for_max_uss = $shr;
            }
         }
      }
   }
}

die "Error: Need at least one log file" if @ARGV < 1;

foreach my $log (@ARGV) {
   processlog($log);
}

my $avg_pcpu = 0.0;
$avg_pcpu = $total_pcpu / $pcpu_cnt if $pcpu_cnt > 0;
my $uss_str = "";
$uss_str = sprintf(" Max USS %.3fG+", $max_uss) if $max_uss > 0.0;
printf "Max VMEM %.3fG Max RAM %.3fG%s Avg PCPU %.1f%%",
       $max_vsz, $max_rss, $uss_str, $avg_pcpu;
