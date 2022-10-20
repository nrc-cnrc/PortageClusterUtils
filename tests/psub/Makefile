#!/usr/bin/make -rf
# vim:noet:ts=3:nowrap


PSUB := 2> /dev/null psub

vpath %.sh scripts/

-include Makefile.params

TEMP_FILES=test_noexecute.sh
include ../Makefile.incl

all:  testSuite

.PHONY:  testSuite

test_noexecute.sh:  test.sh
	cp $< $@
	chmod u-x $@


.PHONY:  testCase.notExecutable
testSuite:  testCase.notExecutable
# If the user provides a script file that is not executable AND that doesn't
# have a shebang, we should get an error.
testCase.notExecutable:  test_noexecute.sh
	${PSUB} -n $< 2>&1 \
	| grep --quiet 'is neither executable nor a script.'

.PHONY:  testCase.noScript
testSuite:  testSuite.noScript
# If no command nor script is provided, we should see an error message.
testSuite.noScript:
	${PSUB} -n 2>&1 \
	| grep --quiet 'fatal error: Missing command, nothing to run!'

.PHONY: testCase.addingResource
testSuite:  testCase.addingResource
testCase.addingResource:  test.sh
	${PSUB} -n -no-slurm -l RES1=VAL1 $< \
	| grep -A 1 '^## Resources:$$' \
	| grep --quiet '^#$$ \-l RES1=VAL1'

.PHONY: testCase.addingResources
testSuite:  testCase.addingResources
testCase.addingResources:  test.sh
	${PSUB} -n -no-slurm -l RES1=VAL1 -l RES2=VAL2 $< \
	| grep -A 1 '^## Resources:$$' \
	| grep --quiet '^#$$ \-l RES1=VAL1,RES2=VAL2'

.PHONY:  testCase.addingResourceList
testSuite:  testCase.addingResourceList
testCase.addingResourceList:  test.sh
	${PSUB} -n -no-slurm -l RES1=VAL1,RES2=VAL2 $< \
	| grep -A 1 '^## Resources:$$' \
	| grep --quiet '^#$$ \-l RES1=VAL1,RES2=VAL2'

.PHONY: testCase_slurm.priority
testSuite:  testCase_slurm.priority
testCase.priority:  test.sh
	${PSUB} -n  -p 6 $< \
	| grep --quiet 'SBATCH --qos=$ '

.PHONY: testCase.priority
testSuite:  testCase.priority
testCase.priority:  test.sh
	${PSUB} -n -no-slurm -p 6 $< \
	| grep -A 1 '^## Priority:' \
	| grep --quiet '^#$$ '

.PHONY: testCase.res_mem
testSuite:  testCase.res_mem
testCase.res_mem:  test.sh
	${PSUB} -n -3 $< \
	| grep --quiet "^#$$ \-l res_mem=$$((3 * 6 * 1024))\|^#SBATCH --mem=$$((3 * 6 * 1024))M"


.PHONY:  testCasePsubMemCpus
testSuite:  testCasePsubMemCpus

.PHONY: testCase.psubNoArgument
testCasePsubMemCpus: testCase.psubNoArgument
# Call psub with no argument => default values => 1cpu & 6G.
testCase.psubNoArgument:
	${PSUB} -n 'sleep 10'  | grep '\-l res_mem=6144\|SBATCH --mem=6144'
	${PSUB} -n 'sleep 10'  | grep '\-l res_cpus=1\|SBATCH --cpus-per-task=1'


.PHONY: testCase.dash5
testCasePsubMemCpus: testCase.dash5
# Verify the balzac way of calling psub with -5 => 5x6G & 5cpus.
testCase.dash5:
	${PSUB} -5 -n 'sleep 10'  | grep '\-l res_mem=30720\|SBATCH --mem=30720M'
	${PSUB} -5 -n 'sleep 10'  | grep '\-l res_cpus=5\|SBATCH --cpus-per-task=5'

.PHONY: testCase.cpus2
testCasePsubMemCpus: testCase.cpus2
# Call psub with 2 cpus and the default amount of vmem => 2cpus & 6Gb.
testCase.cpus2:
	${PSUB} -cpus 2 -n 'sleep 10'  | grep '\-l res_mem=6144\|-c memory=6144M\|--mem=6144M'
	${PSUB} -cpus 2 -n 'sleep 10'  | grep '\-l res_cpus=2\|-c ncores=2\|--cpus-per-task=2'

.PHONY: testCase.mem12
testCasePsubMemCpus: testCase.mem12
# Call psub with 12G of mem and the default number of cpus => 1cpu & 12G.
testCase.mem12:
	${PSUB} -mem 12 -n 'sleep 10'  | grep '\-l res_mem=12288\|-c memory=12288M\|--mem=12288M'
	${PSUB} -mem 12 -n 'sleep 10'  | grep '\-l res_cpus=1\|-c ncores=1\|--cpus-per-task=1'

.PHONY: testCase.memmap5
testCasePsubMemCpus: testCase.memmap5
# Call psub with default mem & cpus but adding 5G of vmem => 1cpu & (5+6)G.
testCase.memmap5:
	${PSUB} -memmap 5 -n 'sleep 10'  | grep '\-l res_mem=11264\|-c memory=11264M\|--mem=11264M'
	${PSUB} -memmap 5 -n 'sleep 10'  | grep '\-l res_cpus=1\|-c ncores=1\|--cpus-per-task=1'


.PHONY: testCase.dash5.cpus2
testCasePsubMemCpus: testCase.dash5.cpus2
# Call psub -5 asking for 2 cpus => 2cpus & (5x6)G.
testCase.dash5.cpus2:
	${PSUB} -5 -cpus 2 -n 'sleep 10'  | grep '\-l res_mem=30720\|-c memory=30720M\|--mem=30720M'
	${PSUB} -5 -cpus 2 -n 'sleep 10'  | grep '\-l res_cpus=2\|-c ncores=2\|--cpus-per-task=2'

.PHONY: testCase.dash5.mem12
testCasePsubMemCpus: testCase.dash5.mem12
# Call psub -5 asking for 12G mem => 5cpus & 12G.
testCase.dash5.mem12:
	${PSUB} -5 -mem 12 -n 'sleep 10'  | grep '\-l res_mem=12288\|-c memory=12288M\|--mem=12288M'
	${PSUB} -5 -mem 12 -n 'sleep 10'  | grep '\-l res_cpus=5\|-c ncores=5\|--cpus-per-task=5'

.PHONY: testCase.mem12.memmap5
testCasePsubMemCpus: testCase.mem12.memmap5
# Call psub asking for 12G plus 5G of memmap and default number of cpus => 1cpu & (12+5)G.
testCase.mem12.memmap5:
	${PSUB} -mem 12 -memmap 5 -n 'sleep 10'  | grep '\-l res_mem=17408\|-c memory=17408M\|--mem=17408M'
	${PSUB} -mem 12 -memmap 5 -n 'sleep 10'  | grep '\-l res_cpus=1\|-c ncores=1\|--cpus-per-task=1'

.PHONY: testCase.cpus7.mem12
testCasePsubMemCpus: testCase.cpus7.mem12
# Call psub asking 7 cpus and 12G of mem => 7cpus & 12G.
testCase.cpus7.mem12:
	${PSUB} -cpus 7 -mem 12 -n 'sleep 10'  | grep '\-l res_mem=12288\|-c memory=12288M\|--mem=12288M'
	${PSUB} -cpus 7 -mem 12 -n 'sleep 10'  | grep '\-l res_cpus=7\|-c ncores=7\|--cpus-per-task=7'


.PHONY: testCase.dash3.cpus7.mem12
testCasePsubMemCpus: testCase.dash3.cpus7.mem12
# Call psub -3 with 7 cpus and 12G mem => 7cpus & 12G.
testCase.dash3.cpus7.mem12:
	${PSUB} -3 -cpus 7 -mem 12 -n 'sleep 10'  | grep '\-l res_mem=12288\|-c memory=12288M\|--mem=12288M'
	${PSUB} -3 -cpus 7 -mem 12 -n 'sleep 10'  | grep '\-l res_cpus=7\|-c ncores=7\|--cpus-per-task=7'


.PHONY: testCase.dash3.cpus7.mem12.memmap5
testCasePsubMemCpus: testCase.dash3.cpus7.mem12.memmap5
# Call psub -3 with 7 cpus with 12G mem and 5G memmap => 7cpus & (12+5)G.
testCase.dash3.cpus7.mem12.memmap5:
	${PSUB} -3 -cpus 7 -mem 12 -n -memmap 5 'sleep 10'  | grep '\-l res_mem=17408\|-c memory=17408M\|--mem=17408M'
	${PSUB} -3 -cpus 7 -mem 12 -n -memmap 5 'sleep 10'  | grep '\-l res_cpus=7\|-c ncores=7\|--cpus-per-task=7'
