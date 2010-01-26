#!/bin/bash
# $Id$

# @file cvs-attic-list.sh
# @brief List all files in the Attic under the current directory tree.
#
# @author Eric Joanis
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2009, Sa Majeste la Reine du Chef du Canada /
# Copyright 2009, Her Majesty in Right of Canada

source `dirname $0`/sh_utils.sh

usage() {
   for msg in "$@"; do
      echo $msg >&2
   done
   cat <<==EOF== >&2

Usage: cvs-attic-list.sh [-h(elp)]

   List all files in the Attic under the current directory tree.
   Must be executed within a sandbox.

   Caveat: this script assumes that all files are initially checked is as
   revision 1.1, which is the default in cvs.

==EOF==

    exit 1
}

while [[ $# -gt 0 ]]; do
   case "$1" in
   -h|-help)            usage;;
   -d|-debug)           DEBUG=1;;
   *)                   break;;
   esac
   shift
done

[[ $# -gt 0 ]]  && usage "Superfluous argument(s) $*"

[[ -r CVS/Repository ]] || error_exit "This directory does not appear to be a CVS sandbox."

REPOSITORY=`cat CVS/Repository`

{ { cvs rdiff -r1.1 -s $REPOSITORY |
   grep '\bis removed\b' |
   sed -e "s|File $REPOSITORY/\?||" \
       -e 's| .*||'
} 3>&1 2>&3 1>&2 | grep -v 'cvs rdiff: Diffing'
} 3>&1 2>&3 1>&2
