$1
CYCLES=-all
BASE_DIR="../../../../../.."
DRAC_FOLDER_RTL="${BASE_DIR}/rtl"
IF_STAGE="${BASE_DIR}/rtl/datapath/rtl/if_stage/rtl"
ID_STAGE="${BASE_DIR}/rtl/datapath/rtl/id_stage/rtl"
RR_STAGE="${BASE_DIR}/rtl/datapath/rtl/rr_stage/rtl"
DATAPATH="${BASE_DIR}/rtl/datapath/rtl"
INCLUDES="${BASE_DIR}/includes"

rm -rf lib_module

vlib lib_module
vmap work $PWD/lib_module
vlog +acc=rn +incdir+ $INCLUDES/riscv_pkg.sv $INCLUDES/drac_pkg.sv\
 $ID_STAGE/immediate.sv  $ID_STAGE/decoder.sv tb_decoder.sv colors.vh
vmake lib_module/ > Makefile

if [ -z "$1" ]
then
      vsim work.tb_decoder -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_decoder $1 -do "run $CYCLES"
fi
