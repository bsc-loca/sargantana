#$1
VLOG_FLAGS="-svinputport=compat +define+SIMULATION"
CYCLES=-all
RTL="../../rtl"
ROOT=$(git rev-parse --show-cdup)

rm -rf lib_fpu

vlib lib_fpu
vmap work $PWD/lib_fpu
vlog $VLOG_FLAGS +acc=rn +incdir+${ROOT}includes \
                                  ${ROOT}includes/riscv_pkg.sv \
                                  ${ROOT}includes/drac_pkg.sv \
                                  ${ROOT}includes/registers.svh \
                                  ${ROOT}includes/fpuv_pkg.sv \
                                  ${ROOT}includes/fpuv_wrapper_pkg.sv \
                                  ${RTL}/fpu/fpuv_rr_arb_tree.sv \
                                  ${RTL}/fpu/fpuv_lzc.sv \
                                  ${RTL}/fpu/fpuv_cast_multi.sv \
                                  ${RTL}/fpu/fpuv_classifier.sv \
                                  ${RTL}/fpu/fpuv_divsqrt_multi.sv \
                                  ${RTL}/fpu/fpuv_fma_multi.sv \
                                  ${RTL}/fpu/fpuv_fma.sv \
                                  ${RTL}/fpu/fpuv_noncomp.sv \
                                  ${RTL}/fpu/fpuv_opgroup_block.sv \
                                  ${RTL}/fpu/fpuv_opgroup_fmt_slice.sv \
                                  ${RTL}/fpu/fpuv_opgroup_multifmt_slice.sv \
                                  ${RTL}/fpu/fpuv_rounding.sv \
                                  ${RTL}/fpu/fpuv_top.sv \
                                  ${RTL}/fpu/fpuv_wrapper.sv \
                                  ${RTL}/divsqrt/divsqrt_iter.sv \
                                  ${RTL}/divsqrt/divsqrt_nrst.sv \
                                  ${RTL}/divsqrt/divsqrt_top.sv \
                                  tb_fpu.sv colors.vh
vmake lib_fpu/ > Makefile_test

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_fpu -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_fpu $1 -do "run $CYCLES"
fi

divsqrt_iter.sv
divsqrt_nrst.sv
divsqrt_top.sv










