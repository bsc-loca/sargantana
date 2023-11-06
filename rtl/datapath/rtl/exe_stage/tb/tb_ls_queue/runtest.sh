$1
CYCLES=80

mv lib_ls_queue /tmp

BASE_DIR=../../../../../..

vlib lib_ls_queue
vmap work $PWD/lib_ls_queue
vlog +acc=rn +incdir+ $BASE_DIR/includes/riscv_pkg.sv $BASE_DIR/includes/drac_pkg.sv ../../rtl/load_store_queue.sv tb_ls_queue.sv ./colors.vh
vmake lib_ls_queue/ > Makefile

#vsim work.tb_icache_interface -do  "view wave -new" -do "do wave.do" -do "run 20"

if [ -z "$1" ]
then
      vsim work.tb_ls_queue -do "view wave -new" -do "do wave.do" -do "run $CYCLES"
else
      vsim work.tb_ls_queue $1 -do "run $CYCLES"
fi
