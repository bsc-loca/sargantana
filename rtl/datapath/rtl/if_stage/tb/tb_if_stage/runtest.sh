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
 $IF_STAGE/if_stage.sv  $IF_STAGE/branch_predictor.sv $IF_STAGE/bimodal_predictor.sv \
 tb_if_stage.sv colors.vh
vmake lib_module/ > Makefile

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_if_stage -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_if_stage $1 -do "run $CYCLES"
fi
