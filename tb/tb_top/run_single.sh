#$1
VLOG_FLAGS="-svinputport=compat +define+SIMULATION"
TEST=$1
CYCLES=-all
BASE_DIR="../.."
DRAC_FOLDER_RTL="${BASE_DIR}/rtl"
TOP="${BASE_DIR}/rtl"
IF_STAGE_1="${BASE_DIR}/rtl/datapath/rtl/if_stage_1/rtl"
IF_STAGE_2="${BASE_DIR}/rtl/datapath/rtl/if_stage_2/rtl"
ID_STAGE="${BASE_DIR}/rtl/datapath/rtl/id_stage/rtl"
IR_STAGE="${BASE_DIR}/rtl/datapath/rtl/ir_stage/rtl"
RR_STAGE="${BASE_DIR}/rtl/datapath/rtl/rr_stage/rtl"
CONTROL="${BASE_DIR}/rtl/control_unit/rtl"
EXE_STAGE="${BASE_DIR}/rtl/datapath/rtl/exe_stage/rtl"
FPU_DIR="${BASE_DIR}/rtl/datapath/rtl/exe_stage/rtl/fpu"
DATAPATH="${BASE_DIR}/rtl/datapath/rtl"
DCACHE="${BASE_DIR}/rtl/interface_dcache/rtl"
ICACHE_INTERFACE="${BASE_DIR}/rtl/interface_icache/rtl"
ICACHE="${BASE_DIR}/rtl/icache/rtl"
CSR_INTERFACE="${BASE_DIR}/rtl/datapath/rtl/interface_csr/rtl"
WB_STAGE="${BASE_DIR}/rtl/datapath/rtl/wb_stage/rtl"
INCLUDES="${BASE_DIR}/includes"

rm -rf lib_module

vlib lib_module
vmap work $PWD/lib_module
vlog $VLOG_FLAGS +acc=rn +incdir+$DRAC_FOLDER_RTL/ $INCLUDES/riscv_pkg.sv $DRAC_FOLDER_RTL/registers.svh \
 $INCLUDES/fpuv_pkg.sv $INCLUDES/drac_pkg.sv \
 $INCLUDES/sargantana_icache_pkg.sv $INCLUDES/fpuv_wrapper_pkg.sv $DRAC_FOLDER_RTL/register.sv \
 $IF_STAGE_1/if_stage_1.sv $IF_STAGE_1/bimodal_predictor.sv $IF_STAGE_1/branch_predictor.sv \
 $IF_STAGE_1/return_address_stack.sv $IF_STAGE_2/if_stage_2.sv \
 $ID_STAGE/decoder.sv $ID_STAGE/immediate.sv $RR_STAGE/regfile_fp.sv $RR_STAGE/regfile.sv $RR_STAGE/vregfile.sv \
 $IR_STAGE/instruction_queue.sv $IR_STAGE/free_list.sv $IR_STAGE/rename_table.sv $EXE_STAGE/load_store_queue.sv \
 $IR_STAGE/simd_free_list.sv $IR_STAGE/simd_rename_table.sv \
 $IR_STAGE/fp_free_list.sv $IR_STAGE/fp_rename_table.sv \
 $EXE_STAGE/exe_stage.sv $EXE_STAGE/alu.sv $EXE_STAGE/mul_unit.sv $EXE_STAGE/div_unit.sv $EXE_STAGE/div_4bits.sv \
 $EXE_STAGE/mem_unit.sv $EXE_STAGE/score_board.sv $EXE_STAGE/pending_mem_req_queue.sv $EXE_STAGE/pending_fp_ops_queue.sv \
 $EXE_STAGE/branch_unit.sv $EXE_STAGE/functional_unit.sv $EXE_STAGE/simd_unit.sv \
 $EXE_STAGE/vcomp.sv $EXE_STAGE/vshift.sv $EXE_STAGE/vaddsub.sv \
 $FPU_DIR/divsqrt_iter.sv $FPU_DIR/fpu_drac_wrapper.sv $FPU_DIR/fpuv_divsqrt_multi.sv $FPU_DIR/fpuv_lzc.sv \
 $FPU_DIR/fpuv_opgroup_fmt_slice.sv $FPU_DIR/fpuv_rr_arb_tree.sv $FPU_DIR/divsqrt_nrst.sv $FPU_DIR/fpuv_cast_multi.sv\
 $FPU_DIR/fpuv_fma_multi.sv $FPU_DIR/fpuv_noncomp.sv $FPU_DIR/fpuv_opgroup_multifmt_slice.sv $FPU_DIR/fpuv_top.sv \
 $FPU_DIR/divsqrt_top.sv $FPU_DIR/fpuv_classifier.sv $FPU_DIR/fpuv_fma.sv $FPU_DIR/fpuv_opgroup_block.sv \
 $FPU_DIR/fpuv_rounding.sv  $DCACHE/dcache_interface.sv $CONTROL/control_unit.sv $WB_STAGE/graduation_list.sv \
 $ICACHE_INTERFACE/icache_interface.sv $DATAPATH/datapath.sv \
 $ICACHE/*.sv $ICACHE/icache_ctrl/rtl/icache_ctrl.sv $ICACHE/icache_memory/rtl/*.sv \
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
