#!/bin/bash
#
# @file which-test.sh 
# @brief Portable wrapper for which, with reliable status code.
#
# @author Eric Joanis
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2005, Sa Majeste la Reine du Chef du Canada /
# Copyright 2005, Her Majesty in Right of Canada

## Usage: which-test.sh PROG
## Exits with status code 0 if PROG is on the path and executable, 1 otherwise.
## Example use in a bash or sh script:
##    if which-test.sh PROG; then
##       # PROG is available; you can use it
##    else
##       # PROG doesn't exist, isn't on the path, or isn't executable;
##       # work around it or give up
##    fi
##
## Options:
##
##  -h       print this help message
##  -v       print verbose output
##
## Motivation for this script: on some Solaris and Mac installations, "which"
## does not return a fail status code when the program doesn't exist.  This
## script has been tested and works correctly on Solaris, Mac OS X, and various
## Linux distros.


usage() {
   cat $0 | grep "^##" | cut -c4-
}

[[ "$1" == "-h" ]] && usage
[[ "$1" == "-v" ]] && VERBOSE=1 && shift
[[ $# -eq 0 ]] && usage

# Hack: we detect that we're running on a cluster by looking for jobsub or qsub.
# Defining the PORTAGE_NOCLUSTER environment variable to a non-empty string
# hides jobsub/qsub globally by altering what this script returns.
if [[ $1 = jobsub && $PORTAGE_NOCLUSTER ]]; then
   [[ $VERBOSE ]] && echo ignoring jobsub >&2
   exit 1
elif [[ $1 = qsub && $PORTAGE_NOCLUSTER ]]; then
   [[ $VERBOSE ]] && echo ignoring qsub >&2
   exit 1
elif [[ -x "`which $1 2> /dev/null`" ]]; then
   [[ $VERBOSE ]] && echo found: $1 >&2
   exit 0
else
   [[ $VERBOSE ]] && echo not found: $1 >&2
   exit 1
fi
