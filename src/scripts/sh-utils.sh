#!/bin/bash
# $Id$

# @file sh_utils.sh 
# @brief Library of useful bash commands.
# 
# @author Samuel Larkin
# 
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2008, Sa Majeste la Reine du Chef du Canada /
# Copyright 2008, Her Majesty in Right of Canada

# error_exit "some error message" "optionnally a second line of error message"
# will exit with an error status, print the specified error message(s) on
# STDERR.
error_exit() {
   for msg in "$@"; do
      echo $msg >&2
   done
   echo "Use -h for help." >&2
   exit 1
}

# Verify that enough args remain on the command line
# syntax: one_arg_check <args needed> $# <arg name>
# Note that the syntax show above is meant to be part of a while/case structure
# for handling parameters, so that $# still includes the option itself.  exits
# with error message if the check fails.
arg_check() {
   if [ $2 -le $1 ]; then
      error_exit "Missing argument to $3 option."
   fi
}

# arg_check_int $value $arg_name exits with an error if $value does not
# represent an integer, using $arg_name to provide a meaningful error message.
arg_check_int() {
   expr $1 + 0 &> /dev/null
   RC=$?
   if [ $RC != 0 -a $RC != 1 ]; then
      error_exit "Invalid argument to $2 option: $1; integer expected."
   fi
}

# arg_check_pos_int $value $arg_name exits with an error if $value does not
# represent a positive integer, using $arg_name to provide a meaningful error
# message.
arg_check_pos_int() {
   expr $1 + 0 &> /dev/null
   RC=$?
   if [ $RC != 0 -a $RC != 1 ] || [ $1 -le 0 ]; then
      error_exit "Invalid argument to $2 option: $1; positive integer expected."
   fi
}

# Print a warning message.
warn() {
   echo "WARNING: $*" >&2
}

# Print a debug message.
debug() {
   if [[ $DEBUG ]]; then
      echo "<D> $*" >&2
   fi
}

# Print a verbose message.
verbose() {
   level=$1; shift
   if [[ $level -le $VERBOSE ]]; then
      echo "$*" >&2
   fi
}

# evaluates a command but also prints the command if verbose is on.
run_cmd() {
   cmd=$*
   verbose 1 $cmd
   if [[ ! $NOTREALLY ]]; then
      eval $cmd
   fi
}

# This library's help message.
_sh_utils_help() {
   echo "This is intended to be used as a library, not a stand-alone program."
}

# This file is intended to be a library and not an executable file.
if [[ $0 == "sh_utils.sh" ]]; then
   _sh_utils_help
   exit 1
fi


