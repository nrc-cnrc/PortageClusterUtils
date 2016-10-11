#!/usr/bin/make -f
# vim:noet:ts=3:nowrap:filetype=make

PSUB = psub
-include Makefile.params

SHELL = bash

.DEFAULT_GOAL := all
.PHONY: all
all:  psub.jobctl_cell


.PHONY: clean
clean:


.PHONY:  psub.jobctl_cell
psub.jobctl_cell:  psub.jobctl_cell.default
psub.jobctl_cell:  psub.jobctl_cell.c
psub.jobctl_cell:  psub.jobctl_cell.export
psub.jobctl_cell:  psub.jobctl_cell.cli
psub.jobctl_cell:  psub.jobctl_cell.run-parallel


# If we don't specify a jobctl_cell, by default, we should be running on
# gpsc1.science.gc.ca.
.PHONY:  psub.jobctl_cell.default
psub.jobctl_cell.default:
	${PSUB} -n sleep 10 \
	| grep "export JOBCTL_CELL=gpsc1.science.gc.ca" \
	|| ! echo "Error: we should be using the default cell." >&2


# Let's change jobctl_cell by passing -c to psub.
.PHONY:  psub.jobctl_cell.c
psub.jobctl_cell.c:
	${PSUB} -n -c gpsc2.science.gc.ca sleep 10 \
	| grep "export JOBCTL_CELL=gpsc2.science.gc.ca" \
	|| ! echo "Error: -c didn't export JOBCTL_CELL." >&2


# Let's see if psub picks up a different jobctl_cell if the user sets it in his
# environment.
.PHONY:  psub.jobctl_cell.export
psub.jobctl_cell.export:  export JOBCTL_CELL=gpsc2.science.gc.ca
psub.jobctl_cell.export:
	${PSUB} -n sleep 10 \
	| grep "export JOBCTL_CELL=gpsc2.science.gc.ca" \
	|| ! echo "Error: environment variable didn't get exported." >&2


# What if we prefix psub with JOBCTL_CELL for a one time use.
.PHONY:  psub.jobctl_cell.cli
psub.jobctl_cell.cli:
	JOBCTL_CELL=gpsc2.science.gc.ca ${PSUB} -n sleep 10 \
	| grep "export JOBCTL_CELL=gpsc2.science.gc.ca" \
	|| ! echo "Error: cli environment variable didn't get exported." >&2



.INTERMEDIATE:  psub.jobctl_cell.run-parallel.cmds
psub.jobctl_cell.run-parallel.cmds:
	for f in {0..4}; do echo "sleep 10; env"; done > $@

# Let's verify that run-parallel.sh's workers are running on the master's cell.
.PHONY:  psub.jobctl_cell.run-parallel
.INTERMEDIATE:  psub.jobctl_cell.run-parallel
psub.jobctl_cell.run-parallel:  psub.jobctl_cell.run-parallel.cmds
	${PSUB} \
		-N workers \
		-noscript \
		-qsparams '-sync yes' \
		-c gpsc2.science.gc.ca \
		'run-parallel.sh -unordered-cat $< 5 > $@'
	[[ `grep --count JOBCTL_CELL=gpsc2.science.gc.ca $@` -eq 5 ]] \
	|| ! echo "Error: workers should run on gpsc2.science.gc.ca" >&2
	${RM} workers.[joe]*

