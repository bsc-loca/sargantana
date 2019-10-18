$1
CYCLES=20
DRAC_FOLDER="/home/glopez/MIRI/Q4/PD/lab/drac-inorder/rtl"
DECODER="/home/glopez/MIRI/Q4/PD/lab/drac-inorder/rtl/datapath/rtl/id_stage/rtl"
INCLUDES="/home/glopez/MIRI/Q4/PD/lab/drac-inorder/includes"

mv lib_module /tmp

vlib lib_module
vmap work $PWD/lib_module
vlog +acc=rn +incdir+ $INCLUDES/riscv_pkg.sv $INCLUDES/drac_pkg.sv\
 $DECODER/immediate.sv  $DECODER/decoder.sv tb_decoder.sv colors.vh
vmake lib_module/ > Makefile

if [ -z "$1" ]
then
      vsim work.tb_decoder -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_decoder $1 -do "run $CYCLES"
fi
