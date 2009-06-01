#!/bin/bash
# $Id$

# @file cvs-cat-all-revisions.sh 
# @brief Show all revisions of a file in a continuous stream.
#
# @author Eric Joanis
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2008, Sa Majeste la Reine du Chef du Canada /
# Copyright 2008, Her Majesty in Right of Canada

usage() {
   for msg in "$@"; do
      echo $msg >&2
   done
   cat <<==EOF== >&2

Usage: cvs-cat-all-revisions.sh [-h(elp)] [-diff] cvs_file

   Show all revisions of cvs_file in a continuous stream.

Options:

   -h|-help     Show this help message
   -diff        Show differences between consecutive versions intead

==EOF==

    exit 1
}

while [ $# -gt 0 ]; do
   case "$1" in
   -h|-help)            usage;;
   -d|-debug)           DEBUG=1;;
   -diff)               DIFF=1;;
   *)                   break;;
   esac
   shift
done

test $# -eq 0   && usage "Missing cvs_file argument"
CVS_FILE=$1
shift
test $# -gt 0   && usage "Superfluous arguments $*"

REVISIONS=`cvs log -b -N $CVS_FILE | grep '^revision ' | cut -d' ' -f 2`
test $DEBUG && echo REVISIONS: $REVISIONS

test -z "$REVISIONS" && usage "No revisions found for $CVS_FILE"

if [ $DIFF ]; then
   next_rev=""
   for rev in $REVISIONS; do
      if [ $next_rev ]; then
         cvs diff -r$rev -r$next_rev $CVS_FILE 2>&1 | sed "s/^/-$rev+$next_rev: /"
      fi
      next_rev=$rev
   done
else
   for rev in $REVISIONS; do
      cvs up -p -r$rev $CVS_FILE 2>&1 | sed "s/^/$rev: /"
   done
fi
