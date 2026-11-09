#$1
VLOG_FLAGS=-svinputport=compat
CYCLES=-all

rm -rf lib_vclmul

vlib lib_vclmul
vmap work $PWD/lib_vclmul
vlog $VLOG_FLAGS +acc=rn \
      +incdir+ \
      ../../../../../../includes/riscv_pkg.sv \
      ../../../../../../rtl/datapath/rtl/exe_stage/rtl/fpu/src/fpnew_pkg.sv \
      ../../../../../../includes/drac_pkg.sv \
      ../../rtl/simd/vclmul.sv \
      tb_vclmul.sv \
      colors.vh

if [ -z "$1" ]
then
      vsim work.tb_vclmul -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_vclmul $1 -do "run $CYCLES"
fi
