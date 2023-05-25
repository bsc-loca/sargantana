#!/bin/bash

BENCHMARKS_TO_SKIP=(
    # Core doesn't support pmp
    pmp
)

for bmark in benchmarks/benchmarks/*.riscv; do
    name=$(basename $bmark .riscv)

    if [[ ! ${BENCHMARKS_TO_SKIP[*]} =~ "$name" ]]; then
        echo "*** $name ***"
        ./sim +load=$bmark
    fi
done