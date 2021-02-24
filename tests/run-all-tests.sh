#!/bin/bash
# run-all-tests.sh - Run all unit testing suites, reporting which ones failed
#
# PROGRAMMER: Eric Joanis
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2008-2016, Sa Majeste la Reine du Chef du Canada /
# Copyright 2008-2016, Her Majesty in Right of Canada

usage() {
   echo "Usage: $0 [test-suite [test-suite2 [...]]]
   Run the specified test suites, or all test suites if none are specified.
   Each test suite must contain a script named run-test.sh which returns 0
   as exit status if the suite passes, non-zero otherwise.

Option:
   -j N       Run the tests N-ways parallel [1]
   -local L   Run L parallel workers locally [calculated by run-parallel.sh]
   -v(erbose) Increase verbosity
" >&2
   exit
}

while [ $# -gt 0 ]; do
   case "$1" in
   -j)      PARALLEL_MODE=1; PARALLEL_LEVEL=$2; shift;;
   -local)  LOCAL="-local $2"; shift;;
   -v|-verbose) VERBOSE=1;;
   -*)      usage;;
   *)       break;;
   esac
   shift
done

TEST_SUITES=$*
if [[ ! $TEST_SUITES ]]; then
   TEST_SUITES=`echo */run-test.sh | sed 's/\/run-test.sh//g'`
fi

echo ""
echo Test suites to run: $TEST_SUITES

if [[ $PARALLEL_MODE ]]; then
   LOG=.log.run-all-tests.`date +%Y%m%dT%H%M%S`
   PARALLEL_MODE=
   {
      # Launch tune.py first, since it's the longest one to run and would get
      # launched almost last by default.
      if [[ $TEST_SUITES =~ tune.py ]]; then echo $0 tune.py; fi
      for suite in $TEST_SUITES; do
         if [[ $suite =~ tune.py ]]; then : ; else
            echo $0 $suite
         fi
      done
   } |
      if [[ $VERBOSE ]]; then
         run-parallel.sh -j 4 -v -psub -1 -on-error continue $LOCAL -unordered-cat - $PARALLEL_LEVEL 2>&1 |
         tee $LOG
      else
         run-parallel.sh -j 4 -psub -1 -on-error continue $LOCAL -unordered-cat - $PARALLEL_LEVEL 2>&1 |
         tee $LOG |
         egrep -i --line-buffered '^\[|error' |
         egrep -v -i --line-buffered '^(Test suites to run:|Running|PASSED|\*\*\* FAILED) ' |
         egrep --line-buffered --color '.*\*.*|$|(^|[^-])[Ee][Rr][Rr][Oo][Rr]'
      fi
   grep PASSED $LOG | grep -v 'test suites' | sort -u
   grep FAILED $LOG | grep -v 'test suites' | sort -u

   if grep -q FAILED $LOG; then
      exit 1
   elif perl -e 'while (<>) { if (m# (\d+)/\1 DONE #) { exit(0); } } exit(1)' $LOG; then
      echo ""
      echo PASSED all test suites.
      exit
   else
      echo ""
      echo Test suite not completed.
      exit 1
   fi
fi

run_test() {
   { time ./run-test.sh; } >& _log.run-test
}

if [[ $TEST_SUITES =~ \  ]]; then
   LOG=.log.run-all-tests.`date +%Y%m%dT%H%M%S`
   PIPE_LOG="tee $LOG"
else
   PIPE_LOG="cat"
fi

set -o pipefail

{
   for TEST_SUITE in $TEST_SUITES; do
      echo ""
      echo =======================================
      echo Running $TEST_SUITE
      if cd -- $TEST_SUITE; then
         if [[ ! -x ./run-test.sh ]]; then
            echo '***' FAILED $TEST_SUITE: can\'t find or execute ./run-test.sh
            FAIL="$FAIL $TEST_SUITE"
         elif run_test; then
            echo PASSED $TEST_SUITE
         else
            echo '***' FAILED $TEST_SUITE: ./run-test.sh returned $?
            FAIL="$FAIL $TEST_SUITE"
         fi

         cd ..
      else
         echo '***' FAILED $TEST_SUITE: could not cd into $TEST_SUITE
         FAIL="$FAIL $TEST_SUITE"
      fi
   done

   echo ""
   echo =======================================
   if [[ $FAIL ]]; then
      echo '***' FAILED these test suites:$FAIL
      exit 1
   else
      echo PASSED all test suites
   fi
} | $PIPE_LOG

exit $?
