#!/bin/bash

SIMULATOR=$1
ISA_DIR=$2
TEST_TIMEOUT=100000

TESTS_TO_SKIP=(
    # Core doesn't support misaligned load/stores
    rv64ui-p-ma_data
    rv64ui-v-ma_data

    # TODO: Oscar is fixing this
    rv64mi-p-csr 
)

print_padded() {
    pad=$(printf '%0.1s' "."{1..60})
    padlength=30
    printf '%s' "$1"
    printf '%*.*s' 0 $((padlength - ${#1} )) "$pad"
}

failed_tests=()
passed_tests=0

for test in $ISA_DIR/{rv64u{i,m,f,d,a}-{p,v}-*,rv64mi-p-*}; do
    test_name=$(basename $test)

    if [[ "$test_name" != *dump ]]; then
        print_padded "Testing $test_name" 

        if [[ ! ${TESTS_TO_SKIP[*]} =~ "$test_name" ]]; then
            $SIMULATOR +max-cycles=$TEST_TIMEOUT +load=$test &> /dev/null
            result=$?
            if [[ result -eq 0 ]]; then
                printf "\e[32mOK\e[0m\n"
                ((passed_tests++))
            else
                if [[ result -eq 255 ]]; then
                    printf "\e[31mTIMED OUT\e[0m\n"
                else
                    printf "\e[31mFAILED\e[0m (Test case %d)\n" "$result"
                fi
                
                failed_tests[${#failed_tests[@]}]=$test_name
            fi
        else
            printf "\e[33mSKIP\e[0m\n"
        fi
    fi
done

echo ""
echo "*** SUMMARY ***"

echo "Tests passed:  $passed_tests"
echo "Tests skipped: ${#TESTS_TO_SKIP[@]}"
echo "Tests failed:  ${#failed_tests[@]}"

if [[ "${#failed_tests[@]}" -gt 0 ]]; then
    echo ""
    echo "*** LIST OF FAILED TESTS ***"

    for test in "${failed_tests[@]}"; do
        printf "%s, " $test
    done

    printf "\n"
fi

exit ${#failed_tests[@]}