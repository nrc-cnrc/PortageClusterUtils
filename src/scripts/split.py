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
from optparse import OptionParser

usage="pslit.py [options] [infile [outfile]]"
help="""
  Perform a strip split on the input.
  Allows to split without creating temporary files.
"""

parser = OptionParser(usage=usage, description=help)
parser.add_option("-i", dest="index", type="int", default=1,
                  help="what index to display [%default] valid value [0, m)")
parser.add_option("-m", dest="modulo", type="int", default=3,
                  help="How many chunks aka modulo [%default]")
parser.add_option("-n", dest="numbered", action="store_true", default=False,
                  help="Prefix each line with their line value [%default]")
parser.add_option("-v", dest="verbose", action="store_true", default=False,
                  help="write verbose output to stderr [%default]")

(opts, args) = parser.parse_args()
if len(args) > 2:
    parser.error("too many arguments")

if opts.verbose:
   print "options are:", opts
   print "positional args are:", args

# The index must be smaller than the modulo.
if opts.index >= opts.modulo:
   print >> sys.stderr, "Error the index is %d but must be in the range [0, %d)" % ( opts.index, opts.modulo )

def myopen(filename, mode):
   "This function will try to open transparently compress files or not."
   if filename == "-":
      theFile = sys.stdin
   elif filename[-3:] == ".gz":
      theFile = gzip.open(filename, mode+'b')
   else:
      theFile = open(filename, mode)
   return theFile


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

