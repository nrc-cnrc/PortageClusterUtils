#!/usr/bin/make -rf
# vim:noet:ts=3:nowrap


PSUB := 2> /dev/null psub

vpath %.sh scripts/

-include Makefile.params

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
	${PSUB} -n -l RES1=VAL1 $< \
	| grep -A 1 '^## Resources:$$' \
	| grep --quiet '^#$$ \-l RES1=VAL1'

.PHONY: testCase.addingResources
testSuite:  testCase.addingResources
testCase.addingResources:  test.sh
	${PSUB} -n -l RES1=VAL1 -l RES2=VAL2 $< \
	| grep -A 1 '^## Resources:$$' \
	| grep --quiet '^#$$ \-l RES1=VAL1,RES2=VAL2'

.PHONY:  testCase.addingResourceList
testSuite:  testCase.addingResourceList
testCase.addingResourceList:  test.sh
	${PSUB} -n -l RES1=VAL1,RES2=VAL2 $< \
	| grep -A 1 '^## Resources:$$' \
	| grep --quiet '^#$$ \-l RES1=VAL1,RES2=VAL2'

.PHONY: testCase.priority
testSuite:  testCase.priority
testCase.priority:  test.sh
	${PSUB} -n -p 6 $< \
	| grep -A 1 '^## Priority:$$' \
	| grep --quiet '^#$$ \-p 6'

.PHONY: testCase.nodes
testSuite:  testCase.nodes
testCase.nodes:  test.sh
	${PSUB} -n -nodes c2:blz0:big $< \
	| grep -A 1 '^## Nodes:$$' \
	| grep --quiet '^#$$ \-l nodes=c2:blz0:big'

.PHONY: testCase.res_mem
testSuite:  testCase.res_mem
testCase.res_mem:  test.sh
	${PSUB} -n -6 $< \
	| grep --quiet "^#$$ \-l res_mem=$$((4 * 6 * 1024))"
