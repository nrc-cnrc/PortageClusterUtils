#!/usr/bin/make -f
# vim:noet:ts=3:nowrap:filetype=make

PSUB = psub
-include Makefile.params

SHELL = bash

.DEFAULT_GOAL := all
.PHONY: all
all:  psub.jobctl_cell


include ../Makefile.incl


.PHONY:  psub.jobctl_cell
psub.jobctl_cell:  psub.jobctl_cell.c
psub.jobctl_cell:  psub.jobctl_cell.export
psub.jobctl_cell:  psub.jobctl_cell.cli
psub.jobctl_cell:  psub.jobctl_cell.run-parallel


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




.PHONY: psub.project
all: psub.project

.PHONY: psub.project.cli_user_define
psub.project:  psub.project.none
psub.project.none: export PSUB_PROJECT_NAME:=
psub.project.none:
	${PSUB} \
		-n \
		'sleep 10' \
	| grep -c '^#$$ -P' 2> /dev/null \
	| grep 0 \
	|| ! echo "Error: Project Name should empty" >&2

.PHONY: psub.project.default
psub.project:  psub.project.default
psub.project.default: export PSUB_PROJECT_NAME:=project_default_tag
psub.project.default:
	${PSUB} \
		-n \
		'sleep 10' \
	| grep --quiet '^#$$ -P project_default_tag\|^#JGEN -r project=project_default_tag' 2> /dev/null \
	|| ! echo "Error: Project Name it should be teh default project name." >&2

# Has to be done in the .bashrc of the user.
#.PHONY: psub.project.override
#psub.project:  psub.project.override
#psub.project.override: export PSUB_PROJECT_NAME:=project_default_tag
#psub.project.override: export PSUB_PROJECT_NAME_OVERRIDE:=project_name_overridden
#psub.project.override:
#	${PSUB} \
#		-n \
#		'sleep 10' \
#	| grep --quiet '^#$$ -P project_name_overridden' 2> /dev/null \
#	|| ! echo "Error: Project Name not Overridden" >&2

.PHONY: psub.project.cli_user_define
psub.project:  psub.project.cli_user_define
psub.project.cli_user_define:
	${PSUB} \
		-n \
		-Q this_is_my_project_tag \
		'sleep 10' \
	| grep --quiet '^#$$ -P this_is_my_project_tag\|^#JGEN -r project=this_is_my_project_tag' 2> /dev/null \
	|| ! echo "Error: Project Name not the one from the CLI." >&2
