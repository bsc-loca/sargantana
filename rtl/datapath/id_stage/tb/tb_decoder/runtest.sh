$1
CYCLES=20
DRAC_FOLDER="/home/glopez/MIRI/Q4/PD/lab/drac-inorder/hdl"
DECODER="/home/glopez/MIRI/Q4/PD/lab/drac-inorder/hdl/datapath/id_stage/hdl"

mv lib_decoder /tmp

vlib lib_decoder
vmap work $PWD/lib_decoder
vlog +acc=rn +incdir+ $DRAC_FOLDER/riscv_pkg.sv $DRAC_FOLDER/drac_pkg.sv $DECODER/immediate.sv  $DECODER/decoder.sv tb_decoder.sv colors.vh
vmake lib_decoder/ > Makefile

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_decoder -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_decoder $1 -do "run $CYCLES"
fi
