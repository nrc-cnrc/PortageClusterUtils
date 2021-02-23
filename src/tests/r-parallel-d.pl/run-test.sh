#!/bin/bash

# @file run-test.sh
# @brief Unittest for r-parallel-d.pl.
#
# @author Samuel Larkin
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2010, Sa Majeste la Reine du Chef du Canada /
# Copyright 2010, Her Majesty in Right of Canada

set -e   # Exit when an error occurs.

make clean
make gitignore

# If we're already in a run-parallel instance,
#{ ps -o pid,ppid,tty,time,args | egrep '^ *[0-9]+ +1 [^g]*r-parallel-d.pl$'; } &&

# Start run-parallel.sh and have the watch dog thread to verify for run-parallel.sh every 30 seconds.
# EJJ 2016: we now use setsid so that the run-parallel.sh instance and all its children
# can be found using ps -g $MASTER_PID
R_PARALLEL_D_PL_DEBUG=1 R_PARALLEL_D_PL_SLEEP_TIME=8 setsid run-parallel.sh -nocluster -v -v -e "sleep 16" -e "sleep 16" -e "sleep 16" 1 >& log.debug &
MASTER_PID=$!
echo PID $MASTER_PID

# Checking the functionality:
# - wait some time, enough for the first job to be finished plus half
#   way through the first watch dog loop for the second job;
# - kill the master which is run-parallel.sh
# - look for r-parallel-d.pl which should still be running at this point;
# - wait for for the watch dog to do its job;
# - check again to see if r-parallel-d.pl which should be gone at this point;
# - for user, print a status message about the process.
EXIT_STATUS=0
echo sleep 20 &&
     sleep 20 &&
echo ps before kill &&
     ps -o pid,ppid,pgid,sid,tty,time,args -g $MASTER_PID &&
echo kill -9 $MASTER_PID &&
     kill -9 $MASTER_PID &&
echo ps just after kill &&
     ps -o pid,ppid,pgid,sid,tty,time,args -g $MASTER_PID &&
     { ps -o pid,ppid,pgid,sid,tty,time,args -g $MASTER_PID | egrep '^ *[0-9]+ +1 [^g]*r-parallel-d.pl$'; } &&
echo sleep 8 &&
     sleep 8 &&
echo ps 8 seconds later &&
     { ps -o pid,ppid,pgid,sid,tty,time,args -g $MASTER_PID || : ; } &&
! { ps -o pid,ppid,pgid,sid,tty,time,args -g $MASTER_PID | egrep '^ *[0-9]+ +1 [^g]*r-parallel-d.pl$'; } &&
echo "SUCCESS" || { echo "FAILED" ; EXIT_STATUS=1; }

exit $EXIT_STATUS
