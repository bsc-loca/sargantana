#$1
VLOG_FLAGS=-svinputport=compat
CYCLES=-all

rm -rf lib_module

BASE_DIR="../../../../../.."

vlib lib_module
vmap work $PWD/lib_module
vlog $VLOG_FLAGS +acc=rn +incdir+ ${BASE_DIR}/includes/riscv_pkg.sv ${BASE_DIR}/includes/def_pkg.sv ${BASE_DIR}/includes/drac_pkg.sv \
      ../../rtl/return_address_stack.sv \
      tb_module.sv colors.vh
vmake lib_module/ > Makefile

if [ -z "$1" ]
then
      vsim work.tb_module -do "view wave -new" -do "do wave.do"  -do "run $CYCLES"
else
      vsim work.tb_module $1 -do "run $CYCLES"
fi
