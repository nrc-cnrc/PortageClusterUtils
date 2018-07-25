#!/usr/bin/env python

# @file stripe.py
# @brief Performs a strip split which allows splitting without using temporary files.
#
# @author Samuel Larkin
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2011, Sa Majeste la Reine du Chef du Canada /
# Copyright 2011, Her Majesty in Right of Canada

from __future__ import print_function

import sys
import gzip
import glob
import re 
from optparse import OptionParser


def sort_nicely( l ): 
   """ Sort the given list in the way that humans expect. 
   """ 
   convert = lambda text: int(text) if text.isdigit() else text 
   alphanum_key = lambda key: [ convert(c) for c in re.split('([0-9]+)', key) ] 
   l.sort( key=alphanum_key ) 


usage="stripe.py [options] [infile [outfile]]"
help="""
  Perform a striped split, assigning lines in a round-robin fashion to each
  chunk.  Intended for splitting files without creating temporary copies.
  stripe.py -r [infiles] will rebuild the whole file from striped pieces.
"""

parser = OptionParser(usage=usage, description=help)
parser.add_option("-i", dest="indices", type="string", default="0",
                  help="what indices to display [%default] valid value [0, m)"
                  + "-i [i:j) where 0 <= i < j <= m")
parser.add_option("-m", dest="modulo", type="int", default=3,
                  help="How many chunks aka modulo [%default]")
parser.add_option("-c", dest="complement", action="store_true", default=False,
                  help="writes lines that are NOT 0 <= i < j <=m [%default]")
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

# Check if the user provided a rane of indices or a single index.
all_indices = opts.indices.split(":")
index = int(all_indices[0])
jndex = index + 1
if len(all_indices) == 2:
   jndex = int(all_indices[1])
elif len(all_indices) > 2:
   print("Indices format is -i i:j where [i,j) where 0 <= i < j <= m.", file=sys.stderr)
   sys.exit(1)
# validate the index range.
if not (0 <= index < jndex <= opts.modulo):
   print("Indices format is -i i:j where [i,j) where 0 <= i < j <= m.", file=sys.stderr)
   sys.exit(1)

if opts.debug:
   print("index %d, jndex %d" % (index, jndex), file=sys.stderr)

if opts.verbose:
   print("options are:", opts, file=sys.stderr)
   print("positional args are:", args, file=sys.stderr)


def myopen(filename, mode='r'):
   "This function will try to open transparently compress files or not."
   if opts.debug: print("myopen: ", filename, " in ", mode, " mode", file=sys.stderr)
   if filename == "-":
      if mode == 'r':
         theFile = sys.stdin
      elif mode == 'w':
         theFile = sys.stdout
      else:
         print("Unsupported mode.", file=sys.stderr)
         sys.exit(1)
   elif filename[-3:] == ".gz":
      theFile = gzip.open(filename, mode+'b')
   else:
      theFile = open(filename, mode)
   return theFile


def rebuild():
   "This function will unstripe the output of a previous usage of stripe.py."
   def myOpenRead(filename):
      "Trying out a function closure."
      if opts.debug: print("myOpenRead: ", filename, file=sys.stderr)
      return myopen(filename, 'rb')

   # Open files from a pattern.
   inputfilenames = args
   # Let see if the user provided us with a pattern.
   if len(args) == 1:
      inputfilenames = glob.glob(args[0] + "*")
      sort_nicely(inputfilenames)  # Safer sort if filename are not properly sorted when using alpha sorting.
      if len(inputfilenames) == 0:
         # Looks like it wasn't a pattern, let's assume he provided us a list
         # of files instead.
         inputfilenames = args

   if len(inputfilenames) <= 0:
      print("Cannot find any file with ", inputfilenames, file=sys.stderr)
      sys.exit(1)

   if opts.verbose: print("Rebuilding output from ", repr(inputfilenames), file=sys.stderr)

   # What if the user provided use we more files than the os allows us to have opened at once?
   try:
      inputfiles = list(map(myOpenRead, inputfilenames))
   except IOError:
      print("You provided %d files to merge but the os doesn't allow that many file to be opened at once." % len(inputfilenames), file=sys.stderr)
      sys.exit(1)

   if opts.debug: print(inputfiles, file=sys.stderr)

   if sys.version_info >= (3, 0):
      outfile = sys.stdout.buffer
   else:
      outfile = sys.stdout

   cpt = 0
   M = len(inputfiles)
   while True:
      if M == 0: break
      index = cpt % M
      if opts.debug: print("\t", repr(index), file=sys.stderr)
      inputfile = inputfiles[index]
      line = inputfile.readline()
      if line == b'':
         inputfiles.pop(index)
         M -= 1
      else:
         outfile.write(line)
      cpt += 1


if opts.rebuild:
   if index + 1 != jndex:
      print("Not implemented yet!  You can only merge if you used -i without a range.", file=sys.stderr)
      sys.exit(1)
   rebuild()
else:
   # Performing a split
   # NOTE: look at import fileinput for line in fileinput.input(filenames): process(line)  to process all lines from a list of filenames.
   if sys.version_info >= (3, 0):
      infile  = myopen(args[0], 'rb') if len(args) >= 1 else sys.stdin.buffer
      outfile = myopen(args[1], 'wb') if len(args) == 2 else sys.stdout.buffer
   else:
      infile  = myopen(args[0], 'rb') if len(args) >= 1 else sys.stdin
      outfile = myopen(args[1], 'wb') if len(args) == 2 else sys.stdout

   cpt = 0
   for line in infile:
      step = cpt % opts.modulo
      # NOTE this is XOR
      if (opts.complement) ^ (index <= step < jndex):
         if (opts.numbered):
            outfile.write(repr(cpt))
            outfile.write('\t')
         outfile.write(line)
      cpt += 1


   infile.close()
   outfile.close()

