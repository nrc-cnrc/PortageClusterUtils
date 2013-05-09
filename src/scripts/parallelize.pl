#!/usr/bin/env perl
# $Id$

# @file parallelize.pl
# @brief Parallelizes a command into N smaller chunks, executes each chunks and
# merges the results.
#
# @author Samuel Larkin
#
# COMMENTS:
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2007, Sa Majeste la Reine du Chef du Canada /
# Copyright 2007, Her Majesty in Right of Canada

# WISH LIST
# - custom splitter (default split).
#   - split on paragraph for utokenize.pl for example (separate custom splitter).
# - custom merger   (default cat).
#   - merge-N 3 tally => merge 3 at a time with tally until all merged (Eric
#     make-big-lm).
# - resume based on input chunks not deleted (Partially implemented).
#   Build a merge.cmd final.  This would allow merging with run-parallel.sh and
#   make resuming easier.
# - properly handle gzip.
#   - Intelligent output format:
#     Detect if the input is big which may indicate a big output then if the
#     input is big, gzip the output of each chunks and simply cat all the
#     chunks into one final output.gz or if the input is small, produce
#     uncompress chunks' output and cat | gzip all chunks to a final output
#     file.  Here we are trying to save some intermediate disk space.
# - use base name of argument for chunk's name (DONE => using argument's name
#   as intermediate directory name).
# - split in chunks of size S instead of in X chunks.
# - Only feasable for output but if no output file is specified, implicitly use
#   /dev/stdout and /dev/stderr (DONE).

use strict;
use warnings;
use POSIX qw(ceil);
use File::Basename;

sub usage {
   local $, = "\n";
   print STDERR @_, "";
   $0 =~ s#.*/##;
   print STDERR "
Usage: $0 [-debug] [-resume] [-s <token>] [-m <token>]
       [Options]
       -n N cmd cmd_args

  Parallelizes a command into N smaller chunks, executes each chunks and merges
  the results.  The files specified with < and > are automatically handled.
  The input and ouput can be either text files or gzip files.

WARNING:
  For ease of use, this script detects .gz at the end of a filename and takes
  care of zipping and unzipping the inputs and outputs thus no need to pipe
  your outputs to gzip.

Options:

  -h(elp):      print this help message
  -v(erbose):   increment the verbosity level by 1 (may be repeated)
  -d(ebug):     print debugging information

  -n N    split the work in N jobs/chunks (at most N with -w) [3].
  -np M   number of simultaneous workers used to process the N chunks [N].
  -w W    Specifies the minimum number of lines in each block.
  -s <X>  split additional input file X in N chunks where X in cmd_args.
  -m <Z>  merge additional output file Z where Z in cmd_args.
  -stripe Each job get lines l%N==i and also prevents creating temporary chunk
          files.  Only works correctly for jobs where each line of input
          creates one line of output.
  -merge  merge command [cat]
  -nolocal  Run run-parallel.sh -nolocal
  -psub <O> Passes additional options to run-parallel.sh -psub.
  -rp   <O> Passes additional options to run-parallel.sh.

Note:
  -s / -m accept a space-separated list of files i.e. -s 'a b c'.

Good examples:
  Tokenize the test_en.txt using 12 nodes.
  $0 -n 12 \"utokenize.pl -noss -lang=en < test_en.txt > test_en.tok\"

  Tag dev1 using 2 nodes and using a tagger and keeping only the tags with the
  sed expression.
  $0 -debug -n 2 \"(./tagger | sed 's#[^ ]*/##g') < dev1 > dev1.tagged\"

  Even though the syntax is non-standard, for ease of use $0 handles gzip files
  as input as if it was a regular file:
  $0 'cat < input.gz > output'
  $0 'cat < input.gz > output.gz'

  Handles outputing to stdout transparently.
  $0 'cat < input.gz'    > output
  
  When you have multiple inputs & outputs:
  $0 \\
    -s src_in \\
    -s tgt_in \\
    -m src_out \\
    -m tgt_out \\
    'filter_training_corpus src_in tgt_in src_out tgt_out 100 9'

  To illustrate the -merge option, here is an example that does an inventory
  count of characters in a corpus:
  $0 \\
    -merge \"merge_counts -\" -w 100000 -n 100 \\
    \"(grep -o . | sed 's/^ \$/__/' | get_voc -c | sed 's/^__ /  /' | \\
       LC_ALL=C sort) < corpus > corpus.char\"

BAD examples:
  $0 '(cat | gzip) < input > output.gz'
  Your output will be zipped twice.

";
   exit 1;
}

my $debug_cmd = "";

use Getopt::Long;
# Note to programmer: Getopt::Long automatically accepts unambiguous
# abbreviations for all options.
my $MERGE_PGM = undef;
my $verbose = 0;
my @SPLITS = ();
my @MERGES = ();
my $N = 3;
my $NP = undef;
my $W = undef;
my $NOLOCAL = "";
my $PSUB_OPTS = "";
my $RP_OPTS = "";
GetOptions(
   help        => sub { usage },
   "verbose+"  => \$verbose,
   quiet       => sub { $verbose = 0 },
   debug       => \my $debug,

   # Hidden option for unit testing parsing the arguments.
   show_args   => \my $show_args,
   "workdir=s" => \my $workdir,

   stripe      => \my $use_stripe_splitting,

   "s=s"       => \@SPLITS,
   "m=s"       => \@MERGES,

   "merge=s"   => \$MERGE_PGM,

   "n=i"       => \$N,
   "np=i"      => \$NP,
   "w=i"       => \$W,

   "psub=s"    => \$PSUB_OPTS,
   "rp=s"      => \$RP_OPTS,
   "nolocal"   => sub {$NOLOCAL = "-nolocal"},
   "resume"    => sub {die "not implemented yet"},
) or usage;

sub debug {
   print STDERR "<D> @_\n" if ($debug);
}

sub verbose {
   my $level = shift(@_);
   print STDERR "<V> @_\n" if ($verbose >= $level);
}

$PSUB_OPTS = "-psub \"$PSUB_OPTS\"" unless ($PSUB_OPTS eq "");

# Make sure we have access to stripe.py
$use_stripe_splitting = ($use_stripe_splitting and system("which-test.sh stripe.py") == 0);
if ($use_stripe_splitting) {
   # If we are using stripe mode and the user DIDN'T specify is one merge
   # command tool, we will use stripe.py in rebuild mode.
   $MERGE_PGM = "stripe.py -r" unless(defined($MERGE_PGM));
}


# Make sure the merge command tool is set.
$MERGE_PGM = "cat" unless(defined($MERGE_PGM));


# Removes duplicates in an array.
sub remove_dups {
   my %hash;
   $hash{$_}++ for @_;
   # sorting is needed here for parallelize.pl's unittest.
   return sort(keys %hash);
}

# We need to strip any arguments of the MERGE_PGM command before we can check
# if the merge program is available in PATH.
$MERGE_PGM =~ /([^ ]+)/;
my $CHECK_MERGE_PGM = $1;
my $rc = system("which-test.sh $CHECK_MERGE_PGM");
die "Merge program $CHECK_MERGE_PGM is not on your PATH.\n" unless($rc eq 0);

# If the user provides more than one file to an -s option, we need to make sure
# we expand to be one entry per array index.
@SPLITS = map { split("[ \t]+", $_) } @SPLITS;
@MERGES = map { split("[ \t]+", $_) } @MERGES;

# Grab the rest of the command line as the command to run
my $CMD = join " ", @ARGV;

# W, if exists, must be positive;
die "-w W must be a positive value." unless (not defined($W) or $W > 0);

# By default, look for input redirection
if ($CMD =~ /<(\s*)([^\( >]+)($|\s*|\))/) {
   my $split = $2;
   verbose(1, "Adding $split to splits");
   push @SPLITS, $split;
}

# Check if the user provided an output.
my $merge = "";
if ($CMD =~ /[^2]>(\s*)([^ <]+)($|\s*|\))/) {
   $merge = $2;
}
else {
   # If no output is given then the user must want to have its output to stdout.
   $CMD = "$CMD > /dev/stdout";
   $merge = "/dev/stdout";
}
verbose(1, "Adding $merge to merge");
push @MERGES, $merge;

# Check if the user provided an error output.
if ($CMD =~ /2>(\s*)([^ <]+)($|\s*)/) {
   $merge = $2;
}
else {
   # If no err output is given then the user must want to have its output to stderr.
   $CMD = "$CMD 2> /dev/stderr";
   $merge = "/dev/stderr";
}
verbose(1, "Adding $merge to merge");
push @MERGES, $merge;

@SPLITS = remove_dups @SPLITS;
@MERGES = remove_dups @MERGES;

if ( $debug ) {
   $debug_cmd = "time ";
   no warnings;
   printf STDERR "
   CMD=$CMD
   SPLITS=%s
   MERGES=%s
   PSUB_OPTS=$PSUB_OPTS
   RP_OPTS=$RP_OPTS
"
   , join(" : ", @SPLITS)
   , join(" : ", @MERGES);
   exit if(defined($show_args));
}

# Create a working directory to prevent polluting the environment.
$workdir = "parallelize.pl.$$" unless(defined($workdir));
mkdir($workdir);



# Make sure there is at least one input file.
die "You must provide an input file." unless(scalar(@SPLITS) gt 0);

# Check if all SPLITS and all MERGES are arguments of the command.
foreach my $s (@SPLITS) {
   # Escape the input since it might have some control characters.
   die "not an argument of command: $s" unless $CMD =~ /(^|\s|<)\Q$s\E($|\s|\))/;
}
foreach my $m (@MERGES) {
   # Escape the input since it might have some control characters.
   die "not an argument of command: $m" unless $CMD =~ /(^|\s|>)\Q$m\E($|\s|\))/;
}


# Get the basename of all SPLITS and MERGES
# Since we can't have file names with slashes, will change them for _SLASH_
sub slash($) {
   my $t=$_;
   $t =~ s#/#_SLASH_#g;
   return $t;
}
my %basename = map { $_ => slash($_) } (@MERGES, @SPLITS);
if ($debug) {
   print STDERR "basenames:\n";
   print STDERR join("\n", values %basename);
   print STDERR "\n";
}


# Create MERGES & SPLITS dir
foreach my $d (@MERGES, @SPLITS) {
   my $dir = "$workdir/" . $basename{$d};
   mkdir($dir) unless -e $dir;
}


my $NUMBER_OF_CHUNK_GENERATED = $N;

unless ($use_stripe_splitting) {
   # Split all SPLITS
   foreach my $s (@SPLITS) {
      my $dir = "$workdir/" . $basename{$s};

      my $NUM_LINE = $W;
      # Did the user specified a number of line to split into?
      if (defined($N)) {
         $NUM_LINE = `gzip -cqfd $s | wc -l`;
         $NUM_LINE = ceil($NUM_LINE / $N);
         $NUM_LINE = $W if (defined($W) and $W > $NUM_LINE);
      }

      verbose(1, "Splitting $s in $N chunks of ~$NUM_LINE lines in $dir");
      my $rc = system("$debug_cmd gzip -cqfd $s | split -a 4 -d -l $NUM_LINE - $dir/");
      die "Error spliting $s\n" unless($rc eq 0);

      # Calculates the total number of jobs to create which can be different from
      # -n N if the user specified -w W.
      $NUMBER_OF_CHUNK_GENERATED = `find $dir -type f | \\wc -l`;

      warn "You requested $N jobs but only $NUMBER_OF_CHUNK_GENERATED were created (due to -w $W)." if (2*$NUMBER_OF_CHUNK_GENERATED < $N);
   }
}

sub min{
   return ($_[0] < $_[1]) ? $_[0] : $_[1];
}

$NP = min($NUMBER_OF_CHUNK_GENERATED, 50) unless (defined($NP));


# Build all sub commands in CMD_FILE
verbose(1, "Building command file.");
verbose(2, "There is $NUMBER_OF_CHUNK_GENERATED commands to build.");
my $cmd_file = "$workdir/commands";
open(CMD_FILE, ">$cmd_file") or die "Unable to open command file";
for (my $i=0; $i<$NUMBER_OF_CHUNK_GENERATED; ++$i) {
   my $SUB_CMD = $CMD;
   my $index = sprintf("%4.4d", $i);

   # For each occurence of a file to merge, replace it by a chunk.
   foreach my $m (@MERGES) {
      my $file = "$workdir/" . $basename{$m} . "/$index";
      unless ($SUB_CMD =~ s/(^|\s|>)\Q$m\E($|\s|\))/$1$file$2/) {
         die "Unable to match $m and $file";
      }
   }

   if ($use_stripe_splitting) {
      my $done = "$workdir/" . $basename{$SPLITS[0]} . "/$index.done";
      foreach my $s (@SPLITS) {
         # NOTE: doing zcat file.gz | stripe.py is much much faster than
         # stripe.py file.gz.  Seems like the python's implementation of gzip is
         # quite slow.
         unless ($SUB_CMD =~ s/(^|\s|<)\Q$s\E($|\s|\))/$1<(zcat -f $s | stripe.py -i $i -m $N)$2/) {
            die "Unable to match $s";
         }
      }

      verbose(1, "\tStrip mode: Adding to the command list: $SUB_CMD");
      print(CMD_FILE "set -o pipefail; test -f $done || { { $debug_cmd $SUB_CMD; } && touch $done; }\n");
   }
   else {
      my @delete = ();
      # For each occurence of a file to split, replace it by a chunk.
      foreach my $s (@SPLITS) {
         my $file = "$workdir/" . $basename{$s} . "/$index";
         push(@delete, $file);
         unless ($SUB_CMD =~ s/(^|\s|<)\Q$s\E($|\s|\))/$1$file$2/) {
            die "Unable to match $s and $file";
         }
      }

      verbose(1, "\tAdding to the command list: $SUB_CMD");
      # By deleting the input chunks we say this block was properly process in
      # case of a resume is needed.
      print(CMD_FILE "set -o pipefail; test ! -f $delete[0] || { { $debug_cmd $SUB_CMD; } && mv $delete[0] $delete[0].done; }\n");
   }
}
close(CMD_FILE) or die "Unable to close command file!";


verbose(1, "Building merge command file.");
my $merge_cmd_file = "$workdir/commands.merge";
open(MERGE_CMD_FILE, ">$merge_cmd_file") or die "Unable to open merge command file";
foreach my $m (@MERGES) {
   my $dir = "$workdir/" . $basename{$m};
   my $sub_cmd;
   my $find_files = "set -o pipefail; find $dir -maxdepth 1 -type f | sort | xargs";
   if ($m =~ /.gz$/) {
      $sub_cmd = "$MERGE_PGM | gzip > $m";
   }
   else {   
      if ($m =~ m#/dev/stdout#) {
         $sub_cmd = "$MERGE_PGM";
      }
      elsif ($m =~ m#/dev/stderr#) {
         # MERGE_PGM never applies to stderr
         $sub_cmd = "cat 1>&2";
      }
      else {
         $sub_cmd = "$MERGE_PGM > $m";
      }
   }
   print MERGE_CMD_FILE "test ! -d $dir || { { $debug_cmd $find_files $sub_cmd; } && mv $dir $dir.done; }\n";
}
close(MERGE_CMD_FILE) or die "Unable to close merge command file!";


# Run all the sub commands
verbose(1, "Processing all chunks.");
my $cmd = "$debug_cmd run-parallel.sh $RP_OPTS $PSUB_OPTS $NOLOCAL $cmd_file $NP";
verbose(2, "cmd is: $cmd");
$rc = system($cmd);
die "Error running run-parallel.sh" unless($rc eq 0);


# If everything is fine merge all MERGES
verbose(1, "Merging final outputs.");
verbose(1, "Merging commands: ");
if ( $verbose >= 1 ) { `cat $merge_cmd_file >&2`; }
verbose(1, "End of merging commands.\n");
$cmd = "$debug_cmd bash $merge_cmd_file";
verbose(2, "cmd is: $cmd");
$rc = system($cmd);
die "Error merging output." unless($rc eq 0);

# Disabling elaborated merging since /dev/stdout & /dev/stderr doesn't work
# with run-parallel.sh.
if (0) {
   my $number_item_2_merge = scalar(@MERGES);
   if ($number_item_2_merge eq 1) {
      verbose(1, "Only one final output to merge.");
      my $rc;
      if ( $NOLOCAL ) {
         verbose(1, "Using the cluster.");
         $rc = system("run-parallel.sh $RP_OPTS $PSUB_OPTS -nolocal $merge_cmd_file 1");
      }
      else {
         verbose(1, "Using the current machine.");
         $rc = system("bash $merge_cmd_file");
      }
      die "Error merging output." unless($rc eq 0);
   }
   else {
      verbose(1, "$number_item_2_merge outputs to merge.");
      my $rc = system("run-parallel.sh $RP_OPTS $PSUB_OPTS $NOLOCAL $merge_cmd_file $number_item_2_merge");
      die "Error running run-parallel.sh when merging outputs." unless($rc eq 0);
   }
}


# Clean up on successful work
verbose(1, "Doing final cleanup.");
`rm -rf $workdir` unless($debug);

