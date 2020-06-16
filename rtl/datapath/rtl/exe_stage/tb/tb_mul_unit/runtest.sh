#$1
VLOG_FLAGS=-svinputport=compat 
CYCLES=-all
INCLUDE="../../../../../../includes"
rm -rf lib_mul_unit

vlib lib_mul_unit
vmap work $PWD/lib_mul_unit
vlog $VLOG_FLAGS +acc=rn +incdir+  ${INCLUDE}/riscv_pkg.sv ${INCLUDE}/drac_pkg.sv ../../rtl/mul_unit.sv tb_mul_unit.sv colors.vh
vmake lib_mul_unit/ > Makefile_test

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_mul_unit -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_mul_unit $1 -do "run $CYCLES"
fi
