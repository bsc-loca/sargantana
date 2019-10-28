$1
CYCLES=30000

TOP_DIR=$(git rev-parse --show-cdup)

mv lib_module /tmp

vlib lib_module
vmap work $PWD/lib_module
vlog +acc=rn +incdir+ ${TOP_DIR}includes/riscv_pkg.sv ${TOP_DIR}includes/drac_pkg.sv ${TOP_DIR}rtl/datapath/rtl/exe_stage/rtl/exe_top.sv ${TOP_DIR}rtl/datapath/rtl/exe_stage/rtl/alu.sv ${TOP_DIR}rtl/datapath/rtl/exe_stage/rtl/mul_unit.sv ${TOP_DIR}rtl/datapath/rtl/exe_stage/rtl/div_unit.sv ${TOP_DIR}rtl/datapath/rtl/exe_stage/rtl/branch_unit.sv ${TOP_DIR}rtl/interface_dcache/rtl/mem_unit.sv tb_module.sv colors.vh
vmake lib_module/ > Makefile

#vsim work.tb_module -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_module -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
#else
#      vsim work.tb_module $1 -do "run $CYCLES"
fi
