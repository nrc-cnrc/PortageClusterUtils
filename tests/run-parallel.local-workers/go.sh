#!/bin/bash
# run-test.sh - Run the various run-parallel.sh commands in this test suite.
#
# PROGRAMMER: Eric Joanis
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2009, Sa Majeste la Reine du Chef du Canada /
# Copyright 2009, Her Majesty in Right of Canada


export -n RUNPARALLEL_WORKER_NCPUS
export -n RUNPARALLEL_WORKER_VMEM
export PATH=.:$PATH
export BALZAC=1
PBS_JOBID=1 run-parallel.sh -unit-test -d <(seq 1 10) 4
PBS_JOBID=1 run-parallel.sh -unit-test -d <(seq 1 3) 4
PBS_JOBID=1.2CPU run-parallel.sh -psub -1 -unit-test -d <(seq 1 10) 4
PBS_JOBID=1.5CPU run-parallel.sh -psub -2 -unit-test -d <(seq 1 10) 4
PBS_JOBID=1.5CPU run-parallel.sh -psub -2 -unit-test -d <(seq 1 10) 1
PBS_JOBID=1.6CPU run-parallel.sh -psub "-2 -memmap 4" -unit-test -d <(seq 1 10) 4
PBS_JOBID=1.6CPU run-parallel.sh -psub "-2 -memmap 4" -unit-test -d <(seq 1 10) 2
PBS_JOBID=1.6CPU run-parallel.sh -psub "-2 -memmap 4" -unit-test -d <(seq 1 10) 1
PBS_JOBID=1.4CPU.1MEMMAP run-parallel.sh -psub "-1 -memmap 1" -unit-test -d <(seq 1 10) 4
PBS_JOBID=1.2CPU.20MEMMAP run-parallel.sh -psub -3 -unit-test -d <(seq 1 10) 4
PBS_JOBID=1.2CPU.20MEMMAP run-parallel.sh -psub "-memmap 30" -unit-test -d <(seq 1 10) 4
