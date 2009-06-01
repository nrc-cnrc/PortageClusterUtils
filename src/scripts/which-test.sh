#!/bin/sh
# $Id$
#
# @file which-test.sh 
# @brief portable wrapper for which, with reliable status code.
#
# @author Eric Joanis
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2005, Sa Majeste la Reine du Chef du Canada /
# Copyright 2005, Her Majesty in Right of Canada

## Usage: which-test.sh <prog> prog
## Exists with status code 0 if prog is on the path and executable, 1 otherwise.
## Example use in a bash or sh script:
##    if which-test.sh prog; then
##       # prog is available; you can use it
##    else
##       # prog doesn't exist, isn't on the path, or isn't executable;
##       # work around it or give up
##    fi
##
## Options:
##
##  -h(elp)        print this help message
##
## Motivation for this script: on some Solaris and Mac installations, "which"
## does not return a fail status code when the program doesn't exist.  This test
## here has been tested on Solaris, Mac OS X, and various Linux distros.


usage() {
	cat $0 | grep "^##" | cut -c4-
}

[ "$1" == "-h" ] && usage
[ $# -eq 0 ] && usage

# Hack: we detect that we're running on a cluster by looking for qsub.
# Defining the PORTAGE_NOCLUSTER environment variable to a non-empty string
# hides qsub globally by altering what this script returns.
if [ "$1" = qsub -a -n "$PORTAGE_NOCLUSTER" ]; then
   exit 1
elif [ -x "`which $1 2> /dev/null`" ]; then
   exit 0
else
   exit 1
fi
