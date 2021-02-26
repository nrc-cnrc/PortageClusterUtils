#!/usr/bin/env perl

# @file analyze-run-parallel-log.pl
# @brief Analyze and summarize the log from run-parallel.sh
#
# @author Eric Joanis
#
# Traitement multilingue de textes / Multilingual Text Processing
# Centre de recherche en technologies numériques / Digital Technologies Research Centre
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2021, Sa Majesté la Reine du Chef du Canada /
# Copyright 2021, Her Majesty in Right of Canada

use strict;
use warnings;

if (@ARGV and $ARGV[0] =~ /^-h/) {
   print STDERR "
Usage: $0 [-h] [run-parallel.sh log]

  Parse the log from run-parallel.sh and display a one-line status for each job:
  one of Running, Done (rc=0) or Done ***(rc=<non-zero>)***.

  For best legibility, pipe the output through expand-auto.pl:
     $0 < rp.log | expand-auto.pl
";
   exit @_ ? 1 : 0;
}

my %jobs;
while (<>) {
   if (/starting \(.*?\) \((\d+)\) (.*)/) {
      my $id = $1;
      my $job = $2;
      $job =~ s/\s*$//;
      $jobs{$id} = [$job, "Running "];
   } elsif (/(\d+)\/\d+ DONE \(.*?\) (\**\(rc=\d+\)\**) \((\d+)\) (.*)/) {
      my $done_rank = $1;
      my $rc = $2;
      my $id = $3;
      my $job = $4;
      $job =~ s/\s*$//;
      if ($jobs{$id}->[0] ne $job) { warn "Job $id was $jobs{$id}->[0] is now $job\n"; }
      $jobs{$id} = [$job, "Done $rc", $done_rank];
   }
}

foreach my $id (sort {$a <=> $b} keys %jobs) {
   my @j = @{$jobs{$id}};
   print "$id\t$j[1]\t$j[0]\n";
}
