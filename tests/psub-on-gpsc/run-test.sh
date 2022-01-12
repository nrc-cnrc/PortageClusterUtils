#!/bin/bash

if [[ $(on-cluster.sh -type) != jobsub ]]; then
    echo SKIPPED: the psub-on-gspc test suite only works on the GPSC
    exit 3
fi

make clean
make all -j 2
