#!/bin/bash

SIM=$1
SPIKE=$2
BINARY=$3

SIM_FIXED=$(mktemp)
SPIKE_FIXED=$(mktemp)

LINES_TO_SKIP=10
TERMINATE_ADDR=$(nm $BINARY | grep terminate | cut -d" " -f 1)
TERMINATE_VADDR="0xffffffffffe${TERMINATE_ADDR:11:5}"

function fix_logs() {
    tail -n +$(( $LINES_TO_SKIP + 1 )) $1 | sed -n "/core   0: $TERMINATE_VADDR/q;p"
}

fix_logs $SIM > $SIM_FIXED
fix_logs $SPIKE > $SPIKE_FIXED

diff --unified --label="Simulation" $SIM_FIXED --label="Spike" $SPIKE_FIXED

result=$?

rm $SIM_FIXED $SPIKE_FIXED

exit $result