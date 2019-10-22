$1
CYCLES=50
BASE_DIR="../../../.."
DRAC_FOLDER_RTL="${BASE_DIR}/rtl"
IF_STAGE="${BASE_DIR}/rtl/datapath/rtl/if_stage/rtl"
ID_STAGE="${BASE_DIR}/rtl/datapath/rtl/id_stage/rtl"
RR_STAGE="${BASE_DIR}/rtl/datapath/rtl/rr_stage/rtl"
CONTROL="${BASE_DIR}/rtl/control_unit/rtl"
EXE_STAGE="${BASE_DIR}/rtl/datapath/rtl/exe_stage/rtl"
DATAPATH="${BASE_DIR}/rtl/datapath/rtl"
INCLUDES="${BASE_DIR}/includes"

mv lib_module /tmp

vlib lib_module
vmap work $PWD/lib_module
vlog +acc=rn +incdir+ $INCLUDES/riscv_pkg.sv $INCLUDES/drac_pkg.sv $DRAC_FOLDER_RTL/register.sv\
 $IF_STAGE/if_stage.sv $ID_STAGE/decoder.sv $ID_STAGE/immediate.sv $RR_STAGE/regfile.sv \
 $EXE_STAGE/exe_top.sv $EXE_STAGE/alu.sv  $EXE_STAGE/mul_unit.sv $EXE_STAGE/div_unit.sv \
 $EXE_STAGE/branch_unit.sv $EXE_STAGE/mem_unit.sv $CONTROL/control_unit.sv \
 $DATAPATH/datapath.sv tb_datapath.sv perfect_memory.sv perfect_memory_hex.sv colors.vh 
vmake lib_module/ > Makefile

if [ -z "$1" ]
then #// -new
      vsim work.tb_datapath -do "view wave " -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_datapath $1 -do "run $CYCLES"
fi
