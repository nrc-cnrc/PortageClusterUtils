#!/usr/bin/make -f
# vim:noet:ts=3

# Makefile - Test STDERR and STDOUT capturing in run-parallel.sh.
#
# PROGRAMMER: Darlene Stewart
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2010, Sa Majeste la Reine du Chef du Canada /
# Copyright 2010, Her Majesty in Right of Canada

SHELL = bash
Q=-q

.SECONDARY:

run-parallel.sh ?= run-parallel.sh
#run-parallel.sh = ../../../src/iit_shared_utils/run-parallel.sh

FILTER_ERR = 'print $$_ if (/^={10}.+={10}$$/ && !/mon.worker/) || /^<output.*>$$/ || /^<error.*>$$/ ;'
PRINT_XX = -e 'print \"<outputXX>\n\";' -e 'print STDERR \"<errorXX>\n\"'

.PHONY: all clean

all: dash_c dash_c+dash_v dash_e

dash_c:
	run-parallel.sh -nocluster -c "perl $(subst XX,,${PRINT_XX})" 1>out 2>err
	diff $Q out <(echo "<output>")
	cat err | perl -ne ${FILTER_ERR} | diff $Q - <(echo "<error>")
#	${RM} out err

dash_c+dash_v:
	run-parallel.sh -nocluster -v -c "perl $(subst XX,,${PRINT_XX})" 1>out 2>err
	diff $Q out <(echo "<output>")
	cat err | perl -ne ${FILTER_ERR} | diff $Q - ref.err-cv
#	${RM} out err

dash_e:
	run-parallel.sh -nocluster \
		-e "sleep 1; perl $(subst XX,0,${PRINT_XX})" \
		-e "perl $(subst XX,1,${PRINT_XX})" \
		2 1>out 2>err
	cat err | perl -ne ${FILTER_ERR} | diff $Q - ref.err-e || \
	cat err | perl -ne ${FILTER_ERR} | diff $Q - ref.err-e.alt
#	${RM} out err

TEMP_FILES=out err
TEMP_DIRS=run-p.*
include ../Makefile.incl
