#$1
VLOG_FLAGS=-svinputport=compat 
CYCLES=-all

TOP_DIR="../../../.."

rm -rf lib_module 
vlib lib_module
vmap work $PWD/lib_module
vlog $VLOG_FLAGS +acc=rn +incdir+ ${TOP_DIR}/includes/riscv_pkg.sv ${TOP_DIR}/includes/drac_pkg.sv ${TOP_DIR}/rtl/interface_dcache/rtl/interface_dcache.sv tb_module.sv colors.vh
vmake lib_module/ > Makefile

#vsim work.tb_module -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_module -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_module $1 -do "run $CYCLES"
fi
