#!/bin/bash
# run-all-tests.sh - Run the clean Makefile target for all unit testing suites
#
# PROGRAMMER: Darlene Stewart
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2009, Sa Majeste la Reine du Chef du Canada /
# Copyright 2009, Her Majesty in Right of Canada

if [[ "$1" =~ "^-" ]]; then
   echo "Usage: $0 [test-suite [test-suite2 [...]]]
       Run clean.sh or the clean Makefile target for the specified test suites,
       or for all test suites if none are specified."
   exit
fi

CLEAN_LOG=
TEST_SUITES=$*
if [[ ! $TEST_SUITES ]]; then
   TEST_SUITES=`echo */Makefile */clean.sh | sed 's/\/[^ \/]*//g' | tr ' ' '\n' | sort -u`
   CLEAN_LOG=1
fi

echo ""
echo Test suites to clean: $TEST_SUITES

for TEST_SUITE in $TEST_SUITES; do
   echo ""
   echo =======================================
   echo Cleaning $TEST_SUITE
   if cd -- $TEST_SUITE; then
      if [[ -x ./clean.sh ]]; then
         echo ./clean.sh
         if ! ./clean.sh; then
            echo FAILED to clean $TEST_SUITE: clean.sh returned $?
            FAIL="$FAIL $TEST_SUITE"
         fi
      elif [[ ! -r ./Makefile ]]; then
         echo FAILED to clean $TEST_SUITE: can\'t find or execute ./Makefile
         FAIL="$FAIL $TEST_SUITE"
      else
         echo make clean
         if ! make clean; then
            echo FAILED to clean $TEST_SUITE: make returned $?
            FAIL="$FAIL $TEST_SUITE"
         fi
      fi

      echo "rm -f log.run-test run-parallel-logs-*"
      rm -f _log.run-test log.run-test run-parallel-logs-*
      cd ..
   else
      echo FAILED to clean $TEST_SUITE: could not cd into $TEST_SUITE
      FAIL="$FAIL $TEST_SUITE"
   fi
done

if [[ $CLEAN_LOG ]]; then
   echo ""
   echo =======================================
   echo "rm -f .log.run-all-tests-parallel"
   rm -f .log.run-all-tests-parallel
fi

echo ""
echo =======================================
if [[ $FAIL ]]; then
   echo FAILED to clean these test suites:$FAIL
   exit 1
else
   echo CLEANED all test suites
fi
