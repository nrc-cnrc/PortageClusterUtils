# Makefile for IITSharedUtils
# This makefile simply installs all script in the location of your choice.

# Eric Joanis
# Technologies langagieres interactives / Interactive Language Technologies
# Inst. de technologie de l'information / Institute for Information Technology
# Conseil national de recherches Canada / National Research Council Canada
# Copyright 2009, Sa Majeste la Reine du Chef du Canada /
# Copyright 2009, Her Majesty in Right of Canada

BINSCRIPTS = \
        analyze \
        cvs-attic-list.sh \
        cvs-cat-all-revisions.sh \
        cvs-diff-all-revisions.sh \
        cvs-log-sort.pl \
        cvs-status-summary.pl \
        parallelize.pl \
        process-memory-usage.pl \
        psub \
        qstatdir \
        qstatn \
        r-parallel-d.pl \
        r-parallel-worker.pl \
        run-parallel.sh \
        sum.pl \
        which-test.sh

# The following include statement is here to allow this Makefile to work within
# the Portage compiling framework.  you can safely ignore these lines if you're
# in a different project, but please leave them as is.
ifdef PORTAGE
-include ../build/Makefile.incl
endif

# Destination for installing the scripts: specific INSTALL_DIR=/install/path
# to have all the scripts installed in directory /install/path/bin
# Default installation destination is $(HOME)/bin
ifndef INSTALL_DIR
INSTALL_DIR=$(HOME)
endif

install:
	install -d -m0750 $(INSTALL_DIR)/bin
	install -p -m0750 $(BINSCRIPTS) $(INSTALL_DIR)/bin

