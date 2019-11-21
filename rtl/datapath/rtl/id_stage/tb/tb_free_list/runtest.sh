$1
CYCLES=20
BASE_DIR="../../../../../.."
DRAC_FOLDER_RTL="${BASE_DIR}/rtl"
IF_STAGE="${BASE_DIR}/rtl/datapath/rtl/if_stage/rtl"
ID_STAGE="${BASE_DIR}/rtl/datapath/rtl/id_stage/rtl"
RR_STAGE="${BASE_DIR}/rtl/datapath/rtl/rr_stage/rtl"
DATAPATH="${BASE_DIR}/rtl/datapath/rtl"
INCLUDES="${BASE_DIR}/includes"

mv lib_module /tmp

vlib lib_module
vmap work $PWD/lib_module
vlog +acc=rn +incdir+ $INCLUDES/riscv_pkg.sv $INCLUDES/drac_pkg.sv\
 $ID_STAGE/free_list.sv tb_free_list.sv colors.vh
vmake lib_module/ > Makefile

if [ -z "$1" ]
then
      vsim work.tb_free_list -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_free_list $1 -do "run $CYCLES"
fi
