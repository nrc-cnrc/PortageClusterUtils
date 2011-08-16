#!/usr/bin/env python
# $Id$

# @file split.py
# @brief Performs a strip split which allows splitting without using temporary files.
#
# @author Samuel Larkin
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2011, Sa Majeste la Reine du Chef du Canada /
# Copyright 2011, Her Majesty in Right of Canada

import sys
import gzip
import glob
from optparse import OptionParser

usage="slit.py [options] [infile [outfile]]"
help="""
  Perform a striped split, assigning lines in a round-robin fashion to each
  chunk.  Intended for splitting files without creating temporary copies.
  split.py -r [infiles] will rebuild the whole file from striped pieces.
"""

parser = OptionParser(usage=usage, description=help)
parser.add_option("-i", dest="index", type="int", default=1,
                  help="what index to display [%default] valid value [0, m)")
parser.add_option("-m", dest="modulo", type="int", default=3,
                  help="How many chunks aka modulo [%default]")
parser.add_option("-n", dest="numbered", action="store_true", default=False,
                  help="Prefix each line with its line number [%default]")
parser.add_option("-r", dest="rebuild", action="store_true", default=False,
                  help="rebuild whole file from stripes [%default]")
parser.add_option("-v", dest="verbose", action="store_true", default=False,
                  help="write verbose output to stderr [%default]")
parser.add_option("-d", dest="debug", action="store_true", default=False,
                  help="write debug output to stderr [%default]")


(opts, args) = parser.parse_args()
if opts.rebuild:
   if len(args) == 0:
       parser.error("too few arguments to rebuild the output")
else:
   if len(args) > 2:
       parser.error("too many arguments")

if opts.verbose:
   print "options are:", opts
   print "positional args are:", args

# The index must be smaller than the modulo.
if opts.index >= opts.modulo:
   print >> sys.stderr, "Error the index is %d but must be in the range [0, %d)" % ( opts.index, opts.modulo )
   sys.exit(1)


def myopen(filename, mode='r'):
   "This function will try to open transparently compress files or not."
   if opts.debug: print >> sys.stderr, "myopen: " + filename + " in " + mode + " mode"
   if filename == "-":
      theFile = sys.stdin
   elif filename[-3:] == ".gz":
      theFile = gzip.open(filename, mode+'b')
   else:
      theFile = open(filename, mode)
   return theFile


def rebuild():
   "This function will unstripe the output of a previous usage of split.py."
   def myOpenRead(filename):
      "Trying out a function closure."
      if opts.debug: print >> sys.stderr, "myOpenRead: " + filename
      return myopen(filename, "r")

   # Open files from a pattern.
   inputfilenames = args
   # Let see if the user provided us with a pattern.
   if len(args) == 1:
      inputfilenames = glob.glob(args[0] + "*")
      inputfilenames.sort()
      if len(inputfilenames) == 0:
         # Looks like it wasn't a pattern, let's assume he provided us a list
         # of files instead.
         inputfilenames = args

   if len(inputfilenames) <= 0:
      print >> sys.stderr, "Cannot find any file with " + inputfilenames
      sys.exit(1)

   if opts.verbose: print >> sys.stderr, "Rebuilding output from " + repr(inputfilenames)

   inputfiles = map(myOpenRead, inputfilenames)
   if opts.debug: print >> sys.stderr, inputfiles

   cpt = 0
   M = len(inputfiles)
   while True:
      if M == 0: break
      index = cpt % M
      if opts.debug: print >> sys.stderr, "\t" + repr(index)
      file = inputfiles[index]
      line = file.readline()
      if line == "":
         inputfiles.pop(index)
         M -= 1
      else:
         print >> sys.stdout, line,
      cpt += 1


if opts.rebuild:
   rebuild()
else:
   # Performing a split
   # NOTE: look at import fileinput for line in fileinput.input(filenames): process(line)  to process all lines from a list of filenames.
   infile  = myopen(args[0], 'r') if len(args) >= 1 else sys.stdin
   outfile = myopen(args[1], 'w') if len(args) == 2 else sys.stdout

   cpt = 0
   for line in infile:
      if ((cpt % opts.modulo) == opts.index):
         if (opts.numbered):
            print >> outfile, repr(cpt) + "\t",
         print >> outfile, line,
      cpt += 1


   infile.close()
   outfile.close()

