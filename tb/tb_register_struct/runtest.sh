#$1
CYCLES=-all

rm -rf lib_module

vlib lib_module
vmap work $PWD/lib_module
vlog +acc=rn +incdir+ ../riscv_pkg.sv ../drac_pkg.sv ../register.sv tb_module.sv colors.vh
vmake lib_module/ > Makefile

#vsim work.tb_module -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_module -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_module $1 -do "run $CYCLES"
fi
