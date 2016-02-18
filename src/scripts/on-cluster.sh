#!/bin/bash
#
# @file on-cluster.sh
# @brief Wrapper script to determine if running on a cluster in cluster-mode.
#
# @author Darlene Stewart based on which-test.sh by Eric Joanis
#
# Traitement multilingue de textes / Multilingual Text Processing
# Tech. de l'information et des communications / Information and Communications Tech.
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2015, Sa Majeste la Reine du Chef du Canada /
# Copyright 2015, Her Majesty in Right of Canada

## Usage: on-cluster.sh
##
##   Exit with status code 0 if in cluster mode, 1 otherwise.
##   Cluster mode is defined as running on a cluster without $PORTAGE_NOCLUSTER set.
##
##   Example use in a bash or sh script:
##     if on-cluster.sh; then
##       # treat as on a cluster
##     else
##       # treat as not on a cluster
##     fi
##
## Options:
##
##  -h       print this help message
##  -v       print verbose output
##  -type    write the type of cluster to sdtout: jobsub, qsub, none or disabled
##


usage() {
   cat $0 | grep "^##" | cut -c4-
   exit 2
}

[[ $# -gt 1 ]] && echo $'Error: on-cluster.sh accepts only one argument or option.\n' >&2 && usage
[[ "$1" == "-h" ]] && usage
[[ "$1" == "-v" ]] && VERBOSE=1 && shift
[[ "$1" == "-type" ]] && PRINT_TYPE=1 && shift
[[ $# -gt 0 ]] && echo "Error: superfluous argument or option: $*"$'\n' >&2 && usage

# Hack: we detect that we're running on a cluster by looking for jobsub or qsub.
# Defining the PORTAGE_NOCLUSTER environment variable to a non-empty string
# hides jobsub/qsub globally by altering what this script returns.
if [[ $PORTAGE_NOCLUSTER ]]; then
   [[ $VERBOSE ]] && echo PORTAGE_NOCLUSTER set >&2
   [[ $PRINT_TYPE ]] && echo disabled
   exit 1
elif [[ -x "`which jobsub 2> /dev/null`" ]]; then
   [[ $VERBOSE ]] && echo found: jobsub >&2
   [[ $PRINT_TYPE ]] && echo jobsub
   exit 0
elif [[ -x "`which qsub 2> /dev/null`" ]]; then
   [[ $VERBOSE ]] && echo found: qsub >&2
   [[ $PRINT_TYPE ]] && echo qsub
   exit 0
else
   [[ $VERBOSE ]] && echo not found: jobsub, qsub >&2
   [[ $PRINT_TYPE ]] && echo none
   exit 1
fi
