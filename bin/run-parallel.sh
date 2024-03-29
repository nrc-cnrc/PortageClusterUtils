#!/bin/bash

# @file run-parallel.sh
# @brief Run a series of jobs provided as STDIN on parallel distributed
# workers managed by r-parallel-d.pl and r-parallel-worker.pl.
#
# @author Eric Joanis
#
# Traitement multilingue de textes / Multilingual Text Processing
# Tech. de l'information et des communications / Information and Communications Tech.
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2005, 2016, Sa Majeste la Reine du Chef du Canada /
# Copyright 2005, 2016, Her Majesty in Right of Canada

# Requirements for the run-parallel.sh suite:
# Make sure the following are in your path:
# - parallelize.pl
# - time-mem
# - process-memory-usage.pl
# - psub
# - jobdel
# - jobst
# - jobsub
# - r-parallel-d.pl
# - r-parallel-worker.pl
# - run-parallel.sh
# - sum.pl
# - on-cluster.sh

# Portage is developed with bash 3, and uses the bash 3.1 RE syntax, which
# changed from version 3.2.  Set "compat31" if we're using bash 3.2, 4 or more
# recent, to preserve the expected syntax.
shopt -s compat31 >& /dev/null || true

usage() {
   for msg in "$@"; do
      echo -- $msg >&2
   done
   cat <<==EOF== >&2

Usage: run-parallel.sh [options] FILE_OF_COMMANDS N
       run-parallel.sh [options] -e CMD1 [-e CMD2 ...] N
       run-parallel.sh [options] -c CMD CMD_OPTS
       run-parallel.sh {add M,quench M,kill} JOB_ID

  Execute commands on N parallel workers, each submitted with psub on a
  cluster, or run as background tasks otherwise.  Keeps the CPUs constantly
  busy until all jobs are completed.

Exit status:
  0: all OK
  1: usage error
  2: at least one job had a non-zero exit status
  -1/255: something strange happened, probably a crash of some kind

Arguments:

  FILE_OF_COMMANDS  A file with one command per line (escape the newline with
      \ to insert multi-line commands), in valid bash syntax.  Use - for
      stdin.  Each command may include redirections and pipes, will run in the
      current directory, and will be aware of the current value of PATH.
      Commands may run in an arbitrary order.  Each command should explicitly
      redirect its output, otherwise it goes in the bit bucket by default.

  or

  -e CMD#  A command, properly quoted.  Specifying -e once or more is
      equivalent to specifying a FILE_OF_COMMANDS with one or more lines.
      This option is provided so that run-parallel.sh can be used as a
      "blocking" psub:
          run-parallel.sh -nolocal -e "CMD CMD_OPTS" 1
      is equivalent to "psub CMD CMD_OPTS" except that, unlike psub, it
      only returns when CMD has finished running, and the exit status of
      run-parallel.sh will be 0 iff the exit status of CMD was 0.

  or

  -c CMD CMD_OPTS is equivalent to -e "CMD CMD_OPTS" 1.  When -c is
      found, the rest of the command line is the command to execute.  Implies
      -q -nolocal and N = 1.  Special characters must still be escaped:
          run-parallel -c CMD CMD_OPTS \> OUTPUT_FILE
      is a more convenient solution to the blocking psub problem.
      Note: set SHELL=run-parallel.sh in a Makefile to run all commands on the
      cluster.  Parallelize with make -j N.  The Makefile does not need any
      further modifications.  In particular, you need not escape pipes and
      redirections, since make will already do so for you.
      With -c, run-parallel.sh tries to mimic sh -c: the exit status, stderr
      and stdout of the command are propagated through run-parallel.sh.
      Add RP_PSUB_OPTS="psub opts" before the command to pass options to psub.
      Since make cannot be recursely called accross nodes, it's safer to
      disable recursive call to make using: _LOCAL=1 \${MAKE} or _NOPSUB=1
      \${MAKE} when using run-parallel.sh as make's SHELL.

  N Number of workers to launch (may differ from the number of commands).

General options:

  -p PFX        Work dir prefix [].
                It's the user responsibility to delete <PFX> as it may contain
                other useful file from other scripts.
  -h(elp)       Print this help message.
  -d(ebug)      Print debugging information.
  -q(uiet)      Quiet mode only prints error messages and the resource summary.
  -quiet-daemon Make the daemon quiet, but not all of run-parallel.sh
  -v(erbose)    Increase verbosity level.  If specified once, show the daemon's
                logs, each worker's logs, etc.  Yet more output is produced if
                specified twice.
  -on-error ACTION  Specifies how to proceed when a command is reported to
                have failed (i.e., its exit code is not 0); ACTION may be:
       continue Ignore return codes and execute all commands anyway
       stop     Let commands that have started end, but don't launch any more
       killall  Kill all workers immediately and exit                    [stop]
  -k(eep-going) Short-hand for -on-error continue.
  -subst MATCH  Have workers substite MATCH in each command by their worker-id
                before running it.
  -period P     Sleep for P seconds between monitoring samples. [60]
  -unordered-cat   Outputs to stdout, in an unordered fashion, stdouts from all
                   the workers.
  -worker-cmd CMD  Use CMD instead of r-parallel-worker.pl to run workers.
                   CMD must include the strings __HOST__ and __PORT__, which
                   will be replaced by the daemon's host and port.

Cluster mode options:

  -N            adds a user defined name to the workers. []
                Useful when using run-parallel.sh -nolocal -e "job" 1
  -highmem      Use 2 CPUs per worker, for extra extra memory.  [propagate the
                number of CPUs of master job]
  -nohighmem    Use only 1 CPU per worker, even if master job had more.
  -nolocal      psub all workers [run one worker locally, unless on head node]
  -local L      run L jobs locally [calculated automatically]
  -noc(luster)  force non-cluster mode [auto-detect if we're on a cluster]
  -j J          submit J workers per psub job using psub's -j J option
  -quota T      When workers have done T minutes of work, re-psub them;
                0 means no quota [30, or 0 if -j is specified]
  -psub         Provide custom psub options.
  -qsub         Provide custom qsub options.

Resource propagation from the master job to worker jobs (cluster mode only):

  Priority: workers will be submitted with a priority 1 level below the master.

  Number of CPUs: by default, this is inherited from the psub command used to
  launch run-parallel.sh (or used to launch a script that launches
  run-parallel.sh). It can be overridden by the -psub -<num-jobs> option to
  run-parallel.sh. Resource requirements may necessitate an extra job in this
  case. Here are some examples, with resulting job characteristics:

    psub -2 run-parallel.sh jobfile 10           # 10 2-cpu jobs
    psub -4 run-parallel.sh -psub -2 jobfile 10  # 1 4-cpu job + 9 2-cpu jobs
    psub -1 run-parallel.sh -psub -2 jobfile 10  # 1 1-cpu job + 10 2-cpu jobs

  The results would be exactly the same if "run-parallel.sh ..." were called
  from inside a script, which is a more sensible usage. Eg, assuming "myscript"
  calls "run-parallel.sh -psub -2 jobfile 10", then:

    psub -1 myscript   # 1 1-cpu job + 10 2-cpu jobs

Dynamic options:

  To add M new workers on the fly, identify the PBS_JOBID of the master, or
  the run-p.SUFFIX/psub_cmd file where it is running, and run:
     run-parallel.sh add M PBS_JOBID
  or
     run-parallel.sh add M run-p.SUFFIX/psub_cmd

  To quench the process and remove M workers, replace "add" by "quench".

  To kill the process and all its workers, replace "add M" by "kill".

  To view how many workers are currently working, in the process of being added
  or in the process of been quenched.
     run-parallel.sh num_worker PBS_JOBID
  or
     run-parallel.sh num_worker run-p.SUFFIX/psub_cmd

==EOF==

   exit 0 # exit 0, not 1: it's not an error to call this script with -h!!!
}

error_exit() {
   echo -n "run-parallel.sh fatal error: " >&2
   for msg in "$@"; do
      echo $msg >&2
   done
   echo "Use -h for help." >&2
   GLOBAL_RETURN_CODE=1
   exit 1
}

arg_check() {
   if (( $2 <= $1 )); then
      error_exit "Missing argument to $3 option."
   fi
}

arg_check_pos_int() {
   expr $1 + 0 &> /dev/null
   RC=$?
   if [ $RC != 0 -a $RC != 1 ] || [ $1 -le 0 ]; then
      error_exit "Invalid argument to $2 option: $1; positive integer expected."
   fi
}

# Print a warning message
warn()
{
   echo "WARNING: $*" >&2
}

# Return 1 (false) if we're running a PBS job, and therefore are on a compute
# node, 0 (true) otherwise, in which case we assume we're on a head/login node.
on_head_node()
{
   if [[ $JOB_ID ]]; then
      return 1
   else
      return 0
   fi
}

if [[ $PBS_JOBID ]]; then
   SHORT_JOB_ID=${PBS_JOBID:0:13}
elif [[ $GECOSHEP_JOB_ID ]]; then
   SHORT_JOB_ID=$GECOSHEP_JOB_ID
else
   SHORT_JOB_ID=$$.local
fi

# We use $HOSTNAME in various places, initialize it in case that wasn't done yet.
export HOSTNAME=`hostname`

WORKER_CPU_STRING="Run-parallel-worker-CPU"
START_TIME=`date +"%s"`
CLUSTER_TYPE=`on-cluster.sh -type`
if [[ $CLUSTER_TYPE == sbatch ]]; then
   QDEL=scancel
elif [[ $CLUSTER_TYPE == jobsub ]]; then
   QDEL=jobdel
else
   QDEL=qdel
fi
NUM=
NOLOCAL=
OPT_J=
if on_head_node; then NOLOCAL=1; fi
USER_LOCAL=
NOCLUSTER=
VERBOSE=1
DEBUG=
SAVE_ARGS="$@"
CMD_FILE=
CMD_LIST=
EXEC=
UNORDERED_CAT=
QUOTA=
PREFIX=""
JOB_NAME=
JOBSET_FILENAME=`mktemp -u run-p.tmpjobs.$SHORT_JOB_ID.XXX` || error_exit "Can't create temporary jobs file."
ON_ERROR=stop
SUBST=
MON_PERIOD=60
PSUBOPTS=
#TODO: run-parallel.sh -c RP_ARGS -... -... {-exec | -c} cmd args
# This would allow a job in a Makefile, which uses SHELL = run-parallel.sh, to
# specify some parameters other than the default.
while (( $# > 0 )); do
   case "$1" in
   -p)             arg_check 1 $# $1; PREFIX="$2"; shift;;
   -e)             arg_check 1 $# $1; CMD_LIST=1
                   echo "$2" >> $JOBSET_FILENAME; shift;;
   -unordered-cat|-unordered_cat) UNORDERED_CAT=1;;
   -p|-period)     arg_check 1 $# $1; MON_PERIOD=$2; shift;;
   -exec|-c)       arg_check 1 $# $1; shift; NOLOCAL=1; EXEC=1
                   VERBOSE=$(( $VERBOSE - 1 ))
                   # Special case for make's sake - make invokes uname -s twice
                   # before executing each and every command!
                   test "$*" = "uname -s" && exec $*

                   # NOTE: Make cannot communicate accross machine.
                   # If this invocation is for make, run it locally.
                   if [[ "$*" =~ ^make ]]; then
                      test -n "$DEBUG" && echo "  <D> Found a make command: $*" >&2
                      exec $*;
                   fi

                   # If the user specifies local, run it locally.
                   if [[ $* =~ '(_LOCAL|_NOPSUB)=[^ ]* (.*)' ]]; then
                      test -n "$DEBUG" && echo "  <D> Found a local command: ${BASH_REMATCH[1]}" >&2
                      test -n "$DEBUG" && echo "  <D> Running: ${BASH_REMATCH[2]}" >&2
                      exec bash -c "${BASH_REMATCH[2]}"
                   fi

                   # Thanks germannu for the following regex :D
                   #echo $* | perl -ne '/RP_PSUB_OPTS=(([\x22\x27]).*?[^\\]\2|[^ \x22\x27\n]+)/; print "$1\n";'
                   # Needs some extra escaping for \ and we also remove extra quoting.
                   RP_PSUB_OPTS=`echo $* | perl -pe '/RP_PSUB_OPTS=(([\x22\x27]).*?[^\\\\]\2|[^ \x22\x27\n]+)/; $_=$1; s/^[\x22\x27]//; s/[\x22\x27]$//;'`

                   test -n "$DEBUG" && echo "  <D> RP_PSUB_OPTS: $RP_PSUB_OPTS" >&2;
                   test -n "$DEBUG" && echo "  <D> all: $*" >&2
                   PSUBOPTS="$PSUBOPTS $RP_PSUB_OPTS";
                   echo "$*" >> $JOBSET_FILENAME;

                   if [[ $RP_PSUB_OPTS =~ '-N ([^ ][^ ]*)' ]]; then
                      JOB_NAME="${BASH_REMATCH[1]}"
                   fi

                   break;;
   -highmem)       PSUBOPTS="$PSUBOPTS -2";;
   -nohighmem)     PSUBOPTS="$PSUBOPTS -1";;
   -nolocal)       NOLOCAL=1; USER_LOCAL=;;
   -local)         arg_check 1 $# $1; USER_LOCAL="$2"; NOLOCAL=; shift;;
   -noc|-nocluster) NOCLUSTER=1;;
   -j)             arg_check 1 $# $1; arg_check_pos_int $2 $1; OPT_J=$2; shift;;
   -on-error)      arg_check 1 $# $1; ON_ERROR="$2"; shift;;
   -k|-keep-going) ON_ERROR=continue;;
   -N)             arg_check 1 $# $1; JOB_NAME="$2-"; shift;;
   -quota)         arg_check 1 $# $1; QUOTA="$2"; shift;;
   -psub|-psub-opts|-psub-options)
                   arg_check 1 $# $1; PSUBOPTS="$PSUBOPTS $2"; shift;;
   -qsub|-qsub-opts|-qsub-options)
                   arg_check 1 $# $1; QSUBOPTS="$QSUBOPTS $2"; shift;;
   -subst)         arg_check 1 $# $1; WORKER_SUBST=$2; shift;;
   -worker-cmd)    arg_check 1 $# $1; USER_WORKER_CMD=$2; shift;;
   -v|-verbose)    VERBOSE=$(( $VERBOSE + 1 ));;
   -q|-quiet)      VERBOSE=0;;
   -quiet-daemon)  QUIET_DAEMON=1;;
   -cleanup)       CLEANUP=1;; # kept here so scripts using it don't have to be patched.
   -d|-debug)      DEBUG=1;;
   -debug-trap)    DEBUG_TRAP=1;;
   -debug-cleanup) DEBUG_CLEANUP=1;;
   -h|-help)       usage;;
   -unit-test)     UNIT_TEST=1;; # hidden option for unit testing
   *)              break;;
   esac
   shift
done

# EJJ Oct2016: -j is not really compatible with -quota: -j disabled quota by
# default, unless the user explicitly specified  quota value.
[[ $OPT_J && ! $QUOTA ]] && QUOTA=0

# Special commands pre-empt normal operation
if [[ "$1" = add || "$1" = quench || "$1" = kill || "$1" = num_worker ]]; then
   # Special command to dynamically add or remove worders to/from a job in
   # progress
   if [[ "$1" = kill ]]; then
      if [[ $# != 2 ]]; then
         error_exit "Kill requests take exactly 2 parameters."
      fi
      REQUEST_TYPE=$1
      JOB_ID_OR_CMD_FILE=$2
   elif [[ "$1" = num_worker ]]; then
      if [[ $# != 2 ]]; then
         error_exit "num_worker requests take exactly 2 parameters."
      fi
      REQUEST_TYPE=$1
      JOB_ID_OR_CMD_FILE=$2
   else
      if [[ $# != 3 ]]; then
         error_exit "Dynamic add and quench requests take exactly 3 parameters."
      fi
      REQUEST_TYPE=$1
      NUM=$2
      if [[ "`expr $NUM + 0 2> /dev/null`" != "$NUM" ]]; then
         error_exit "$NUM is not an integer."
      fi
      if (( $NUM < 1 )); then
         error_exit "$NUM is not a positive integer."
      fi
      JOB_ID_OR_CMD_FILE=$3
   fi
   if [[ -f $JOB_ID_OR_CMD_FILE ]]; then
      CMD_FILE=$JOB_ID_OR_CMD_FILE
   else
      JOB_ID=$JOB_ID_OR_CMD_FILE
      JOB_PATH=`qstat -f $JOB_ID | perl -e '
         undef $/;
         $_ = <>;
         s/\s//g;
         my ($path) = (/PBS_O_WORKDIR=(.*?),/);
         print $path;
      '`
      echo Job ID: $JOB_ID
      echo Job Path: $JOB_PATH
      CMD_FILE=`\ls $JOB_PATH/*.$JOB_ID*/psub_cmd 2> /dev/null`
      if [[ ! -f "$CMD_FILE" ]]; then
         error_exit "Can't find command file for job $JOB_ID"
      fi
   fi

   if [[ $DEBUG ]]; then
      echo Psub Cmd File: $CMD_FILE
   fi
   HOST=`perl -e 'undef $/; $_ = <>; ($host) = /-host=(.*?) /; print $host' < $CMD_FILE`
   PORT=`perl -e 'undef $/; $_ = <>; ($port) = /-port=(.*?) /; print $port' < $CMD_FILE`
   echo Host: $HOST:$PORT
   NETCAT_COMMAND="r-parallel-worker.pl -netcat -host $HOST -port $PORT"

   if [[ $REQUEST_TYPE = add ]]; then
      RESPONSE=`echo ADD $NUM | $NETCAT_COMMAND`
      if [[ "$RESPONSE" != ADDED ]]; then
         error_exit "Daemon error (response=$RESPONSE), add request failed."
      fi
      # Ping the daemon to make it launch the first extra worker requested;
      # the rest will get added as the extra workers request their jobs.
      if [[ "`echo PING | $NETCAT_COMMAND`" != PONG ]]; then
         echo "Daemon does not appear to be running; request completed" \
              "but likely won't do anything."
         exit 1
      fi
   elif [[ $REQUEST_TYPE = num_worker ]]; then
      RESPONSE=`echo NUM_WORKER | $NETCAT_COMMAND`
      if [[ "$RESPONSE" =~ "NUM_WORKER (w:[0-9]+ q:[0-9]+ a:[0-9]+)" ]]; then
         echo ${BASH_REMATCH[1]}
      else
         error_exit "Daemon error (response=$RESPONSE), num_worker request failed."
      fi
      exit 0
   elif [[ $REQUEST_TYPE = quench ]]; then
      RESPONSE=`echo QUENCH $NUM | $NETCAT_COMMAND`
      if [[ "$RESPONSE" != QUENCHED ]]; then
         error_exit "Daemon error (response=$RESPONSE), quench request failed."
      fi
   elif [[ $REQUEST_TYPE = kill ]]; then
      RESPONSE=`echo KILL | $NETCAT_COMMAND`
      if [[ "$RESPONSE" != KILLED ]]; then
         error_exit "Daemon error (response=$RESPONSE), kill request failed."
      fi
      echo "Killing daemon and all workers (will take several seconds)."
      exit 0
   else
      error_exit "Internal script error - invalid request type: $REQUEST_TYPE."
   fi

   echo Dynamically ${REQUEST_TYPE}ing $NUM 'worker(s)'

   exit 0
fi

if [[ "$ON_ERROR" != continue &&
      "$ON_ERROR" != stop &&
      "$ON_ERROR" != killall ]]; then
   error_exit "Invalid -on-error specification: $ON_ERROR"
fi

if [[ $NOCLUSTER ]]; then
   CLUSTER=
elif on-cluster.sh; then
   CLUSTER=1
else
   CLUSTER=
fi

# Assume there's a problem until we know things finished cleanly.
GLOBAL_RETURN_CODE=3
# NORMAL_FINISH will be set to 1 before exiting later if run-parellel.sh has finished cleanly.
NORMAL_FINISH=

# Process clean up at exit or kill - set this trap early enough that we
# clean up no matter what happens.
trap '
   trap "" 0 1 13 14
   [[ $DEBUG_CLEANUP ]] && echo "run-parallel.sh cleaning up: $WORKDIR/ $TMPLOGFILEPREFIX ${LOGFILEPREFIX}\*" >&2
   if [[ -n "$WORKER_JOBIDS" ]]; then
      WORKERS=`cat $WORKER_JOBIDS`
      $QDEL $WORKERS >& /dev/null
   else
      WORKERS=""
   fi
   [[ $DEBUG_TRAP ]] && echo "WORKERS=$WORKERS"
   if [[ $DAEMON_PID && `ps -p $DAEMON_PID | wc -l` > 1 ]]; then
      kill $DAEMON_PID
   fi
   if [[ $WORKERS ]]; then
      CLEAN_UP_MAX_DELAY=7    # 7x3=21s
      if [[ $CLUSTER_TYPE == jobsub ]]; then
         WORKER_SPECS=`echo $WORKERS | tr " " ","`
         FIND_JOB_CMD="jobst -j $WORKER_SPECS 2> /dev/null | grep \"^[0-9]\" >& /dev/null"
      else
         FIND_JOB_CMD="qstat $WORKERS 2> /dev/null | grep \" [RQE] \" >& /dev/null"
      fi

      [[ $DEBUG_TRAP ]] && echo "FIND_JOB_CMD=$FIND_JOB_CMD"
      while eval $FIND_JOB_CMD; do
         if [[ $CLEAN_UP_MAX_DELAY = 0 ]]; then break; fi
         CLEAN_UP_MAX_DELAY=$((CLEAN_UP_MAX_DELAY - 1))
         sleep 3
      done
   fi
   for x in ${LOGFILEPREFIX}log.worker*; do
      if [[ -f $x ]]; then
         if ! grep -q "============ Starting job" $x; then
            mkdir -p ~/.eqw-logs
            cp -p $x ~/.eqw-logs
         fi
      fi
   done
   DID_SOME_LOG_OUTPUT=
   if [[ $DEBUG || ! $NORMAL_FINISH ]]; then
      for x in ${LOGFILEPREFIX}log.worker* ${LOGFILEPREFIX}psub-dummy-out.worker* $WORKDIR/err.worker-* $WORKDIR/mon.worker-*; do
         if [[ -s $x ]]; then
            echo ""
            echo ========== $x ==========
            cat $x
            DID_SOME_LOG_OUTPUT=1
         fi
      done >&2
   elif [[ $DEBUG_CLEANUP ]]; then
      for x in ${LOGFILEPREFIX}log.worker*; do
         if [[ -s $x ]]; then
            echo ""
            echo ========== $x ==========
            #cat $x | sed -n -e "/^Architecture/,/^model name/p;/^==* Starting/p;/^==* Finished/p;"
            cat $x | sed -n -e "/^model name/p;/^==* Starting/p;/^==* Finished/p;"
            DID_SOME_LOG_OUTPUT=1
         fi
      done >&2
   fi
   if [[ $DID_SOME_LOG_OUTPUT ]]; then
      echo >&2
      echo ========== End ========== >&2
   fi
   if [[ $DEBUG_CLEANUP ]]; then
      RM_VERBOSE="-v"
      ls -l $WORKDIR/* ${LOGFILEPREFIX}* >&2
   fi
   [[ $DEBUG || ! $NORMAL_FINISH ]] || rm $RM_VERBOSE -rf ${LOGFILEPREFIX}log.worker* ${LOGFILEPREFIX}psub-dummy-out.worker* $WORKDIR >&2
   [[ -f $TMPLOGFILEPREFIX ]] && rm $RM_VERBOSE -f $TMPLOGFILEPREFIX >&2
   [[ $DEBUG_CLEANUP ]] && echo "run-parallel.sh exiting with status code: $GLOBAL_RETURN_CODE" >&2
   exit $GLOBAL_RETURN_CODE
' 0 1 13 14

# When working in cluster mode, killing many jobs at once is not friendly, so
# we setup a trap with a more cluster-friendly behaviour for SIGTERM, SIGINT
# and SIGQUIT.
for sig in 2 3 10 12 15; do
   trap '
      if [[ -n "$WORKER_JOBIDS" ]]; then
         echo "Caught signal '$sig', killing workers (please be patient)"
         WORKERS=`cat $WORKER_JOBIDS`
         if [[ -n "$WORKERS" ]]; then
            echo $QDEL $WORKERS
            $QDEL $WORKERS
            sleep 15
         fi
         WORKER_JOBIDS=""
      fi >&2
      exit $GLOBAL_RETURN_CODE
   ' $sig
done

# Create a temp directory for all temp files to go into.
WORKDIR=`mktemp -d ${PREFIX}run-p.$SHORT_JOB_ID.XXX` || error_exit "Can't create temp WORKDIR."
# Open the work dir as much as the user's umask allows.
chmod +rx $WORKDIR
if [[ ! -d $WORKDIR ]]; then
   error_exit "Created temp dir $WORKDIR, but somehow it doesn't exist!"
fi
if [[ $DEBUG ]]; then
   echo "   Temp JOBSET_FILENAME = $JOBSET_FILENAME" >&2
fi
test -f $JOBSET_FILENAME && mv $JOBSET_FILENAME $WORKDIR/jobs
JOBSET_FILENAME=$WORKDIR/jobs
LOGFILEPREFIX=$WORKDIR/

# save instructions from STDIN into instruction set
if [[ $EXEC ]]; then
   test -n "$CMD_LIST" && error_exit "Can't use -e and -exec together"
   NUM=1
elif [[ -n "$CMD_LIST" ]]; then
   test $# -eq 0       && error_exit "Missing mandatory N argument"
   test $# -gt 1       && error_exit "Can't use command file ($1) and -e together"
   NUM=$1;      shift
else
   test $# -eq 0       && error_exit "Missing command file and <N> arguments"
   test $# -eq 1       && error_exit "Missing mandatory N argument"

   CMD_FILE=$1; shift
   NUM=$1;      shift

   test $# -gt 0       && error_exit "Superfluous argument(s): $*"

   test X"$CMD_FILE" \!= X- -a \! -r "$CMD_FILE" &&
      error_exit "Can't read $CMD_FILE"
   cat $CMD_FILE > $JOBSET_FILENAME
fi

# Replace escaped newlines by spaces, to allow commands to occur on multiple
# lines, and also remove & since it doesn't make sense and would cause the
# process to be killed before it can run to completion.
perl -pe 'if ( s/\\$/ / ) { chop } else { s/ *\& *$// }' \
   < $JOBSET_FILENAME > $JOBSET_FILENAME.tmp
mv $JOBSET_FILENAME.tmp $JOBSET_FILENAME ||
   error_exit "Can't move $JOBSET_FILENAME.tmp to $JOBSET_FILENAME"

NUM_OF_INSTR=$(wc -l < $JOBSET_FILENAME)


test $((NUM + 0)) != $NUM &&
   error_exit "Invalid N argument: $NUM; must be numerical"
if [[ $QUOTA ]]; then
   test $((QUOTA + 0)) != $QUOTA &&
      error_exit "Value for -quota option must be numerical"
   QUOTA="-quota $QUOTA"
fi

if (( $VERBOSE > 1 )); then
   echo "" >&2
   echo Starting run-parallel.sh \(pid $$\) on $HOSTNAME on `date` >&2
   echo $0 $SAVE_ARGS >&2
   echo Using: >&2
   which r-parallel-d.pl r-parallel-worker.pl psub >&2
   echo "" >&2
fi

if [[ $DEBUG ]]; then
   echo "
   NUM       = $NUM
   NUM_OF_INSTR = $NUM_OF_INSTR
   NOLOCAL   = $NOLOCAL
   USER_LOCAL= $USER_LOCAL
   NOCLUSTER = $NOCLUSTER
   SAVE_ARGS = $SAVE_ARGS
   PSUBOPTS  = $PSUBOPTS
   QSUBOPTS  = $QSUBOPTS
   OPT_J     = $OPT_J
   VERBOSE   = $VERBOSE
   DEBUG     = $DEBUG
   EXEC      = $EXEC
   QUOTA     = $QUOTA
   PREFIX    = $PREFIX
   JOB_NAME  = $JOB_NAME
   CLUSTER   = $CLUSTER
   ON_ERROR  = $ON_ERROR
   CMD_FILE  = $CMD_FILE
   CMD_LIST  = $CMD_LIST
   JOBSET_FILENAME = $JOBSET_FILENAME
" >&2
fi

# Enable job control
#set -m


if [[ $NUM_OF_INSTR = 0 ]]; then
   echo "No commands to execute!  So I guess I'm done..." >&2
   GLOBAL_RETURN_CODE=0
   NORMAL_FINISH=1
   exit
fi

if (( $NUM_OF_INSTR < $NUM )); then
   echo "Lowering number of workers (was $NUM) to number of instructions ($NUM_OF_INSTR)" >&2
   NUM=$NUM_OF_INSTR
elif [[ $NUM = 0 ]]; then
   echo "Need at least one worker (setting num workers to 1)" >&2
   NUM=1
fi

if [[ $CLUSTER ]]; then
   MY_HOST=$HOSTNAME

   # This is no longer needed, but I'm keeping the code here in case we need it again later.
   #if (( $NUM == 1 )); then
   #   echo "Shielding from Eqw jobs by submitting two workers instead of just one" >&2
   #   NUM=2;
   #fi

   # The child's options are first any resource option given to the psub
   # instance that called this script, but any specificed with -psub or
   # -[no]highmen.
   [[ $PSUB_RESOURCE_OPTIONS ]] &&
      echo "Propagating these psub options from parent to workers: $PSUB_RESOURCE_OPTIONS" >&2
   [[ $PSUBOPTS =~ "[^ ]" ]] &&
      echo "Requested these psub options/overrides for workers: $PSUBOPTS" >&2
   PSUBOPTS="$PSUB_RESOURCE_OPTIONS $PSUBOPTS"
   NCPUS=`psub -require-cpus $PSUBOPTS`
   if [[ $NCPUS ]]; then
      [[ $DEBUG ]] && echo "Requested $NCPUS CPU(s) per worker" >&2
   else
      NCPUS=1
   fi

   if [[ $USER_LOCAL ]]; then
      LOCAL_JOBS=$USER_LOCAL
   elif [[ ! $NOLOCAL ]]; then
      # We assume by default that we can run one local job.
      LOCAL_JOBS=1

      PARENT_NCPUS=`psub -require-cpus $PSUB_RESOURCE_OPTIONS`
      [[ $PARENT_NCPUS ]] || PARENT_NCPUS=1
      [[ $PSUB_OPT_J ]] && PARENT_NCPUS=$((PARENT_NCPUS * PSUB_OPT_J))

      if [[ $NCPUS -gt $PARENT_NCPUS ]]; then
         echo "Requested more CPUs for workers ($NCPUS) than master has ($PARENT_NCPUS), setting -nolocal." >&2
         NOLOCAL=1
      elif (( $PARENT_NCPUS / $NCPUS > 1 )); then
         LOCAL_JOBS=$(($PARENT_NCPUS / $NCPUS))
         echo "Parent has enough CPUs ($PARENT_NCPUS) for $LOCAL_JOBS local workers ($NCPUS CPU(s) each)." >&2
         if (( $LOCAL_JOBS > $NUM )); then
            LOCAL_JOBS=$NUM
            echo "But only requested $NUM worker(s)". >&2
         fi
      fi

      JOB_VMEM=`psub -require $PSUBOPTS`
      PARENT_VMEM=`psub -require $PSUB_RESOURCE_OPTIONS`
      if [[ ! $NOLOCAL ]]; then
         if (( $JOB_VMEM > $PARENT_VMEM )); then
            echo "Requested more VMEM for workers ($JOB_VMEM) than master has ($PARENT_VMEM), setting -nolocal." >&2
            NOLOCAL=1
         else
            # Let's find out how many jobs can actually fit in local memory
            [[ $PSUB_OPT_J ]] && PARENT_VMEM=$((PARENT_VMEM * PSUB_OPT_J))
            if (( $LOCAL_JOBS * $JOB_VMEM > $PARENT_VMEM )); then
               LOCAL_JOBS=$(($PARENT_VMEM / $JOB_VMEM))
               echo "Parent has only enough VMEM ($PARENT_VMEM) for $LOCAL_JOBS local workers (at $JOB_VMEM VMEM each)." >&2
            fi
         fi
      fi

      # Make the per-worker psub options visible to local workers via the same variable as psub
      export PSUB_RESOURCE_OPTIONS="$PSUBOPTS"
      [[ $PSUB_OPT_J ]] && export PSUB_OPT_J=1
   fi

   if [[ -n "$PBS_JOBID" ]]; then
      MASTER_PRIORITY=`qstat -f $PBS_JOBID 2> /dev/null |
         egrep 'Priority = -?[0-9][0-9]*$' | sed 's/.*Priority = //'`
   fi
   if [[ -z "$MASTER_PRIORITY" ]]; then
      MASTER_PRIORITY=0
   fi
   if [[ $NUM == 1 ]]; then
      WORKER_PRIORITY=$MASTER_PRIORITY
   else
      WORKER_PRIORITY=$((MASTER_PRIORITY - 1))
   fi

   #echo MASTER_PRIORITY $MASTER_PRIORITY
   PSUBOPTS="-p $WORKER_PRIORITY $PSUBOPTS"
   #echo PSUBOPTS $PSUBOPTS

   # The psub command is fairly complex, so here it is documented in
   # details
   #
   # Elements specified through SUBMIT_CMD:
   #
   #  - -o psub-dummy-output: overrides default .o output files generated by
   #    PBS/qsub, since we explicitly redirect STDERR and STDOUT using > and 2>
   #    We now use worker-specific psub-dummy-out files, so no longer in SUBMIT_CMD.
   #  - -e: even if the job redirects STDERR, the memory monitoring logs are in
   #    the .e file, so keep them all and summarize them when run-parallel.sh is
   #    done
   #  - -noscript: don't save the .j script file generated by psub
   #  - $PSUBOPTS: pass on any user-specified psub options
   #  - qsparams "$QSUBOPTS": pass on any user-specified qsub options, as well as
   #    a few added above by this script
   #
   # Elements specified in the body of the for loop below:
   #
   #  - -N c-$i-$PBS_JOBID gives each sub job an easily interpretable
   #    name
   #  - \> $OUT 2\> $ERR (notice the \ before >) sends canoe's STDOUT
   #    and STDERR to $OUT and $ERR, respectively
   #  - >&2 (not escaped) sends psub's output to STDERR of this script.

   # Put psub-dummy-output files in a folder that won't go away if the master
   # is done before some of the workers; avoids getting nasty emails from PBS.
   if [[ ! -d $HOME/.run-parallel-logs ]]; then
      mkdir $HOME/.run-parallel-logs ||
         error_exit "Can't create $HOME/.run-parallel-logs directory"
   fi

   # Remove old psub-dummy-output files from previous runs
   # We use -exec rather than piping into xargs because it's much faster this
   # way when there are no files to delete, which will most often be the case.
   find $HOME/.run-parallel-logs/ -type f -mtime +7 -exec rm -f '{}' \; 2>&1 | grep -v 'No such file or directory' 1>&2
   find $HOME/.eqw-logs/ -type f -mtime +14 -exec rm -f '{}' \; 2>&1 | grep -v 'No such file or directory' 1>&2

   # Can we write into $HOME/.run-parallel-logs/?
   TMPLOGFILEPREFIX=`mktemp $HOME/.run-parallel-logs/run-p.$SHORT_JOB_ID.XXX`
   [[ $? == 0 ]] || error_exit "Can't create temporary file for worker log files."
   LOGFILEPREFIX=$TMPLOGFILEPREFIX.

   if [[ ! $DEBUG ]]; then
      PSUBOPTS="-noscript $PSUBOPTS"
   fi

   #SUBMIT_CMD=(psub -o $HOME/.run-parallel-logs/psub-dummy-output -noscript $PSUBOPTS)
   SUBMIT_CMD=(psub $PSUBOPTS)

   if [[ $QSUBOPTS ]]; then
      SUBMIT_CMD=("${SUBMIT_CMD[@]}" -qsparams "$QSUBOPTS")
   fi

   if [[ $NOLOCAL ]]; then
      FIRST_PSUB=0
   elif [[ $LOCAL_JOBS ]]; then
      FIRST_PSUB=$LOCAL_JOBS
   else
      warn "Internal error, the code should never get here."
      FIRST_PSUB=1
   fi

   if [[ -n "${PBS_JOBID%%.*}" ]]; then
      WORKER_NAME=${PBS_JOBID%%.*}-${JOB_NAME}w
   elif [[ -n "${GECOSHEP_JOB_ID}" ]]; then
      # GPSC case:
      WORKER_NAME=j${GECOSHEP_JOB_ID}w
   elif [[ $HOSTNAME =~ ^gpsc-in ]]; then
      # GPSC case:
      WORKER_NAME=gpsc-${GECOSHEP_JOB_ID}w
   else
      WORKER_NAME=${JOB_NAME}w
   fi

   # This file will contain the PBS job IDs of each worker
   WORKER_JOBIDS=$WORKDIR/worker_jobids
   cat /dev/null > $WORKER_JOBIDS

   if [[ $DEBUG ]]; then
      echo "
   NOLOCAL        = $NOLOCAL
   USER_LOCAL     = $USER_LOCAL
   PBS_JOBID      = $PBS_JOBID
   GECOSHEP_JOB_ID= $GECOSHEP_JOB_ID
   JOB_VMEM       = $JOB_VMEM
   PARENT_VMEM    = $PARENT_VMEM
   NCPUS          = $NCPUS
   PARENT_NCPUS   = $PARENT_NCPUS
   LOCAL_JOBS     = $LOCAL_JOBS
   FIRST_PSUB     = $FIRST_PSUB
   NUM            = $NUM
   " >&2
   fi

else
   # Not running on a cluster
   NOLOCAL=
   FIRST_PSUB=$NUM
   MY_HOST=127.0.0.1
fi

if [[ $UNIT_TEST ]]; then
   trap 'exit' 0 1 2 3 13 14 15
   rm $TMPLOGFILEPREFIX
   rm -r $WORKDIR
   exit
fi

# This is no longer required: we now use ports 5900-5999, where the GPSC login node
# accepts connections.
#[[ $HOSTNAME =~ gpsc && $CLUSTER ]] &&
#   error_exit "run-parallel.sh must be submitted using psub on this cluster."

# We use a named pipe instead of a file - faster, and more reliable.
mkfifo $WORKDIR/port || error_exit "Can't create named pipe $WORKDIR/port"
DAEMON_CMD="r-parallel-d.pl -bind $$ -on-error $ON_ERROR $NUM $WORKDIR"
if [[ $QUIET_DAEMON || $VERBOSE == 0 ]]; then
   $DAEMON_CMD 2>&1 |
      egrep --line-buffered 'FATAL ERROR|SIGNALED|Non-zero' 1>&2 &
elif [[ $VERBOSE == 1 ]]; then
   $DAEMON_CMD 2>&1 |
      egrep --line-buffered 'FATAL ERROR|\] ([0-9/]* (DONE|SIGNALED)|starting|Non-zero)' 1>&2 &
else
   $DAEMON_CMD &
fi
DAEMON_PID=$!

MY_PORT=`cat $WORKDIR/port`
rm -f $WORKDIR/port # Clean this right away so we never leave a fifo behind
[[ $DEBUG ]] && echo "MY_PORT=$MY_PORT" >&2
if [[ $MY_PORT = FAIL ]]; then
   error_exit "Daemon had a fatal error"
elif [[ -z $MY_PORT ]]; then
   error_exit "Failed to launch daemon"
else
   if (( $VERBOSE > 1 )); then
      echo Pinging $MY_HOST:$MY_PORT >&2
   fi
   if [[ "`echo PING | r-parallel-worker.pl -netcat -host $MY_HOST -port $MY_PORT`" != PONG ]]; then
      # When PING fails, do some real ping in the hope it will give us useful
      # troubleshoting info, then try again once before giving up.
      ping -c 10 $MY_HOST >&2
      sleep 5
      if [[ "`echo PING | r-parallel-worker.pl -netcat -host $MY_HOST -port $MY_PORT`" != PONG ]]; then

         error_exit "Daemon did not respond correctly to PING request. Running on $HOSTNAME, trying to ping $MY_HOST:$MY_PORT."
      fi
   fi
fi

if (( $VERBOSE > 1 )); then
   echo Daemon launched successfully on $MY_HOST:$MY_PORT >&2
fi

# Command for launching more workers when some send a STOPPING-DONE message.
PSUB_CMD_FILE=$WORKDIR/psub_cmd
MONOPT="-mon $WORKDIR/mon.worker-__WORKER__ID__"
if [[ $USER_WORKER_CMD ]]; then
   WORKER_CMD_PRE="time-mem -period $MON_PERIOD -timefmt $WORKER_CPU_STRING=real%Rs:user%Us+sys%Ss:pcpu%P%%"
   WORKER_CMD_POST="$USER_WORKER_CMD"
   WORKER_CMD_POST=${WORKER_CMD_POST//__HOST__/$MY_HOST}
   WORKER_CMD_POST=${WORKER_CMD_POST//__PORT__/$MY_PORT}
   WORKER_OTHER_OPT=""
else
   SILENT_WORKER=
   if [[ $VERBOSE < 2 ]]; then
      SILENT_WORKER=-silent
   fi
   # Remove /usr/bin/time because it interferes with traps and signal handling on the GPSC.
   #WORKER_CMD_PRE="/usr/bin/time -f $WORKER_CPU_STRING=real%es:user%Us+sys%Ss:pcpu%P%% r-parallel-worker.pl $SILENT_WORKER -host=$MY_HOST -port=$MY_PORT -period $MON_PERIOD"
   WORKER_CMD_PRE="r-parallel-worker.pl $SILENT_WORKER -host=$MY_HOST -port=$MY_PORT -period $MON_PERIOD"
   WORKER_CMD_POST=""
   [[ $WORKER_SUBST ]] && SUBST_OPT="-subst $WORKER_SUBST/__WORKER__ID__" || SUBST_OPT=""
   WORKER_OTHER_OPT="$SUBST_OPT"
   [[ $CLUSTER ]] && WORKER_OTHER_OPT="$WORKER_OTHER_OPT $QUOTA"
fi

WORKER_ADJ_PSUB_OPT_J=
WORKER_ADJ_PSUB_OPT_J_ESC=
if [[ $PSUB_OPT_J || $OPT_J ]]; then
   WORKER_ADJ_PSUB_OPT_J="export PSUB_OPT_J=1 &&"
   WORKER_ADJ_PSUB_OPT_J_ESC="export PSUB_OPT_J=1 \&\&"
fi

if [[ $CLUSTER ]]; then
   cat /dev/null > $PSUB_CMD_FILE
   for word in "${SUBMIT_CMD[@]}"; do
      if echo "$word" | grep -q ' '; then
         echo -n "" \"$word\" >> $PSUB_CMD_FILE
      else
         echo -n "" $word >> $PSUB_CMD_FILE
      fi
   done
   echo -n "" -N $WORKER_NAME-__WORKER__ID__ >> $PSUB_CMD_FILE
   echo -n "" -o ${LOGFILEPREFIX}psub-dummy-out.worker-__WORKER__ID__ >> $PSUB_CMD_FILE
   echo -n "" -e ${LOGFILEPREFIX}log.worker-__WORKER__ID__ >> $PSUB_CMD_FILE
   echo -n "" $WORKER_ADJ_PSUB_OPT_J_ESC $WORKER_CMD_PRE $MONOPT $WORKER_CMD_POST $WORKER_OTHER_OPT \\\> $WORKDIR/out.worker-__WORKER__ID__ 2\\\> $WORKDIR/err.worker-__WORKER__ID__ \>\> $WORKER_JOBIDS >> $PSUB_CMD_FILE
else
   echo $WORKER_ADJ_PSUB_OPT_J_ESC $WORKER_CMD_PRE $MONOPT $WORKER_CMD_POST $WORKER_OTHER_OPT \> $WORKDIR/out.worker-__WORKER__ID__ 2\> $WORKDIR/err.worker-__WORKER__ID__ \& > $PSUB_CMD_FILE
fi
echo $NUM > $WORKDIR/next_worker_id

# usage: gen_worker_cmd $i
# or:    gen_worker_cmd $i -primary
gen_worker_cmd() {
   local i=$1
   local primary=$2
   local OUT=$WORKDIR/out.worker-$i
   local ERR=$WORKDIR/err.worker-$i
   local MONOPT="-mon $WORKDIR/mon.worker-$i"
   [[ $WORKER_SUBST ]] && SUBST_OPT="-subst $WORKER_SUBST/$i" || SUBST_OPT=
   [[ ! $USER_WORKER_CMD ]] && WORKER_OTHER_OPT="$SUBST_OPT $QUOTA $primary" || WORKER_OTHER_OPT=
   echo "$WORKER_ADJ_PSUB_OPT_J $WORKER_CMD_PRE $MONOPT $WORKER_CMD_POST $WORKER_OTHER_OPT > $OUT 2> $ERR"
}

# start local worker(s) locally, if not disabled.
if [[ ! $NOLOCAL ]]; then
   # start first worker(s) locally
   for (( i = 0; i < $FIRST_PSUB; ++i )); do
      WORKER_CMD=`gen_worker_cmd $i -primary`
      if (( $VERBOSE > 2 )); then
         echo $WORKER_CMD \& >&2
      fi
      eval $WORKER_CMD &
   done
fi

if (( $NUM > $FIRST_PSUB )); then
   if [[ ! $CLUSTER ]]; then
      echo run-parallel.sh internal error >&2
      exit 1
   fi
   # start remaining workers using psub, noting their PID/PBS_JOBID
   if qsub -t 2>&1 | grep -q 'option requires an argument'; then
      # Friendlier behaviour on clusters that support it: use the -t option to
      # submit all workers in a single request
      OUT=$WORKDIR/out.worker-
      ERR=$WORKDIR/err.worker-
      LOG=${LOGFILEPREFIX}log.worker
      DUMMY_OUT=${LOGFILEPREFIX}psub-dummy-out.worker
      ID='$PBS_ARRAYID'
      MONOPT="-mon $WORKDIR/mon.worker-$ID"
      [[ $WORKER_SUBST ]] && SUBST_OPT="-subst $WORKER_SUBST/$ID" || SUBST_OPT=
      [[ ! $USER_WORKER_CMD ]] && WORKER_OTHER_OPT="$SUBST_OPT $QUOTA" || WORKER_OTHER_OPT=
      if (( $VERBOSE > 2 )); then
         echo "${SUBMIT_CMD[@]}" -t $FIRST_PSUB-$(($NUM-1)) -N $WORKER_NAME -o $DUMMY_OUT -e $LOG $WORKER_CMD_PRE $MONOPT $WORKER_CMD_POST $WORKER_OTHER_OPT \> $OUT$ID 2\> $ERR$ID >&2
      fi
      "${SUBMIT_CMD[@]}" -t $FIRST_PSUB-$(($NUM-1)) -N $WORKER_NAME -o $DUMMY_OUT -e $LOG $WORKER_CMD_PRE $MONOPT $WORKER_CMD_POST $WORKER_OTHER_OPT \> $OUT$ID 2\> $ERR$ID >> $WORKER_JOBIDS ||
         error_exit "Error launching array of workers using psub"
      # qstat needs individual job ids, and fails when given the array id, so we
      # need to expand them by hand into the $WORKER_JOBIDS file.
      WORKER_BASE_JOBID=`cat $WORKER_JOBIDS`
      if [[ $WORKER_BASE_JOBID =~ '([0-9][0-9]*)(.*)' ]]; then
         WORKER_BASE_JOBID_NUM=${BASH_REMATCH[1]}
         WORKER_BASE_JOBID_SUFFIX=${BASH_REMATCH[2]}
         cat /dev/null > $WORKER_JOBIDS
         for (( i = FIRST_PSUB; i < NUM; ++i )); do
            echo $WORKER_BASE_JOBID_NUM-$i$WORKER_BASE_JOBID_SUFFIX >> $WORKER_JOBIDS
         done
      fi
   elif [[ $OPT_J > 1 ]]; then
      i=$FIRST_PSUB
      while true; do
         BLOCK_END=$(( $i + $OPT_J ))
         [[ $BLOCK_END -gt $NUM ]] && BLOCK_END=$NUM
         LOCAL_J=$(( BLOCK_END - i ))
         WORKER_RANGE=$i-$(( BLOCK_END - 1 ))
         LOG=${LOGFILEPREFIX}log.workers-$WORKER_RANGE
         DUMMY_OUT=${LOGFILEPREFIX}psub-dummy-out.workers-$WORKER_RANGE
         WORKER_CMD_LIST=
         for (( ; i < $BLOCK_END ; ++i )); do
            WORKER_CMD_LIST="$WORKER_CMD_LIST `gen_worker_cmd $i` &"
         done
         if (( $VERBOSE > 2 )); then
            echo "${SUBMIT_CMD[@]}" -j $LOCAL_J -N $WORKER_NAME-$WORKER_RANGE -o $DUMMY_OUT -e $LOG "$WORKER_CMD_LIST wait" >&2
         fi
         "${SUBMIT_CMD[@]}" -j $LOCAL_J -N $WORKER_NAME-$WORKER_RANGE -o $DUMMY_OUT -e $LOG "$WORKER_CMD_LIST wait" >> $WORKER_JOBIDS ||
            error_exit "Error launching worker $i using psub"
         if (( $i == $NUM )); then
            break
         fi
      done
   else
      for (( i = $FIRST_PSUB ; i < $NUM ; ++i )); do
         # These should not end up being used by the commands, only by the
         # worker scripts themselves
         WORKER_CMD=`gen_worker_cmd $i`
         LOG=${LOGFILEPREFIX}log.worker-$i
         DUMMY_OUT=${LOGFILEPREFIX}psub-dummy-out.worker-$i

         if (( $VERBOSE > 2 )); then
            echo "${SUBMIT_CMD[@]}" -N \"$WORKER_NAME-$i\" -o $DUMMY_OUT -e $LOG "$WORKER_CMD" >&2
         fi
         "${SUBMIT_CMD[@]}" -N "$WORKER_NAME-$i" -o $DUMMY_OUT -e $LOG "$WORKER_CMD" >> $WORKER_JOBIDS ||
            error_exit "Error launching worker $i using psub"
         # PBS doesn't like having too many qsubs at once, let's give it a
         # chance to breathe between each worker submission
         (( i > 10 )) && sleep 1
      done
   fi
fi

if [[ $CLUSTER ]]; then
   # wait on daemon pid (r-parallel-d.pl, the daemon, will exit when the last
   # worker reports the last task is done)
   wait $DAEMON_PID

   # Give PBS up to 20 seconds to finish cleaning up worker jobs that have just
   # finished
   WORKERS=`cat $WORKER_JOBIDS 2> /dev/null`
   [[ $DEBUG_TRAP ]] && echo "WORKERS=$WORKERS" >&2
   #echo run-parallel job_id: $PBS_JOBID workers: $WORKERS >&2
   #qstat $WORKERS >&2
   if [[ $WORKERS ]]; then
      if [[ $CLUSTER_TYPE == jobsub ]]; then
         WORKER_SPECS=`echo $WORKERS | tr " " ","`
         FIND_JOB_CMD="jobst -j $WORKER_SPECS 2> /dev/null | grep \"^[0-9]\" >& /dev/null"
      else
         FIND_JOB_CMD="qstat $WORKERS 2> /dev/null | grep \" [RQE] \" >& /dev/null"
      fi
      [[ $DEBUG_TRAP ]] && echo "FIND_JOB_CMD=$FIND_JOB_CMD" >&2
      for (( i = 0; i < 7; ++i )); do # 7x3=21 seconds
         if eval $FIND_JOB_CMD; then
            #echo Some workers are still running >&2
            sleep 3
            [[ $DEBUG_TRAP ]] && echo . >&2
         else
            #echo Workers are done, we can safely exit >&2
            break
         fi

         if [[ $i = 3 ]]; then
            # After 9 seconds, kill remaining psubed workers (which may not
            # have been launched yet) to clean things up.  (Ignore errors)
            [[ $DEBUG_TRAP ]] && echo $QDEL $WORKERS >&2
            $QDEL $WORKERS >& /dev/null
         fi
      done
   fi

   WORKERS=""
   WORKER_JOBIDS=""
else
   # In non-cluster mode, just wait after everything, it gives us the exact
   # time when things are completely done.
   wait
fi

if (( $VERBOSE > 0 )); then
   # Send all worker STDOUT and STDERR to STDERR for logging purposes.
   for x in $WORKDIR/{out,err,mon}.worker-*; do
      if [[ $UNORDERED_CAT && $VERBOSE == 1 && $x =~ 'out.worker' ]]; then
         # unordered cat mode already cats out.worker-*, don't duplicate in
         # default verbosity
         :
      elif [[ -s $x ]]; then
         if [[ $VERBOSE = 1 && `grep -v "Can't connect to socket: Connection refused" < $x | wc -c` = 0 ]]; then
            # STDERR only containing workers that can't connect to a dead
            # daemon - ignore in default verbosity mode
            true
            #echo skipping $x
         else
            echo >&2
            echo ========== $(basename $x) ========== >&2
            cat $x >&2
         fi
      fi
   done
   echo >&2
   echo ========== End ========== >&2
fi

if (( $VERBOSE > 1 )); then
   echo "" >&2
   echo Done run-parallel.sh \(pid $$\) on $HOSTNAME on `date` >&2
   echo $0 $SAVE_ARGS >&2
   echo "" >&2
fi

if (( $VERBOSE > 0 )); then
   # show the exit status of each worker
   echo -n 'Exit status(es) from all jobs (in the order they finished): ' >&2
   cat $WORKDIR/rc 2> /dev/null | tr '\n' ' ' >&2
   echo "" >&2
fi

export PORTAGE_INTERNAL_CALL=1

END_TIME=`date +%s`
WALL_TIME=$((END_TIME - START_TIME))
TOTAL_CPU=`grep -h $WORKER_CPU_STRING $WORKDIR/err.worker-* 2> /dev/null |
   egrep -o "user[0-9.]+s.sys[0-9.]+s" | egrep -o "[0-9.]+" | sum.pl`
TOTAL_REAL=`grep -h $WORKER_CPU_STRING $WORKDIR/err.worker-* 2> /dev/null |
   egrep -o "real[0-9.]+s" | egrep -o "[0-9.]+" | sum.pl`
TOTAL_WAIT=$(bc <<< "scale=2; $TOTAL_REAL - $TOTAL_CPU")
if [[ $TOTAL_REAL == 0 ]]; then TOTAL_PCPU=100; else
   TOTAL_PCPU=$(bc <<< "scale=2; $TOTAL_CPU * 100 / $TOTAL_REAL")
fi
RP_MON_TOTALS=`rp-mon-totals.pl $WORKDIR/mon.worker-*`
RPTOTALS="RP-Totals: Wall time ${WALL_TIME}s CPU time ${TOTAL_CPU}s CPU Wait time ${TOTAL_WAIT}s PCPU ${TOTAL_PCPU}% ${RP_MON_TOTALS}"

if [[ `wc -l < $WORKDIR/rc` -ne "$NUM_OF_INSTR" ]]; then
   echo 'Wrong number of job return statuses: got' `wc -l < $WORKDIR/rc` "expected $NUM_OF_INSTR." >&2
   echo $RPTOTALS >&2
   GLOBAL_RETURN_CODE=-1
   exit -1
elif [[ $EXEC ]]; then
   # With -c, we work like the shell's -c: connect stdout and stderr from the
   # job to the this script's, and exit with the job's exit status
   cat $WORKDIR/out.worker-0
   if [[ $SILENT_WORKER ]]; then
      cat $WORKDIR/err.worker-0 >&2
   else
      cat $WORKDIR/err.worker-0 |
         perl -e '
            while (<>) {
               if ( /\[.*\] \((\S+)\) Executing \(1\) / ) {
                  $jobid=$1;
                  last;
               }
            }
            while (<>) {
               if ( s/\[.*?\] \(\Q$jobid\E\) Exit status.*//s ) {
                  print;
                  last;
               }
               print;
            }' >&2
   fi
   echo $RPTOTALS >&2
   GLOBAL_RETURN_CODE=`cat $WORKDIR/rc`
   NORMAL_FINISH=1
   exit $GLOBAL_RETURN_CODE
elif [[ $UNORDERED_CAT ]]; then
   find $WORKDIR -name 'out.worker*' | xargs cat
   (( $VERBOSE == 0 )) && find $WORKDIR -name 'err.worker*' | xargs more >&2
fi

echo $RPTOTALS >&2

if grep -q -v '^0$' $WORKDIR/rc >& /dev/null; then
   # At least one job got a non-zero return code
   GLOBAL_RETURN_CODE=2
   NORMAL_FINISH=1
   exit 2
else
   GLOBAL_RETURN_CODE=0
   NORMAL_FINISH=1
   exit 0
fi
