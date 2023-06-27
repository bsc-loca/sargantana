#!/bin/bash

SIM="./sim"
SPIKE="simulator/riscv-isa-sim/build/spike"

CONFIG=$1
BINARY="tb/tb_torture/riscv-torture/output/test_$CONFIG.riscv"

SIM_LOG=tb/tb_torture/signatures/$CONFIG\_sim.txt
SPIKE_LOG=tb/tb_torture/signatures/$CONFIG\_spike.txt

if ! [[ -f "tb/tb_torture/signatures" ]]; then
    mkdir -p tb/tb_torture/signatures
fi

if [[ -f "$BINARY" ]]; then
    $SIM +load=$BINARY +torture_dump_ON +torture_dump=$SIM_LOG
    $SPIKE -l --log-commits --isa=rv64g --mmu-dirty --log=$SPIKE_LOG $BINARY
    tb/tb_torture/sigdiff.sh $SIM_LOG $SPIKE_LOG $BINARY > tb/tb_torture/signatures/$CONFIG.diff
else
    echo "Couldn't find the binary. Is the config valid? Has it been generated?"
fi
