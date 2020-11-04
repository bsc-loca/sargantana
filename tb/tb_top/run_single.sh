#$1
VLOG_FLAGS="-svinputport=compat +define+SIMULATION"
TEST=$1
CYCLES=-all
BASE_DIR="../.."
DRAC_FOLDER_RTL="${BASE_DIR}/rtl"
TOP="${BASE_DIR}/rtl"
IF_STAGE="${BASE_DIR}/rtl/datapath/rtl/if_stage/rtl"
ID_STAGE="${BASE_DIR}/rtl/datapath/rtl/id_stage/rtl"
RR_STAGE="${BASE_DIR}/rtl/datapath/rtl/rr_stage/rtl"
CONTROL="${BASE_DIR}/rtl/control_unit/rtl"
EXE_STAGE="${BASE_DIR}/rtl/datapath/rtl/exe_stage/rtl"
DATAPATH="${BASE_DIR}/rtl/datapath/rtl"
DCACHE="${BASE_DIR}/rtl/interface_dcache/rtl"
ICACHE_INTERFACE="${BASE_DIR}/rtl/interface_icache/rtl"
ICACHE="${BASE_DIR}/rtl/icache/rtl"
CSR_INTERFACE="${BASE_DIR}/rtl/datapath/rtl/interface_csr/rtl"
INCLUDES="${BASE_DIR}/includes"

rm -rf lib_module

vlib lib_module
vmap work $PWD/lib_module
vlog $VLOG_FLAGS +acc=rn +incdir+ $INCLUDES/riscv_pkg.sv $INCLUDES/drac_pkg.sv \
 $INCLUDES/drac_icache_pkg.sv $DRAC_FOLDER_RTL/register.sv \
 $IF_STAGE/if_stage.sv $IF_STAGE/bimodal_predictor.sv $IF_STAGE/branch_predictor.sv $ID_STAGE/decoder.sv $ID_STAGE/immediate.sv $RR_STAGE/regfile.sv \
 $EXE_STAGE/exe_stage.sv $EXE_STAGE/alu.sv  $EXE_STAGE/mul_unit.sv $EXE_STAGE/div_unit.sv $EXE_STAGE/div_4bits.sv\
 $EXE_STAGE/branch_unit.sv $DCACHE/dcache_interface.sv $CONTROL/control_unit.sv \
 $ICACHE_INTERFACE/icache_interface.sv $DATAPATH/datapath.sv \
 $ICACHE/*.sv $ICACHE/icache_ctrl/rtl/icache_ctrl.sv  $ICACHE/icache_memory/rtl/*.sv \
 $CSR_INTERFACE/csr_interface.sv \
 $TOP/top_drac.sv \
 tb_top.sv perfect_memory_hex.sv perfect_memory_hex_write.sv colors.vh 

vmake lib_module/ > Makefile_test

if [ -z "$2" ]
then #// -new
      cp ${TEST} test.riscv.hex
      vsim work.tb_top -do "view wave " -do "do wave.do" -do "run $CYCLES"
else
      cp ${TEST} test.riscv.hex
      vsim work.tb_top $2 -do "run $CYCLES"
fi
