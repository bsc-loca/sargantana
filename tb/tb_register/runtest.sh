#!/bin/bash
# $1 flags for questasim
CYCLES=-all

rm -rf lib_module
vlib lib_module
vmap work $PWD/lib_module
vlog +acc=rn +incdir+ ../../includes/riscv_pkg.sv ../../includes/drac_pkg.sv ../../rtl/register.sv tb_module.sv colors.vh
vmake lib_module/ > Makefile

#vsim work.tb_module -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_module -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_module $1 -do "run $CYCLES"
fi
