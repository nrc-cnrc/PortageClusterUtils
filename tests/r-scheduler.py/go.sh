#!/bin/bash

# psub 'for f in `seq 1 1000`; do echo sleep 160; done | run-parallel.sh - 5'
# psub 'for f in `seq 1 10`; do echo sleep 60; done | run-parallel.sh - 5'

./r-scheduler.py \
  --debug \
  -b 1 \
  -m 5 \
  -f 0 \
  run-p.*.balza.*/psub_cmd \
  -a '0.31415 : */5 * * * * * *' \
  -q '.271 : */7 * * * * * *'
