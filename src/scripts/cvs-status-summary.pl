#!/usr/bin/env perl
# $Id$

# @file cvs-status-summary.pl 
# @brief Make the output of cvs status more compact, making the important
# information stand out more.
#
# @author Eric Joanis
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2005, Sa Majeste la Reine du Chef du Canada /
# Copyright 2005, Her Majesty in Right of Canada

use strict;
use warnings;

sub usage {
   local $, = "\n";
   print STDERR @_, "";
   $0 =~ s#.*/##;
   print STDERR "
Usage: cvs status | cvs-status-summary.pl [options] [FILE_LIST]

  When called in a pipe or with a list of files, summarizes the cvs status
  information found in stdin or FILE_LIST.

  When called without a list of files and with a tty as stdin, displays status
  information about modified files in the current sandbox, including new files
  in the repository in need of checkout.

Options: -n(ew)     skip up-to-date files.
         -v(erbose) display verbose information
         -h(elp)    print this help message
";
   exit 1;
}

use Getopt::Long;
GetOptions(
   "new"       => \my $newonly,
   "verbose"   => \my $verbose,
   help        => sub { usage },
);

if (-t STDIN && @ARGV == 0) {
   $verbose and 
      print STDERR "cvs -n up 2>&1 | grep '^[A-Z] ' | sed 's/. //' | xargs -r cvs status | cvs-status-summary.pl\n";
   close STDIN;
   open(STDIN, "cvs -n up 2>&1 | grep '^[A-Z] ' | sed 's/. //' | xargs -r cvs status 2> /dev/null |")
      or die "Can't open cvs pipe: $!";
}

my @conflicts;
my %status_lists;
local $/ = "=================\n";
while (<>) { 
   next unless /revision/;
   my ($status) = /Status:\s+(.*)/;
   next if $newonly && $status =~ /Up-to-date/;
   $status =~ s/Up-to-date//;
   my ($working) = /Working revision:\s+(\S+)/;
   my ($date) = /Working revision:\s+\S+[ \t]+(.*)/;
   my ($repository, $filename) = 
      /Repository revision:\s+(\S+)\s+\/home\/cvs\/(?:LTRC\/)?[^\/]+\/(.*)/;
   if ( ! defined $repository ) {
      # Probably a new file
      $repository = "Unknown";
      ($filename) = /File:\s+(\S+)/;
   }
   $filename =~ s/,v$//;
   $filename =~ s/\/Attic(\/)/$1/;
   my $filename_copy = $filename;
   while ( 1 ) {
      if ( -f $filename_copy ) {
         $filename = $filename_copy;
         last;
      }
      if ( $filename_copy !~ s#.*?/## ) {
         last;
      }
   }
   if ($repository eq $working) { $repository = "" }
   my ($sticky_tag) = /Sticky Tag:\s*(.*)/;
   my ($sticky_date) = /Sticky Date:\s*(.*)/;
   my ($sticky_opts) = /Sticky Options:\s*(.*)/;
   for ($sticky_tag, $sticky_date, $sticky_opts) {
      if ( defined $_ ) {
         s/\(none\)//;
      } else {
         $_ = "";
      }
   }
   my $sticky = "";
   if ($sticky_tag || $sticky_date || $sticky_opts) {
      $sticky = "Sticky: $sticky_tag $sticky_date $sticky_opts";
   }
   if ( $status =~ /conflict/i ) {
      push @conflicts, $filename;
   }
   if ( $status ) {
      push @{$status_lists{$status}}, $filename
   }

   if ( defined $date ) {
      printf "%-8s %-24s   %-8s %-16s %s   %s\n",
             $working, $date, $repository, $status, $sticky, $filename;
   } else {
      printf "%-8s %-8s %-16s %s   %s\n",
             $working, $repository, $status, $sticky, $filename;
   }
   if ( 0 ) {
      print "working: $working\ndate: $date\nrepository: $repository\n";
      print "status: $status\nsticky: $sticky\nfilename: $filename\n";
   }
}

if (!%status_lists) {
   print "\nAll files are up to date.\n";
} else {
   print "\nFiles by status:\n";
   foreach my $key (sort keys %status_lists) {
      print " - $key:\n      @{$status_lists{$key}}\n";
   }
}

if ( @conflicts ) {
   print "\n\nWARNING: These files had conflicts:\n";
   foreach ( @conflicts ) {
      print "	$_\n";
   }
}

