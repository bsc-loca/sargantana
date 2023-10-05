set -e

BASE_DIR="."
INCLUDE_FLAGS="+incdir+${BASE_DIR}/rtl/dcache/rtl/include/ +incdir+${BASE_DIR}/includes/ +incdir+${BASE_DIR}/rtl/"
CCFLAGS="-I${BASE_DIR}/simulator/reference/riscv-isa-sim/"
LDFLAGS="-L${BASE_DIR}/simulator/reference/build/ -ldisasm -Wl,-rpath=${BASE_DIR}/simulator/reference/build/"
DEFINES="+define+SIMULATION +define+SIM_COMMIT_LOG +define+SIM_COMMIT_LOG_DPI +define+SIM_KONATA_DUMP"
VLOG_FLAGS="-svinputport=compat +acc=rn"
CYCLES=-all

rm -rf lib_module

vlib lib_module
vmap work $PWD/lib_module

vlog $VLOG_FLAGS \
     $INCLUDE_FLAGS \
     $DEFINES \
     -ccflags "$CCFLAGS" \
     -F $BASE_DIR/filelist.f \
     -F ${BASE_DIR}/simulator/models/filelist.f \
     ${BASE_DIR}/simulator/questa/questa_top.sv

vsim work.questa_top -ldflags "$LDFLAGS" $@ -do "run $CYCLES"