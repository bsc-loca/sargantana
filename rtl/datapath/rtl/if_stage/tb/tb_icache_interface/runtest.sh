$1
CYCLES=80
DRAC_FOLDER="/home/glopez/MIRI/Q4/PD/lab/drac-inorder/rtl"
FETCH="/home/glopez/MIRI/Q4/PD/lab/drac-inorder/rtl/datapath/rtl/id_stage/rtl"
INCLUDES="/home/glopez/MIRI/Q4/PD/lab/drac-inorder/includes"

mv lib_module /tmp

vlib lib_module
vmap work $PWD/lib_module
vlog +acc=rn +incdir+ $INCLUDES/riscv_pkg.sv $INCLUDES/drac_pkg.sv $FETCH/icache_interface.sv\
 tb_icache_interface.sv colors.vh
vmake lib_module/ > Makefile

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_icache_interface -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_icache_interface $1 -do "run $CYCLES"
fi
