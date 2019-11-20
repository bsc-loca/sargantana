#$1
TEST=$1
CYCLES=2100
BASE_DIR="../../../.."
DRAC_FOLDER_RTL="${BASE_DIR}/rtl"
IF_STAGE="${BASE_DIR}/rtl/datapath/rtl/if_stage/rtl"
ID_STAGE="${BASE_DIR}/rtl/datapath/rtl/id_stage/rtl"
RR_STAGE="${BASE_DIR}/rtl/datapath/rtl/rr_stage/rtl"
CONTROL="${BASE_DIR}/rtl/control_unit/rtl"
EXE_STAGE="${BASE_DIR}/rtl/datapath/rtl/exe_stage/rtl"
DATAPATH="${BASE_DIR}/rtl/datapath/rtl"
DCACHE="${BASE_DIR}/rtl/interface_dcache/rtl"
INCLUDES="${BASE_DIR}/includes"

file_out="tests_status.txt"

mv lib_module /tmp

vlib lib_module
vmap work $PWD/lib_module
vlog +acc=rn +incdir+ $INCLUDES/riscv_pkg.sv $INCLUDES/drac_pkg.sv $DRAC_FOLDER_RTL/register.sv\
 $IF_STAGE/if_stage.sv $ID_STAGE/decoder.sv $ID_STAGE/immediate.sv $RR_STAGE/regfile.sv \
 $EXE_STAGE/exe_top.sv $EXE_STAGE/alu.sv  $EXE_STAGE/mul_unit.sv $EXE_STAGE/div_unit.sv \
 $EXE_STAGE/branch_unit.sv $DCACHE/interface_dcache.sv $CONTROL/control_unit.sv \
 $DATAPATH/datapath.sv tb_datapath.sv perfect_memory.sv perfect_memory_hex.sv wip_perfect_memory_hex_write.sv colors.vh 

status=$?

#vlog +acc=rn +incdir+ $INCLUDES/*.sv $DRAC_FOLDER_RTL/*.sv \
# $IF_STAGE/*.sv $ID_STAGE/*.sv $RR_STAGE/*.sv $EXE_STAGE/* $DCACHE/*.sv \
# $CONTROL/*.sv $DATAPATH/*.sv tb_datapath.sv perfect_memory.sv wip_perfect_memory_hex.sv colors.vh 

if [ $status -eq "0" ]; then
    rm -f $file_out
    touch $file_out
    vmake lib_module/ > Makefile_test

    for file in tests/*.hex; do
    #for file in tests/rv64ui-p-sw.hex; do
        cp ${file} test.riscv.hex
        test="$(cut -d'-' -f3 <<< $file)"
        test="$(cut -d'.' -f1 <<< $test)"
        vsim work.tb_datapath -c -do "run $CYCLES" -do "exit" +TESTNAME=${test} +FILENAME=${file_out}
    done
fi

