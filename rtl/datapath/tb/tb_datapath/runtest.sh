#!/bin/bash
# This run tests uses run_single.sh since multiple instances of the 
# ISA tests need to be run. If required run_single.sh could be replaced by 
# a script more optimized for the task that does not recompile the libraries 
# before each test.

#Store all the .hex names from the tests folder

isa_tests=""
while read file; do
    isa_tests=$isa_tests$file$'\n'
done < <(find tests -iname \*.hex )
#remove empty character at the end
isa_tests=${isa_tests::-1}

#iterate over all the listed isa_tests
echo "*** Start ISA tests form: tb_datapath "
while read p; do
    if [ -z "$1" ]
    then #// -new
        ./run_single.sh "$p"
    else
        ./run_single.sh "$p" "$1"
    fi
done <<< "$isa_tests"

echo "*** Finish ISA tests form: tb_datapath"

#This script does not perform selfchecking of results
#It will be handled by CI when filtering artifacts

exit 0
