#!/usr/bin/make -f
# vim:noet:ts=3
#
# Makefile - Run this unit test suite.
#
# PROGRAMMER: Samuel Larkin
#
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2008, Sa Majeste la Reine du Chef du Canada /
# Copyright 2008, Her Majesty in Right of Canada


.PHONY: clean all

all: all_rp

.PHONY: all_rp
all_rp:
	make -f Makefile.rp all 2>&1 | egrep '^ *<D>' | diff ref -

TEMP_FILES=delme run-parallel-logs-*
TEMP_DIRS=run-p.*.*
include ../Makefile.incl
