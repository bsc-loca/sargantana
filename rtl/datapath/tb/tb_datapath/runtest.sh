$1
CYCLES=20
DRAC_FOLDER="/home/glopez/MIRI/Q4/PD/lab/drac-inorder/rtl"
IF_STAGE="/home/glopez/MIRI/Q4/PD/lab/drac-inorder/rtl/datapath/rtl/if_stage/rtl"
ID_STAGE="/home/glopez/MIRI/Q4/PD/lab/drac-inorder/rtl/datapath/rtl/id_stage/rtl"
RR_STAGE="/home/glopez/MIRI/Q4/PD/lab/drac-inorder/rtl/datapath/rtl/rr_stage/rtl"
DATAPATH="/home/glopez/MIRI/Q4/PD/lab/drac-inorder/rtl/datapath/rtl"
INCLUDES="/home/glopez/MIRI/Q4/PD/lab/drac-inorder/includes"

mv lib_module /tmp

vlib lib_module
vmap work $PWD/lib_module
vlog +acc=rn +incdir+ $INCLUDES/riscv_pkg.sv $INCLUDES/drac_pkg.sv $DRAC_FOLDER/register.sv\
 $IF_STAGE/if_stage.sv $ID_STAGE/decoder.sv $ID_STAGE/immediate.sv $RR_STAGE/regfile.sv \
 $DATAPATH/datapath.sv tb_datapath.sv perfect_memory.sv perfect_memory_hex.sv colors.vh 
vmake lib_module/ > Makefile

if [ -z "$1" ]
then #// -new
      vsim work.tb_datapath -do "view wave " -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_datapath $1 -do "run $CYCLES"
fi
