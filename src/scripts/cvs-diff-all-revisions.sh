#!/bin/bash
# $Id$

# @file cvs-diff-all-revisions.sh 
# @brief Show all revisions of a file in a continuous stream.
#
# @author Eric Joanis
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2009, Sa Majeste la Reine du Chef du Canada /
# Copyright 2009, Her Majesty in Right of Canada

usage() {
   for msg in "$@"; do
      echo $msg >&2
   done
   cat <<==EOF== >&2

Usage: cvs-diff-all-revisions.sh [-h(elp)] cvs_file

   Show differences between each consecutive version of cvs_file in a
   continuous stream.

Options:

   -h|-help     Show this help message

==EOF==

    exit 1
}

while [ $# -gt 0 ]; do
   case "$1" in
   -h|-help)            usage;;
   -d|-debug)           DEBUG=$1;;
   -diff)               ;; # parsed just so calling syntax is same as cvs-cat-all-revisions.
   *)                   break;;
   esac
   shift
done

test $# -eq 0   && usage "Missing cvs_file argument"
CVS_FILE=$1
shift
test $# -gt 0   && usage "Superfluous argument(s) $*"

exec cvs-cat-all-revisions.sh -diff $DEBUG $CVS_FILE
