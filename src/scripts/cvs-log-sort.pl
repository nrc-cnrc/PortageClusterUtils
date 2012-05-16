#!/usr/bin/perl
# $Id$

# @file cvs-log-sort.pl 
# @brief Take the output of "cvs log" on a directory, and present it
# chronologically, merging the reporting of commits that were done at the same
# time on multiple files.
#
# @author Eric Joanis
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2007, Sa Majeste la Reine du Chef du Canada /
# Copyright 2007, Her Majesty in Right of Canada

use strict;
use warnings;
use POSIX;

sub usage {
   local $, = "\n";
   print STDERR @_, "";
   $0 =~ s#.*/##;
   print STDERR "
Usage: cvs log | $0 | less

  Take the output of \"cvs log\" on a directory, and present it
  chronologically, merging the reporting of commits that were done at the same
  time on multiple files.

";
   exit 1;
}

use Getopt::Long;
# Note to programmer: Getopt::Long automatically accepts unambiguous
# abbreviations for all options.
my $verbose = 1;
GetOptions(
   help        => sub { usage },
) or usage;

sub max($$) {
   $_[0] > $_[1] ? $_[0] : $_[1];
}

# pad($string, $len) returns $string padded with spaces to length $len
sub pad($$) {
   $_[0] . (" " x max(0,($_[1] - length $_[0])));
}

# map "$date $author $log_text" -> @file_rev_infos
my %log_items;
while (1) {
   last if eof();
   my $file;
   while (<>) {
      if ( /^Working file: (.*)/ ) { $file = $1; last; }
   }
   last if eof();

   next if $file =~ /\.log\.klocwork\.tag/; # ignore automatic file.

   # Read tags
   my %tags;
   while (<>) {
      if ( /^symbolic names:/ ) {
         while (<>) {
            if ( /^\s+(.*?):\s+([0-9.]+)$/ ) {
               if ( exists $tags{$2} ) {
                  $tags{$2} .= ",$1";
               } else {
                  $tags{$2} = $1;
               }
            } else {
               last;
            }
         }
         last;
      }
      if ( /^(keyword sub|total revisions|description|------------)/ ) {
         last;
      }
      if ( /^revision / ) {
         warn "revision section in an unexpected location at line $.";
         last;
      }
   }
   last if eof();

   # Read revisions
   my $rev_count = 0;
   while (1){
      my $revision;
      while (<>) {
         if ( /^revision (.*)/ ) { $revision = $1; last; }
      }
      last if eof();
      my $date_line = <>;
      defined $date_line or do { warn "unexpected eof()"; last; };
      my ($date, $zone, $author, $state, $lines, $commitid) =
         $date_line =~ /
                        date:\s*(.*?):\d\d(?:\s*([-+]\d{4}))?;\s*
                        author:\s*([^;]*);\s*
                        state:\s*([^;]*);\s*
                        (?:lines:\s*(.*?);?\s*)?
                        (?:commitid:\s*(.*?);?\s*)?
                        $
                       /x
            or do { warn "invalid date line $date_line"; next; };

      my $local_date;
      if ( my ($year, $month, $day, $hour, $min) =
           $date =~ m#(\d+)[-/](\d+)[-/](\d+) (\d+):(\d+)# ) {
         my $time_t = POSIX::mktime(0, $min, $hour, $day, $month-1, $year-1900);
         #printf STDERR "ZONE: $zone\n";
         if ( defined $zone ) {
            $time_t -= $zone/100 * 3600; # Convert $time_t to UTC
         }
         $time_t += -5 * 3600; # Convert $time_t to the Eastern time zone
         $local_date = strftime "%Y/%m/%d %H:%M:%S %Z (%a)", localtime($time_t);
         #print "Date $date LocalDate $local_date\n";
      } else {
         $local_date = "$date UTC";
      }

      my $log_text = "";
      my $got_file_end_marker = 0;
      my $branches = "";
      while (<>) {
         last if /^-{20,}$/;
         if ( /^={70,}$/ ) { $got_file_end_marker = 1; last; }
         if ( /^branches:((?: +[0-9.]+;)+)$/ ) {
            $branches .= $1;
            $branches =~ s/ //g;
            next;
         }
         $log_text .= $_;
      }

      defined $commitid or $commitid = "";
      my $key = "$local_date $author $commitid\n\n$log_text\n";
      my $file_rev_info = pad("$revision ", 11) .
                          pad(((defined $lines) ? $lines : ""), 11) .
                          "$file " .
                          ($state eq "Exp" ? "" : "($state) ") .
                          (exists $tags{$revision} ? "(tags:$tags{$revision}) " : "") .
                          ($branches ? "(branches:$branches)" : "") .
                          "\n";
      if ( exists $log_items{$key} ) {
         push @{$log_items{$key}}, $file_rev_info;
      } else {
         $log_items{$key} = [ $file_rev_info ];
      }

      ++$rev_count;

      #print "$key$file_rev_info---------------\n";
      last if ( $got_file_end_marker || eof() );
   }
   warn "No revisions found for file $file\n" if ( $rev_count == 0 );
}

foreach my $key (reverse sort keys %log_items) {
   defined $key or die "key undefined";
   exists $log_items{$key} or die "invalid key $_";
   print $key, @{$log_items{$key}}, ("=" x 77), "\n\n";
   #print $key;
   #print $log_items{$key};
   #print @{$log_items{$key}};
   #print @{$log_items{$key}};
}

