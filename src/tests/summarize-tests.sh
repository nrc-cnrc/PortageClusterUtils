#!/bin/bash

if [[ $# -gt 0 ]]; then
   RUN_TO_ANALYZE="$1"
   shift
else
   RUN_TO_ANALYZE="$(\ls .log.run-all-tests* | tail -1)"
fi
echo Summarizing $RUN_TO_ANALYZE

if [[ ! $RUN_TO_ANALYZE ]]; then
   echo No run found to summarize >&2
   exit 1
fi

grep FAILED $RUN_TO_ANALYZE | grep -v these | sort
echo FAILED $(grep FAILED $RUN_TO_ANALYZE | grep -v these | wc -l) test suites
echo PASSED $(grep PASSED $RUN_TO_ANALYZE | grep -v "all test suites" | wc -l) test suites
echo FAILED: $(grep -o "FAILED.*:" $RUN_TO_ANALYZE | grep -v "these test suites" | sed -e 's/.*FAILED *//' -e 's/:.*//')
