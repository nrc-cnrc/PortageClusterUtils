#!/bin/bash

# @file rsync-with-restart.sh
# @brief Self-resuming and recovering copy that tried until the copy is really done.
# @author Eric Joanis
# 
# Traitement multilingue de textes / Multilingual Text Processing
# Tech. de l'information et des communications / Information and Communications Tech.
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2015, Sa Majeste la Reine du Chef du Canada /
# Copyright 2015, Her Majesty in Right of Canada

usage() {
   for msg in "$@"; do
      echo $msg >&2
   done
   [[ $0 =~ [^/]*$ ]] && PROG=$BASH_REMATCH || PROG=$0
   cat <<==EOF== >&2

Usage: $PROG SOURCE DESTINATION

Recommended usage:
  psub $PROG 132.246.128.2nn:/path/on/MATS-machine /path/on/Balzac

  Run rsync repeatedly until the copy has completed successfully. Useful in an
  unstable network environment where rsync often aborts before completion.

  The recommendation is to run this script on a compute node on Balzac, not on
  a MATS machine.  Reason: minimize load on the head node; all other uses of
  rsync, scp or this script will impose an undesirable load on the head node.

  Warning: if the rsync commands fails due to a non-network related reason
  (path or permission errors, e.g.), it will keep trying every 30 seconds
  anyway. Inspect your job logs or the destination folder to make sure the copy
  is really starting.  (qpeek -e JOBID can help.)
==EOF==

   exit 1
}

while [[ $# -gt 0 ]]; do
   case "$1" in
   -*) usage;;
   *) break;;
   esac
   shift
done

[[ $# -eq 2 ]] || usage "Error: This script takes exactly two arguments."

iter=0
while true; do 
   iter=$((iter+1))
   echo ITER $iter
   echo rsync -arz --partial --timeout=30 --delete --stats "$@"
   if time rsync -arz --partial --timeout=30 --delete --stats "$@"; then
      echo "Success!"
      break
   fi
   echo "Problem detected. Sleeping 30 seconds before trying again."
   sleep 30
done >&2

