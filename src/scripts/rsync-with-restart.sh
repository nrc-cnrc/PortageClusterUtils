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

[[ $0 =~ [^/]*$ ]] && PROG=$BASH_REMATCH || PROG=$0

usage() {
   for msg in "$@"; do
      echo "$msg" >&2
   done
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

  Warning: the destination directory should not exist, because files found
  there will be deleted if they don't also exist in the source directory.

Options:
  -h(elp)    Print this help message
  -f(orce)   Run this script even if the destination directory exists
==EOF==

   if [[ $@ ]]; then
      exit 1
   else
      exit 0
   fi
}

while [[ $# -gt 0 ]]; do
   case "$1" in
   -f|--force) FORCE=1;;
   -*) usage;;
   *) break;;
   esac
   shift
done

[[ $# -eq 2 ]] || usage "ERROR: this script takes exactly two arguments."

shopt -s compat31

DEST_EXISTS=
if [[ $2 =~ "(..*):(..*)" ]]; then
   DEST_HOST=${BASH_REMATCH[1]}
   DEST_PATH=${BASH_REMATCH[2]}
   if ! ssh $DEST_HOST true; then
      echo "$PROG ERROR: cannot connect to destination host $DEST_HOST. Aborting."
      exit 1
   fi
   if ssh "$DEST_HOST" test -e "\"$DEST_PATH\""; then
      DEST_EXISTS=1
   fi
else
   if [[ -e $2 ]]; then
      DEST_EXISTS=1
   fi
fi >&2

if [[ $DEST_EXISTS ]]; then
   if [[ $FORCE ]]; then
      echo "$PROG Warning: Destination directory $2 exists."
      echo "Proceeding anyway because --force was specified."
      echo "Files in the destination will be deleted if they don't exist in the source."
   else
      echo "$PROG ERROR: destination directory $2 exists. Aborting."
      exit 1
   fi
fi >&2


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

