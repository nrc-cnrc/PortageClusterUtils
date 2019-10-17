# vim:noet:ts=3:nowrap:filetype=make
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
        jobsig.pl \
        jobtree \
        on-cluster.sh \
        parallelize.pl \
        process-memory-usage.pl \
        psub \
        qstatdir \
        qstatn \
        qstattree \
        r-scheduler.py \
        r-parallel-d.pl \
        r-parallel-worker.pl \
        rp-mon-totals.pl \
        rsync-with-restart.sh \
        run-parallel.sh \
        stripe.py \
        sum.pl \
        which-test.sh

# The following code is here to allow this Makefile to work within the Portage
# compiling framework.  You can safely ignore this block if you're in a
# different project, but please leave it as is.
ifdef PORTAGE
-include ../build/Makefile.incl
lib:
	@true
endif

# Destination for installing the scripts: specific INSTALL_DIR=/install/path
# to have all the scripts installed in directory /install/path/bin
# Default installation destination is $(HOME)/bin
ifndef INSTALL_DIR
INSTALL_DIR=$(HOME)
endif

install:  test
	install -d -m0750 $(INSTALL_DIR)/bin
	install -p -m0750 $(BINSCRIPTS) $(INSTALL_DIR)/bin

# jobtree & qstattree have some Perl dependencies
test: check_perl_dependencies

# Term::ANSIColor 3.00 is needed for the bright_ colours; otherwise Term::ANSIColor 2.02 is needed for colorvalid.
.PHONY: check_perl_dependencies
check_perl_dependencies:
	perldoc -l Data::TreeDumper
	perldoc -l Tree::Simple
	perldoc -l Time::Piece
	perl -e 'use Term::ANSIColor 3.00;'
