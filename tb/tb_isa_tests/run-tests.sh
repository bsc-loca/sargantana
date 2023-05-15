#!/bin/bash

SIMULATOR=$1
ISA_DIR=$2
TEST_TIMEOUT=100000

TESTS_TO_SKIP=(
    rv64ui-p-ma_data # Core doesn't support misaligned load/stores
)

print_padded() {
    pad=$(printf '%0.1s' "."{1..60})
    padlength=30
    printf '%s' "$1"
    printf '%*.*s' 0 $((padlength - ${#1} )) "$pad"
}

failed_tests=()
passed_tests=0

for test in $ISA_DIR/rv64u{f,i,d,m}-p-*; do
    test_name=$(basename $test)

    if [[ "$test_name" != *dump ]]; then
        print_padded "Testing $test_name" 

        if [[ ! ${TESTS_TO_SKIP[*]} =~ "$test_name" ]]; then
            if $SIMULATOR +max-cycles=$TEST_TIMEOUT +load=$test &> /dev/null; then
                printf "\e[32mOK\e[0m\n"
                ((passed_tests++))
            else
                printf "\e[31mFAILED\e[0m\n"
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