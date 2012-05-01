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

   -rBRANCHNAME Show only revisions for branch BRANCHNAME
   -h|-help     Show this help message
   -diff        Show differences between consecutive versions intead

==EOF==

    exit 1
}

BRANCHTAG=-b # default is main branch only = trunk
while [[ $# -gt 0 ]]; do
   case "$1" in
   -r*)                 BRANCHTAG=$1;;
   -h|-help)            usage;;
   -d|-debug)           DEBUG=1;;
   -diff)               DIFF=1;;
   *)                   break;;
   esac
   shift
done

[[ $# -eq 0 ]]  && usage "Missing cvs_file argument"
CVS_FILE=$1
shift
[[ $# -gt 0 ]]  && usage "Superfluous argument(s) $*"

REVISIONS=`cvs log $BRANCHTAG -N $CVS_FILE | grep '^revision ' | cut -d' ' -f 2`
[[ $DEBUG ]] && echo REVISIONS: $REVISIONS

[[ ! "$REVISIONS" ]] && usage "No revisions found for $CVS_FILE"

if [[ $DIFF ]]; then
   if [[ $BRANCHTAG != -b ]]; then
      BASEREV=`echo $REVISIONS | perl -nle 's/\.\d+\.\d+$//; @a = split; print pop @a;'`
   else
      BASEREV=0.0
   fi
   [[ $DEBUG ]] && echo BASEREV: $BASEREV
   REVISIONS="$REVISIONS $BASEREV"
fi

trap "echo cvs-cat-all-revisions.sh caught a signal\; aborting. >&2; exit 1" 1 2 3 11 13 14 15 

if [[ -t 1 ]]; then
   MYPAGER=less
else
   MYPAGER=cat
fi

if [[ $DIFF ]]; then
   next_rev=""
   for rev in $REVISIONS; do
      if [[ $next_rev ]]; then
         echo "=============================================================================";
         cvs log -N -r$next_rev $CVS_FILE 2>&1 | perl -e 'while (<>) { last if /^-----------------*$/ } while (<>) { print }'
         echo "cvs diff -r$rev -r$next_rev $CVS_FILE 2>&1 | sed \"s/^/-$rev+$next_rev: /\""
         cvs diff -r$rev -r$next_rev $CVS_FILE 2>&1 | sed "s/^/-$rev+$next_rev: /"
      fi
      next_rev=$rev
   done
else
   for rev in $REVISIONS; do
      echo "=============================================================================";
      cvs log -N -r$rev $CVS_FILE 2>&1 | perl -e 'while (<>) { last if /^-----------------*$/ } while (<>) { print }'
      cvs up -p -r$rev $CVS_FILE 2>&1 | sed "s/^/$rev: /"
   done
fi | $MYPAGER
