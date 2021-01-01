# This script runs a single isa test with questasim.
# To use it pass as the first argument the complete name of the test, as a
# second argument you can pass a flag for vsim such as -c to run in batch mode.

#$1: Path to the test (.hex) to be run
#$2: Flags for Vsim

VLOG_FLAGS="-svinputport=compat +define+SIMULATION"
TEST=$1
CYCLES=-all
BASE_DIR="../../../.."
DRAC_FOLDER_RTL="${BASE_DIR}/rtl"
IF_STAGE="${BASE_DIR}/rtl/datapath/rtl/if_stage/rtl"
ID_STAGE="${BASE_DIR}/rtl/datapath/rtl/id_stage/rtl"
RR_STAGE="${BASE_DIR}/rtl/datapath/rtl/rr_stage/rtl"
CSR_INTERFACE="${BASE_DIR}/rtl/datapath/rtl/interface_csr/rtl"
CONTROL="${BASE_DIR}/rtl/control_unit/rtl"
EXE_STAGE="${BASE_DIR}/rtl/datapath/rtl/exe_stage/rtl"
DATAPATH="${BASE_DIR}/rtl/datapath/rtl"
DCACHE="${BASE_DIR}/rtl/interface_dcache/rtl"
INCLUDES="${BASE_DIR}/includes"

rm -rf lib_module 

vlib lib_module
vmap work $PWD/lib_module
vlog $VLOG_FLAGS +acc=rn +incdir+ $INCLUDES/riscv_pkg.sv $INCLUDES/drac_pkg.sv $DRAC_FOLDER_RTL/register.sv\
 $IF_STAGE/if_stage.sv $IF_STAGE/bimodal_predictor.sv $IF_STAGE/branch_predictor.sv $ID_STAGE/decoder.sv $ID_STAGE/immediate.sv $RR_STAGE/regfile.sv \
 $EXE_STAGE/exe_stage.sv $EXE_STAGE/alu.sv  $EXE_STAGE/mul_unit.sv $EXE_STAGE/div_unit.sv $EXE_STAGE/div_4bits.sv\
 $EXE_STAGE/branch_unit.sv $DCACHE/dcache_interface.sv $CONTROL/control_unit.sv $CSR_INTERFACE/csr_interface.sv \
 $DATAPATH/datapath.sv tb_datapath.sv perfect_memory.sv perfect_memory_hex.sv colors.vh 

vmake lib_module/ > Makefile_test

if [ -z "$2" ]
then #// -new
      cp ./${TEST} test.riscv.hex
      vsim work.tb_datapath -do "view wave " -do "do wave.do" -do "run $CYCLES"
else
      cp ./${TEST} test.riscv.hex
      vsim $2 work.tb_datapath -do "run $CYCLES"
fi
