#!/usr/bin/make -f
# vim:noet:ts=3:nowrap:filetype=make

PARALLELIZE_PL := parallelize.pl

-include Makefile.params

export PORTAGE_NOCLUSTER=1
PROCESS := rev

NUM_SRC_INPUT := 1000

SHELL := bash

.SECONDARY:
DEFAULT_GOAL := all
PHONY: all
all:  testSuite


PHONY: clean
clean:
	${RM} -fr input* testcase* run-p.*/


.PHONY:  testSuite
.PHONY:  inputs

inputs:  input
input:
	seq 0001 ${NUM_SRC_INPUT} > $@

inputs:  input.gz
input.gz:  input
	cat $< | gzip > $@

inputs:  input.xz
input.xz:  input
	cat $< | xz > $@

inputs:  input.symlink
input.symlink:  input
	ln -fs $< $@



########################################
# Using text files.

.PHONY:  text
testSuite:  text

testcase.text:  input
	${PARALLELIZE_PL} -workdir=$@.wk -debug -n 50 -np 5 '${PROCESS} < $< > $@' 2> $@.log

.PHONY: testcase.text.validate
text:  testcase.text.validate
testcase.text.validate:  %.validate:  %
	[[ `cat $*.wk/input/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the input is missing" >&2
	[[ `\ls $*.wk/input/* | wc -l` -eq 50 ]] || ! echo "Too many input parts" >&2
	[[ `\ls $*.wk/input/*.done | wc -l` -eq 50 ]] || ! echo "Not all input parts were processed" >&2
	[[ `find $*.wk/input/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All input parts should be none empty." >&2
	[[ `find $*.wk/_SLASH_dev_SLASH_stderr.done/ -type f | wc -l` -eq 50 ]] || ! echo "Missing error logs" >&2
	[[ `cat $*.wk/$*.done/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the output is missing" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Too many output parts" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Not all output parts were processed" >&2
	[[ `find $*.wk/$*.done/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All output parts should be none empty." >&2
	diff <(rev input) $*  --brief

testcase.stripe.text:  input
	${PARALLELIZE_PL} -stripe -workdir=$@.wk -debug -n 50 -np 5 '${PROCESS} < $< > $@' 2> $@.log

.PHONY: testcase.stripe.text.validate
text:  testcase.stripe.text.validate
testcase.stripe.text.validate:  %.validate:  %
	[[ `cat $*.wk/input/* | wc -l` -eq 0 ]] || ! echo "Seems that stripe did not work" >&2
	[[ `\ls $*.wk/input/* | wc -l` -eq 50 ]] || ! echo "Too many input parts" >&2
	[[ `\ls $*.wk/input/*.done | wc -l` -eq 50 ]] || ! echo "Not all input parts were processed" >&2
	[[ `find $*.wk/input/ -type f -empty | wc -l` -eq 50 ]] || ! echo "All input parts should be empty." >&2
	[[ `find $*.wk/_SLASH_dev_SLASH_stderr.done/ -type f | wc -l` -eq 50 ]] || ! echo "Missing error logs" >&2
	[[ `cat $*.wk/$*.done/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the output is missing" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Too many output parts" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Not all output parts were processed" >&2
	[[ `find $*.wk/$*.done/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All output parts should be none empty." >&2
	diff <(rev input) $*  --brief



########################################
# Using symbolic links.

.PHONY:  symlink
testSuite:  symlink

testcase.symlink:  input.symlink
	${PARALLELIZE_PL} -workdir=$@.wk -debug -n 50 -np 5 '${PROCESS} < $< > $@' 2> $@.log

.PHONY: testcase.symlink.validate
symlink:  testcase.symlink.validate
testcase.symlink.validate:  %.validate:  %
	[[ `cat $*.wk/input.symlink/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the input is missing" >&2
	[[ `\ls $*.wk/input.symlink/* | wc -l` -eq 50 ]] || ! echo "Too many input parts" >&2
	[[ `\ls $*.wk/input.symlink/*.done | wc -l` -eq 50 ]] || ! echo "Not all input parts were processed" >&2
	[[ `find $*.wk/input.symlink/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All input parts should be none empty." >&2
	[[ `find $*.wk/_SLASH_dev_SLASH_stderr.done/ -type f | wc -l` -eq 50 ]] || ! echo "Missing error logs" >&2
	[[ `cat $*.wk/$*.done/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the output is missing" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Too many output parts" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Not all output parts were processed" >&2
	[[ `find $*.wk/$*.done/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All output parts should be none empty." >&2
	diff <(rev input.symlink) $*  --brief

testcase.stripe.symlink:  input.symlink
	${PARALLELIZE_PL} -stripe -workdir=$@.wk -debug -n 50 -np 5 '${PROCESS} < $< > $@' 2> $@.log

.PHONY: testcase.stripe.symlink.validate
symlink:  testcase.stripe.symlink.validate
testcase.stripe.symlink.validate:  %.validate:  %
	[[ `cat $*.wk/input.symlink/* | wc -l` -eq 0 ]] || ! echo "Seems that stripe did not work" >&2
	[[ `\ls $*.wk/input.symlink/* | wc -l` -eq 50 ]] || ! echo "Too many input parts" >&2
	[[ `\ls $*.wk/input.symlink/*.done | wc -l` -eq 50 ]] || ! echo "Not all input parts were processed" >&2
	[[ `find $*.wk/input.symlink/ -type f -empty | wc -l` -eq 50 ]] || ! echo "All input parts should be empty." >&2
	[[ `find $*.wk/_SLASH_dev_SLASH_stderr.done/ -type f | wc -l` -eq 50 ]] || ! echo "Missing error logs" >&2
	[[ `cat $*.wk/$*.done/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the output is missing" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Too many output parts" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Not all output parts were processed" >&2
	[[ `find $*.wk/$*.done/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All output parts should be none empty." >&2
	diff <(rev input.symlink) $*  --brief



########################################
# Using xz compressed files.

testcase.xz:  input.xz
	${PARALLELIZE_PL} -workdir=$@.wk -debug -n 50 -np 5 '${PROCESS} < $< > $@' 2> $@.log

.PHONY: testcase.xz.validate
testSuite:  testcase.xz.validate
testcase.xz.validate:  %.validate:  %
	[[ `cat $*.wk/input.xz/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the input is missing" >&2
	[[ `\ls $*.wk/input.xz/* | wc -l` -eq 50 ]] || ! echo "Too many input parts" >&2
	[[ `\ls $*.wk/input.xz/*.done | wc -l` -eq 50 ]] || ! echo "Not all input parts were processed" >&2
	[[ `find $*.wk/input.xz/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All input parts should be none empty." >&2
	[[ `find $*.wk/_SLASH_dev_SLASH_stderr.done/ -type f | wc -l` -eq 50 ]] || ! echo "Missing error logs" >&2
	[[ `cat $*.wk/$*.done/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the output is missing" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Too many output parts" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Not all output parts were processed" >&2
	[[ `find $*.wk/$*.done/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All output parts should be none empty." >&2
	diff <(xzcat input.xz | rev) <(xzcat $*)  --brief

testcase.stripe.xz:  input.xz
	${PARALLELIZE_PL} -stripe -workdir=$@.wk -debug -n 50 -np 5 '${PROCESS} < $< > $@' 2> $@.log

.PHONY: testcase.stripe.xz.validate
testSuite:  testcase.stripe.xz.validate
testcase.stripe.xz.validate:  %.validate:  %
	[[ `cat $*.wk/input.xz/* | wc -l` -eq 0 ]] || ! echo "Seems that stripe did not work" >&2
	[[ `\ls $*.wk/input.xz/* | wc -l` -eq 50 ]] || ! echo "Too many input parts" >&2
	[[ `\ls $*.wk/input.xz/*.done | wc -l` -eq 50 ]] || ! echo "Not all input parts were processed" >&2
	[[ `find $*.wk/input.xz/ -type f -empty | wc -l` -eq 50 ]] || ! echo "All input parts should be empty." >&2
	[[ `find $*.wk/_SLASH_dev_SLASH_stderr.done/ -type f | wc -l` -eq 50 ]] || ! echo "Missing error logs" >&2
	[[ `cat $*.wk/$*.done/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the output is missing" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Too many output parts" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Not all output parts were processed" >&2
	[[ `find $*.wk/$*.done/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All output parts should be none empty." >&2
	diff <(xzcat input.xz | rev) <(xzcat $*)  --brief



########################################
# Using gzip compressed files.

testcase.gz:  input.gz
	${PARALLELIZE_PL} -workdir=$@.wk -debug -n 50 -np 5 '${PROCESS} < $< > $@' 2> $@.log

.PHONY: testcase.gz.validate
testSuite:  testcase.gz.validate
testcase.gz.validate:  %.validate:  %
	[[ `cat $*.wk/input.gz/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the input is missing" >&2
	[[ `\ls $*.wk/input.gz/* | wc -l` -eq 50 ]] || ! echo "Too many input parts" >&2
	[[ `\ls $*.wk/input.gz/*.done | wc -l` -eq 50 ]] || ! echo "Not all input parts were processed" >&2
	[[ `find $*.wk/input.gz/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All input parts should be none empty." >&2
	[[ `find $*.wk/_SLASH_dev_SLASH_stderr.done/ -type f | wc -l` -eq 50 ]] || ! echo "Missing error logs" >&2
	[[ `cat $*.wk/$*.done/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the output is missing" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Too many output parts" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Not all output parts were processed" >&2
	[[ `find $*.wk/$*.done/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All output parts should be none empty." >&2
	diff <(zcat input.gz | rev) <(zcat $*)  --brief

testcase.stripe.gz:  input.gz
	${PARALLELIZE_PL} -stripe -workdir=$@.wk -debug -n 50 -np 5 '${PROCESS} < $< > $@' 2> $@.log

.PHONY: testcase.stripe.gz.validate
testSuite:  testcase.stripe.gz.validate
testcase.stripe.gz.validate:  %.validate:  %
	[[ `cat $*.wk/input.gz/* | wc -l` -eq 0 ]] || ! echo "Seems that stripe did not work" >&2
	[[ `\ls $*.wk/input.gz/* | wc -l` -eq 50 ]] || ! echo "Too many input parts" >&2
	[[ `\ls $*.wk/input.gz/*.done | wc -l` -eq 50 ]] || ! echo "Not all input parts were processed" >&2
	[[ `find $*.wk/input.gz/ -type f -empty | wc -l` -eq 50 ]] || ! echo "All input parts should be empty." >&2
	[[ `find $*.wk/_SLASH_dev_SLASH_stderr.done/ -type f | wc -l` -eq 50 ]] || ! echo "Missing error logs" >&2
	[[ `cat $*.wk/$*.done/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the output is missing" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Too many output parts" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Not all output parts were processed" >&2
	[[ `find $*.wk/$*.done/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All output parts should be none empty." >&2
	diff <(zcat input.gz | rev) <(zcat $*)  --brief



########################################
# Using multiple files.

input2:
	seq 50000 $$((50000 - 1 + ${NUM_SRC_INPUT})) > $@

.PHONY:  multiple
testSuite:  multiple

testcase.multiple:  input input2
	${PARALLELIZE_PL} -workdir=$@.wk -debug -n 50 -np 5 -s '$+' 'paste $+ > $@' 2> $@.log

.PHONY: testcase.multiple.validate
multiple:  testcase.multiple.validate
testcase.multiple.validate:  %.validate:  %
	[[ `cat $*.wk/input/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the input is missing" >&2
	[[ `\ls $*.wk/input/* | wc -l` -eq 50 ]] || ! echo "Too many input parts" >&2
	[[ `\ls $*.wk/input/*.done | wc -l` -eq 50 ]] || ! echo "Not all input parts were processed" >&2
	[[ `find $*.wk/input/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All input parts should be none empty." >&2
	[[ `cat $*.wk/input2/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the input2 is missing" >&2
	[[ `\ls $*.wk/input2/* | wc -l` -eq 50 ]] || ! echo "Too many input2 parts" >&2
	[[ `find $*.wk/input2/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All input2 parts should be none empty." >&2
	[[ `find $*.wk/_SLASH_dev_SLASH_stderr.done/ -type f | wc -l` -eq 50 ]] || ! echo "Missing error logs" >&2
	[[ `cat $*.wk/$*.done/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the output is missing" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Too many output parts" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Not all output parts were processed" >&2
	[[ `find $*.wk/$*.done/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All output parts should be none empty." >&2
	diff <(paste input input2) $*  --brief

testcase.stripe.multiple:  input input2
	${PARALLELIZE_PL} -stripe -workdir=$@.wk -debug -n 50 -np 5 -s '$+' 'paste $+ > $@' 2> $@.log

.PHONY: testcase.stripe.multiple.validate
multiple:  testcase.stripe.multiple.validate
testcase.stripe.multiple.validate:  %.validate:  %
	[[ `cat $*.wk/input/* | wc -l` -eq 0 ]] || ! echo "Seems that stripe did not work" >&2
	[[ `\ls $*.wk/input/* | wc -l` -eq 50 ]] || ! echo "Too many input parts" >&2
	[[ `\ls $*.wk/input/*.done | wc -l` -eq 50 ]] || ! echo "Not all input parts were processed" >&2
	[[ `find $*.wk/input/ -type f -empty | wc -l` -eq 50 ]] || ! echo "All input parts should be empty." >&2
	[[ `cat $*.wk/input2/* | wc -l` -eq 0 ]] || ! echo "Seems that stripe did not work" >&2
	[[ `\ls $*.wk/input2/* | wc -l` -eq 0 ]] || ! echo "Too many input2 parts" >&2
	[[ `find $*.wk/_SLASH_dev_SLASH_stderr.done/ -type f | wc -l` -eq 50 ]] || ! echo "Missing error logs" >&2
	[[ `cat $*.wk/$*.done/* | wc -l` -eq ${NUM_SRC_INPUT} ]] || ! echo "Some of the output is missing" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Too many output parts" >&2
	[[ `\ls $*.wk/$*.done/* | wc -l` -eq 50 ]] || ! echo "Not all output parts were processed" >&2
	[[ `find $*.wk/$*.done/ -type f -empty | wc -l` -eq 0 ]] || ! echo "All output parts should be none empty." >&2
	diff <(paste input input2) $*  --brief
