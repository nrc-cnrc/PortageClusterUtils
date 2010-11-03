#!/bin/bash -k
# $Id$

# @file run-parallel.sh 
# @brief runs a series of jobs provided as STDIN on parallel distributed
# workers managed by r-parallel-d.pl and r-parallel-worker.pl.
#
# @author Eric Joanis
#
# COMMENTS:
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2005, Sa Majeste la Reine du Chef du Canada /
# Copyright 2005, Her Majesty in Right of Canada

# Requirements for the run-parallel.sh suite:
# Make sure the following are in your path:
# - parallelize.pl
# - process-memory-usage.pl
# - psub
# - r-parallel-d.pl
# - r-parallel-worker.pl
# - run-parallel.sh
# - sum.pl
# - which-test.sh

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
  -cleanup      Remove run-parallel-logs-* files  upon completion.
  -v(erbose)    Increase verbosity level.  If specified once, show the deamon's
                logs, each worker's logs, etc.  Yet more output is produced if
                specified twice.
  -on-error ACTION  Specifies how to proceed when a command is reported to
                have failed (i.e., its exit code is not 0); ACTION may be:
       continue Ignore return codes and execute all commands anyway [default]
       stop     Let commands that have started end, but don't launch any more
       killall  Kill all workers immediately and exit
  -subst MATCH  Have workers substite MATCH in each command by their worker-id
                before running it.
  -unordered-cat Outputs to stdout, in an unordered fashion, stdouts from all
                 the workers.

Cluster mode options:

  -N            adds a user defined name to the workers. []
                Useful when using run-parallel.sh -nolocal -e "job" 1
  -highmem      Use 2 CPUs per worker, for extra extra memory.  [propagate the
                number of CPUs of master job]
  -nohighmem    Use only 1 CPU per worker, even if master job had more.
  -nolocal      psub all workers [run one worker locally, unless on head node] 
  -nocluster    force non-cluster mode [auto-detect if we're on a cluster]
  -quota T      When workers have done T minutes of work, re-psub them [30]
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

==EOF==

   exit 1
}

error_exit() {
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

# Print a warning message
warn()
{
   echo "WARNING: $*" >&2
}

MY_HOST=`hostname`

# Return 1 (false) if we're running a PBS job, and therefore are on a compute
# node, 0 (true) otherwise, in which case we assume we're on a head/login node.
on_head_node()
{
   if [[ $PBS_JOBID ]]; then
      return 1
   else
      return 0
   fi
}

if [[ $PBS_JOBID ]]; then
   SHORT_JOB_ID=${PBS_JOBID:0:13}
else
   SHORT_JOB_ID=$$.local
fi

WORKER_CPU_STRING="Run-parallel-worker-CPU"
START_TIME=`date +"%s"`
NUM=
HIGHMEM=
NOHIGHMEM=
NOLOCAL=
if on_head_node; then NOLOCAL=1; fi
NOCLUSTER=
VERBOSE=1
CLEANUP=
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
ON_ERROR=continue
SUBST=
#TODO: run-parallel.sh -c RP_ARGS -... -... {-exec | -c} cmd args
# This would allow a job in a Makefile, which uses SHELL = run-parallel.sh, to
# specify some parameters other than the default.
while (( $# > 0 )); do
   case "$1" in
   -p)             arg_check 1 $# $1; PREFIX="$2"; shift;;
   -e)             arg_check 1 $# $1; CMD_LIST=1
                   echo "$2" >> $JOBSET_FILENAME; shift;;
   -unordered-cat|-unordered_cat) VERBOSE=0; UNORDERED_CAT=1;;
   -exec|-c)       arg_check 1 $# $1; shift; NOLOCAL=1; EXEC=1
                   VERBOSE=$(( $VERBOSE - 1 ))
                   # Special case for make's sake - make invokes uname -s twice
                   # before executing each and every command!
                   test "$*" = "uname -s" && exec $*

                   # NOTE: Make cannot communicate accross machine.
                   # If this invocation is for make, run it locally.
                   if [[ $* =~ ^make ]]; then
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
                   break;;
   -highmem)       HIGHMEM=1;;
   -nohighmem)     NOHIGHMEM=1;;
   -nolocal)       NOLOCAL=1;;
   -nocluster)     NOCLUSTER=1;;
   -on-error)      arg_check 1 $# $1; ON_ERROR="$2"; shift;;
   -N)             arg_check 1 $# $1; JOB_NAME="$2-"; shift;;
   -quota)         arg_check 1 $# $1; QUOTA="$2"; shift;;
   -psub|-psub-opts|-psub-options)
                   arg_check 1 $# $1; PSUBOPTS="$PSUBOPTS $2"; shift;;
   -qsub|-qsub-opts|-qsub-options)
                   arg_check 1 $# $1; QSUBOPTS="$QSUBOPTS $2"; shift;;
   -subst)         arg_check 1 $# $1; WORKER_SUBST=$2; shift;;
   -v|-verbose)    VERBOSE=$(( $VERBOSE + 1 ));;
   -q|-quiet)      VERBOSE=0;;
   -cleanup)       CLEANUP=1;;
   -d|-debug)      DEBUG=1;;
   -h|-help)       usage;;
   -unit-test)     UNIT_TEST=1;; # hidden option for unit testing
   *)              break;;
   esac
   shift
done

# Special commands pre-empt normal operation
if [[ "$1" = add || "$1" = quench || "$1" = kill ]]; then
   # Special command to dynamically add or remove worders to/from a job in
   # progress
   if [[ "$1" = kill ]]; then
      if [[ $# != 2 ]]; then
         error_exit "Kill requests take exactly 2 parameters."
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
         error_exit "Deamon error (response=$RESPONSE), add request failed."
      fi
      # Ping the deamon to make it launch the first extra worker requested;
      # the rest will get added as the extra workers request their jobs.
      if [[ "`echo PING | $NETCAT_COMMAND`" != PONG ]]; then
         echo "Deamon does not appear to be running; request completed" \
              "but likely won't do anything."
         exit 1
      fi
   elif [[ $REQUEST_TYPE = quench ]]; then
      RESPONSE=`echo QUENCH $NUM | $NETCAT_COMMAND`
      if [[ "$RESPONSE" != QUENCHED ]]; then
         error_exit "Deamon error (response=$RESPONSE), quench request failed."
      fi
   elif [[ $REQUEST_TYPE = kill ]]; then
      RESPONSE=`echo KILL | $NETCAT_COMMAND`
      if [[ "$RESPONSE" != KILLED ]]; then
         error_exit "Deamon error (response=$RESPONSE), kill request failed."
      fi
      echo "Killing deamon and all workers (will take several seconds)."
      exit 0
   else
      error_exit "Internal script error - invalid request type: $REQUEST_TYPE."
   fi

   echo Dynamically ${REQUEST_TYPE}ing $NUM 'worker(s)'

   exit 0
fi

CLEANLOG=
if [[ $CLEANUP ]]; then
   CLEANLOG="run-parallel-logs-${PBS_JOBID-local}"
fi

# Assume there's a problem until we know things finished cleanly.
GLOBAL_RETURN_CODE=2

# Process clean up at exit or kill - set this trap early enough that we 
# clean up no matter what happens.
trap '
   if [[ -n "$WORKER_JOBIDS" ]]; then
      WORKERS=`cat $WORKER_JOBIDS`
      qdel $WORKERS >& /dev/null
   else
      WORKERS=""
   fi
   if [[ $DEAMON_PID && `ps -p $DEAMON_PID | wc -l` > 1 ]]; then
      kill $DEAMON_PID
   fi
   if [[ $WORKERS ]]; then
      CLEAN_UP_MAX_DELAY=20
      while qstat $WORKERS 2> /dev/null | grep " [RQE] " >& /dev/null; do
         if [[ $CLEAN_UP_MAX_DELAY = 0 ]]; then break; fi
         CLEAN_UP_MAX_DELAY=$((CLEAN_UP_MAX_DELAY - 1))
         sleep 1
      done
   fi
   for x in $WORKDIR/log.worker-* $WORKDIR/mon.worker-*; do
      if [[ -s $x ]]; then
         echo $x
         echo ""
         cat $x
         echo ""
      fi
   done > run-parallel-logs-${PBS_JOBID-local}
   test -n "$DEBUG" || rm -rf $WORKDIR $CLEANLOG
   trap "" 0
   exit $GLOBAL_RETURN_CODE
' 0 1 2 3 13 14 15

# Create a temp directory for all temp files to go into.
WORKDIR=`mktemp -d ${PREFIX}run-p.$SHORT_JOB_ID.XXX` || error_exit "Can't create temp WORKDIR."
if [[ ! -d $WORKDIR ]]; then
   error_exit "Created temp dir $WORKDIR, but somehow it doesn't exist!"
fi
if [[ $DEBUG ]]; then
   echo "   Temp JOBSET_FILENAME = $JOBSET_FILENAME" >&2
fi
test -f $JOBSET_FILENAME && mv $JOBSET_FILENAME $WORKDIR/jobs
JOBSET_FILENAME=$WORKDIR/jobs

if [[ $NOCLUSTER ]]; then
   CLUSTER=
elif which-test.sh qsub; then
   CLUSTER=1
else
   CLUSTER=
fi

if [[ "$ON_ERROR" != continue &&
      "$ON_ERROR" != stop &&
      "$ON_ERROR" != killall ]]; then
   error_exit "Invalid -on-error specification: $ON_ERROR"
fi

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
   echo Starting run-parallel.sh \(pid $$\) on `hostname` on `date` >&2
   echo $0 $SAVE_ARGS >&2
   echo Using: >&2
   which r-parallel-d.pl r-parallel-worker.pl psub >&2
   echo "" >&2
fi

if [[ $DEBUG ]]; then
   echo "
   NUM       = $NUM
   NUM_OF_INSTR = $NUM_OF_INSTR
   HIGHMEM   = $HIGHMEM
   NOHIGHMEM = $NOHIGHMEM
   NOLOCAL   = $NOLOCAL
   NOCLUSTER = $NOCLUSTER
   SAVE_ARGS = $SAVE_ARGS
   PSUBOPTS  = $PSUBOPTS
   QSUBOPTS  = $QSUBOPTS
   VERBOSE   = $VERBOSE
   DEBUG     = $DEBUG
   EXEC      = $EXEC
   QUOTA     = $QUOTA
   PREFIX    = $PREFIX
   JOB_NAME  = $JOB_NAME
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
   if [[ $PSUBOPTS =~ '(^| )-([0-9]+)($| )' ]]; then
      NCPUS=${BASH_REMATCH[2]}
      test -n $DEBUG && echo Requested $NCPUS CPUs per worker >&2
   elif [[ $HIGHMEM ]]; then
      # For high memory, request two CPUs per worker with ncpus=2.
      PSUBOPTS="-2 $PSUBOPTS"
      NCPUS=2
   elif [[ $NOHIGHMEM ]]; then
      NCPUS=1
   fi

   if [[ ! $NOLOCAL ]]; then
      # We assume by default that we can run one local job.
      LOCAL_JOBS=1

      if [[ $PBS_JOBID ]]; then
         if [[ `qstat -f $PBS_JOBID 2> /dev/null` =~ '1:ppn=([[:digit:]]+)' ]]; then
            PARENT_NCPUS=${BASH_REMATCH[1]}
         else
            PARENT_NCPUS=1
         fi
      fi

      if [[ $NCPUS && $PARENT_NCPUS ]]; then
         if [[ $NCPUS -gt $PARENT_NCPUS ]]; then
            echo Requested more CPUs for workers than master has, setting -nolocal. >&2
            NOLOCAL=1
         elif (( $PARENT_NCPUS / $NCPUS > 1 )); then
            LOCAL_JOBS=$(($PARENT_NCPUS / $NCPUS))
            echo Parent has enough CPUs for $LOCAL_JOBS local workers. >&2
            if (( $LOCAL_JOBS > $NUM )); then
               LOCAL_JOBS=$NUM
               echo But only requested $NUM worker"(s)".
            fi
         fi
      elif [[ $PARENT_NCPUS && $PARENT_NCPUS -gt 1 && ! $NCPUS ]]; then
         echo Master was submitted with $PARENT_NCPUS CPUs, propagating to workers. >&2
         PSUBOPTS="-$PARENT_NCPUS $PSUBOPTS"
      fi
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

   if [[ ! $NOLOCAL ]]; then
      # Now that the PSUBOPTS variable has settle down, let see how much vmem the job
      # requires.
      JOB_VMEM=`psub -require $PSUBOPTS`

      if [[ $PBS_JOBID ]]; then
         # How much VMEM was allocated to the parent?
         if [[ `qstat -f $PBS_JOBID 2> /dev/null` =~ 'Resource_List.vmem = ([[:digit:]]+)gb' ]]; then
            PARENT_VMEM=${BASH_REMATCH[1]}
         else
            [[ $DEBUG ]] && echo "Failed determining PARENT_VMEM" >&2
         fi
      else
         [[ $DEBUG ]] && echo "Not in a PBS_JOB thus not getting PARENT_VMEM" >&2
      fi

      # If the parent doesn't have enough VMEM it won't be allowed to run a job.
      if [[ $JOB_VMEM && $PARENT_VMEM ]]; then
         if [[ $JOB_VMEM -gt $PARENT_VMEM ]]; then
            echo "Requested more VMEM for workers (${JOB_VMEM}GB) than master has (${PARENT_VMEM}GB), setting -nolocal." >&2
            NOLOCAL=1
         else
            # Let's find out how many jobs can actually fit in local memory
            if (( $LOCAL_JOBS * $JOB_VMEM > $PARENT_VMEM )); then
               LOCAL_JOBS=$(($PARENT_VMEM / $JOB_VMEM))
               echo "Parent has only enough VMEM (${PARENT_VMEM}GB) for $LOCAL_JOBS local workers (at ${JOB_VMEM}GB VMEM each)." >&2
            fi
         fi
      fi
   fi


   # The psub command is fairly complex, so here it is documented in
   # details
   #
   # Elements specified through SUBMIT_CMD:
   #
   #  - -o psub-dummy-output: overrides defaut .o output files generated by
   #    PBS/qsub, since we explicitely redirect STDERR and STDOUT using > and 2>
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

   SUBMIT_CMD=(psub
               -o $WORKDIR/psub-dummy-output
               -noscript
               $PSUBOPTS)

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
   else
      WORKER_NAME=${JOB_NAME}w
   fi

   # This file will contain the PBS job IDs of each worker
   WORKER_JOBIDS=$WORKDIR/worker_jobids
   cat /dev/null > $WORKER_JOBIDS

   if [[ $DEBUG ]]; then
      echo "
   NOLOCAL = $NOLOCAL
   PBS_JOBID = $PBS_JOBID
   JOB_VMEM = $JOB_VMEM
   PARENT_VMEM = $PARENT_VMEM
   NCPUS = $NCPUS
   PARENT_NCPUS = $PARENT_NCPUS
   LOCAL_JOBS = $LOCAL_JOBS
   FIRST_PSUB = $FIRST_PSUB
   NUM = $NUM
   " >&2
   fi

else
   # Not running on a cluster
   NOLOCAL=
   FIRST_PSUB=$NUM
fi

if [[ $UNIT_TEST ]]; then
   trap 'exit' 0 1 2 3 13 14 15
   rm -r $WORKDIR
   exit
fi

if (( $VERBOSE > 1 )); then
   r-parallel-d.pl -bind $$ -on-error $ON_ERROR $NUM $WORKDIR &
   DEAMON_PID=$!
elif (( $VERBOSE > 0 )); then
   r-parallel-d.pl -bind $$ -on-error $ON_ERROR $NUM $WORKDIR 2>&1 | 
      egrep --line-buffered 'FATAL ERROR|\] ([0-9/]* (DONE|SIGNALED)|starting|Non-zero)' 1>&2 &
   DEAMON_PID=$!
else
   r-parallel-d.pl -bind $$ -on-error $ON_ERROR $NUM $WORKDIR 2>&1 | 
      egrep --line-buffered 'FATAL ERROR' 1>&2 &
   DEAMON_PID=$!
fi

# make sure we have a server listening, by sending a ping
connect_delay=0
while true; do
   sleep 1
   if [[ -f $WORKDIR/port ]]; then
      MY_PORT=`cat $WORKDIR/port 2> /dev/null`
   else
      MY_PORT=
   fi
   connect_delay=$((connect_delay + 1))
   if [[ -z "$MY_PORT" ]]; then
      if [[ $connect_delay -ge 10 ]]; then
         echo No deamon yet after $connect_delay seconds - still trying >&2
      fi
      if [[ $connect_delay -ge 15 ]]; then
         # after 15 seconds, slow down to trying every 5 seconds
         sleep 4;
         connect_delay=$((connect_delay + 4))
      fi
      if [[ $connect_delay -ge 60 ]]; then
         # after 60 seconds, slow down to trying every 15 seconds
         sleep 10; 
         connect_delay=$((connect_delay + 10))
      fi
      if [[ $connect_delay -ge 1200 ]]; then
         error_exit "Can't get a deamon, giving up"
      fi
   else
      if (( $VERBOSE > 1 )); then
         echo Pinging $MY_HOST:$MY_PORT >&2
      fi
      if [[ "`echo PING | r-parallel-worker.pl -netcat -host $MY_HOST -port $MY_PORT`" = PONG ]]; then
         if (( $connect_delay > 10 )); then
            echo Finally got a deamon after $connect_delay seconds >&2
         fi
         # deamon responded correctly, we're good to go now.
         break
      fi
   fi
done

if (( $VERBOSE > 1 )); then
   echo Deamon launched successfully on $MY_HOST:$MY_PORT >&2
fi

# Command for launching more workers when some send a STOPPING-DONE message.
PSUB_CMD_FILE=$WORKDIR/psub_cmd
SILENT_WORKER=
if [[ $VERBOSE < 2 ]]; then
   SILENT_WORKER=-silent
fi
WORKER_COMMAND="/usr/bin/time -f $WORKER_CPU_STRING=user%Us+sys%Ss r-parallel-worker.pl $SILENT_WORKER -host=$MY_HOST -port=$MY_PORT"
if [[ $WORKER_SUBST ]]; then
   SUBST_OPT="-subst $WORKER_SUBST/__WORKER__ID__"
else
   SUBST_OPT=""
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
   echo -n "" -e $WORKDIR/log.worker-__WORKER__ID__ >> $PSUB_CMD_FILE
   echo -n "" $WORKER_COMMAND $SUBST_OPT $QUOTA -mon $WORKDIR/mon.worker-__WORKER__ID__ \\\> $WORKDIR/out.worker-__WORKER__ID__ 2\\\> $WORKDIR/err.worker-__WORKER__ID__ \>\> $WORKER_JOBIDS >> $PSUB_CMD_FILE
else
   echo $WORKER_COMMAND $SUBST_OPT -mon $WORKDIR/mon.worker-__WORKER__ID__ \> $WORKDIR/out.worker-__WORKER__ID__ 2\> $WORKDIR/err.worker-__WORKER__ID__ \& > $PSUB_CMD_FILE
fi
echo $NUM > $WORKDIR/next_worker_id

# start local worker(s) locally, if not disabled.
if [[ ! $NOLOCAL ]]; then
   # start first worker(s) locally
   for (( i = 0; i < $FIRST_PSUB; ++i )); do
      OUT=$WORKDIR/out.worker-$i
      ERR=$WORKDIR/err.worker-$i
      MON=$WORKDIR/mon.worker-$i
      if [[ $WORKER_SUBST ]]; then
         SUBST_OPT="-subst $WORKER_SUBST/$i"
      fi
      if (( $VERBOSE > 2 )); then
         echo $WORKER_COMMAND $SUBST_OPT -primary -mon $MON \> $OUT 2\> $ERR \& >&2
      fi
      eval $WORKER_COMMAND $SUBST_OPT -primary -mon $MON > $OUT 2> $ERR &
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
      LOG=$WORKDIR/log.worker
      MON=$WORKDIR/mon.worker-
      ID='$PBS_ARRAYID'
      if [[ $WORKER_SUBST ]]; then
         SUBST_OPT="-subst $WORKER_SUBST/$ID"
      fi
      if (( $VERBOSE > 2 )); then
         echo "${SUBMIT_CMD[@]}" -t $FIRST_PSUB-$(($NUM-1)) -N $WORKER_NAME -e $LOG $WORKER_COMMAND $SUBST_OPT $QUOTA -mon $MON$ID \> $OUT$ID 2\> $ERR$ID >&2
      fi
      "${SUBMIT_CMD[@]}" -t $FIRST_PSUB-$(($NUM-1)) -N $WORKER_NAME -e $LOG $WORKER_COMMAND $SUBST_OPT $QUOTA -mon $MON$ID \> $OUT$ID 2\> $ERR$ID >> $WORKER_JOBIDS
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
   else
      for (( i = $FIRST_PSUB ; i < $NUM ; ++i )); do
         # These should not end up being used by the commands, only by the
         # worker scripts themselves
         OUT=$WORKDIR/out.worker-$i
         ERR=$WORKDIR/err.worker-$i
         LOG=$WORKDIR/log.worker-$i
         MON=$WORKDIR/mon.worker-$i
         if [[ $WORKER_SUBST ]]; then
            SUBST_OPT="-subst $WORKER_SUBST/$i"
         fi

         if (( $VERBOSE > 2 )); then
            echo ${SUBMIT_CMD[@]} -N $WORKER_NAME-$i -e $LOG $WORKER_COMMAND $SUBST_OPT $QUOTA -mon $MON \> $OUT 2\> $ERR >&2
         fi
         "${SUBMIT_CMD[@]}" -N $WORKER_NAME-$i -e $LOG $WORKER_COMMAND $SUBST_OPT $QUOTA -mon $MON \> $OUT 2\> $ERR >> $WORKER_JOBIDS
         # PBS doesn't like having too many qsubs at once, let's give it a
         # chance to breathe between each worker submission
         sleep 1
      done
   fi
fi

if [[ $CLUSTER ]]; then
   # wait on deamon pid (r-parallel-d.pl, the deamon, will exit when the last
   # worker reports the last task is done)
   wait $DEAMON_PID

   # Give PBS up to 20 seconds to finish cleaning up worker jobs that have just
   # finished
   WORKERS=`cat $WORKER_JOBIDS 2> /dev/null`
   #echo run-parallel job_id: $PBS_JOBID workers: $WORKERS >&2
   #qstat $WORKERS >&2
   if [[ $WORKERS ]]; then
      for (( i = 0; i < 20; ++i )); do
         #qstat $WORKERS >&2
         if qstat $WORKERS 2> /dev/null | grep ' [QRE] ' > /dev/null ; then
            #echo Some workers are still running >&2
            sleep 1
         else
            #echo Workers are done, we can safely exit >&2
            break
         fi

         if [[ $i = 8 ]]; then
            # After 8 seconds, kill remaining psubed workers (which may not
            # have been launched yet) to clean things up.  (Ignore errors)
            qdel $WORKERS >& /dev/null
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
   for x in $WORKDIR/{out,err}.worker-*; do
      if [[ -s $x ]]; then
         if [[ $VERBOSE = 1 && `grep -v "Can't connect to socket: Connection refused" < $x | wc -c` = 0 ]]; then
            # STDERR only containing workers that can't connect to a dead
            # deamon - ignore in default verbosity mode
            true
            #echo skipping $x
         else
            echo >&2
            echo ========== $x ========== | sed "s|$WORKDIR/||" >&2
            cat $x >&2
         fi
      fi
   done
   echo >&2
   echo ========== End ========== >&2
fi

if (( $VERBOSE > 1 )); then
   echo "" >&2
   echo Done run-parallel.sh \(pid $$\) on `hostname` on `date` >&2
   echo $0 $SAVE_ARGS >&2
   echo "" >&2
fi

if (( $VERBOSE > 0 )); then
   # show the exit status of each worker
   echo -n 'Exit status(es) from all jobs (in the order they finished): ' >&2
   cat $WORKDIR/rc 2> /dev/null | tr '\n' ' ' >&2
   echo "" >&2
fi

TOTAL_CPU=`grep -h $WORKER_CPU_STRING $WORKDIR/err.worker-* 2> /dev/null | 
   egrep -o "[0-9.]+" | sum.pl`
END_TIME=`date +%s`
WALL_TIME=$((END_TIME - START_TIME))
MAX_VSZ=`egrep -ho 'vsz: [0-9.]+G' $WORKDIR/mon.worker-* 2> /dev/null |
   egrep -o "[0-9.]+" | sum.pl -m`
MAX_RSS=`egrep -ho 'rss: [0-9.]+G' $WORKDIR/mon.worker-* 2> /dev/null |
   egrep -o "[0-9.]+" | sum.pl -m`
RPTOTALS="RP-Totals: Wall time ${WALL_TIME}s CPU time ${TOTAL_CPU}s Max VMEM ${MAX_VSZ}G Max RAM ${MAX_RSS}G"
if [[ ! $EXEC ]]; then
   echo $RPTOTALS >&2
fi

if [[ `wc -l < $WORKDIR/rc` -ne "$NUM_OF_INSTR" ]]; then
   echo 'Wrong number of job return statuses: got' `wc -l < $WORKDIR/rc` "expected $NUM_OF_INSTR." >&2
   GLOBAL_RETURN_CODE=-1
   exit -1
elif [[ $UNORDERED_CAT ]]; then
   find $WORKDIR | grep -F 'out.worker' | xargs cat
   find $WORKDIR | grep -F 'err.worker' | xargs cat >&2
   echo $RPTOTALS >&2
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
   exit $GLOBAL_RETURN_CODE
elif grep -q -v '^0$' $WORKDIR/rc >& /dev/null; then
   # At least one job got a non-zero return code
   GLOBAL_RETURN_CODE=2
   exit 2
else
   GLOBAL_RETURN_CODE=0
   exit 0
fi
