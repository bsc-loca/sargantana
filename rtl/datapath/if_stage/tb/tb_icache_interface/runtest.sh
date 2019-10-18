$1
CYCLES=80

mv lib_icache_interface /tmp

vlib lib_icache_interface
vmap work $PWD/lib_icache_interface
vlog +acc=rn +incdir+ ../riscv_pkg.sv ../drac_pkg.sv ../icache_interface.sv tb_icache_interface.sv colors.vh
vmake lib_icache_interface/ > Makefile

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_icache_interface -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_icache_interface $1 -do "run $CYCLES"
fi
