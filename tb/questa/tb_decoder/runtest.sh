$1
CYCLES=20

mv lib_decoder /tmp

vlib lib_decoder
vmap work $PWD/lib_decoder
vlog +acc=rn +incdir+ ../riscv_pkg.sv ../drac_pkg.sv ../immediate.sv  ../decoder.sv tb_decoder.sv colors.vh
vmake lib_decoder/ > Makefile

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_decoder -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_decoder $1 -do "run $CYCLES"
fi
