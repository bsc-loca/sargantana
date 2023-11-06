#$1
VLOG_FLAGS=-svinputport=compat 
CYCLES=-all

TOP_DIR=$(git rev-parse --show-cdup)

rm -rf lib_module

vlib lib_module
vmap work $PWD/lib_module
vlog $VLOG_FLAGS +acc=rn +incdir+ ${TOP_DIR}includes/riscv_pkg.sv ${TOP_DIR}includes/drac_pkg.sv ${TOP_DIR}rtl/datapath/rtl/exe_stage/rtl/branch_unit.sv tb_module.sv colors.vh
vmake lib_module/ > Makefile_test

if [ -z "$1" ]
then
      vsim work.tb_module -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_module $1 -do "run $CYCLES"
fi
