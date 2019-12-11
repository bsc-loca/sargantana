#!/bin/bash

CYCLES=5000
RTL="../../rtl/"
ROOT=$(git rev-parse --show-cdup)

mv lib_graduation_list /tmp

vlib lib_graduation_list
vmap work $PWD/lib_graduation_list
vlog +acc=rn +incdir+ ${ROOT}includes/riscv_pkg.sv ${ROOT}includes/drac_pkg.sv ${RTL}graduation_list.sv tb_graduation_list.sv colors.vh
vmake lib_graduation_list/ > Makefile

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_graduation_list -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
#else
#      vsim work.tb_div_unit $1 -do "run $CYCLES"
fi
