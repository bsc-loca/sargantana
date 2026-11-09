#!/usr/bin/env bash
# Build and run SIMD unit testbenches for several VLENs with Verilator.
#   run_tbs.sh [tb ...]          tb: vmul, vredtree (default: both)
# Environment: VLENS (default "128 256 512"), SEEDS (default "1 2 3"),
#   OPS (operations per run, default: the testbench's), VERILATOR (default
#   verilator), BUILD_DIR (default ${TMPDIR:-/tmp}/simd_tb-$USER, outside the repo).
# Prints one PASS/FAIL line per run; exits non-zero if any run fails.
set -u

TB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CORE_DIR=$(cd "$TB_DIR/../../../../../../.." && pwd)
VERILATOR=${VERILATOR:-verilator}
VLENS=${VLENS:-"128 256 512"}
SEEDS=${SEEDS:-"1 2 3"}
BUILD_DIR=${BUILD_DIR:-${TMPDIR:-/tmp}/simd_tb-${USER:-tb}}
TBS=${*:-"vmul vredtree"}

cd "$CORE_DIR" || exit 1
mkdir -p "$BUILD_DIR" || exit 1
fail=0
for tb in $TBS; do
    src=$TB_DIR/tb_$tb/tb_$tb.sv
    [ -f "$src" ] || { echo "unknown testbench: $tb" >&2; exit 2; }
    for vlen in $VLENS; do
        obj=$BUILD_DIR/tb_${tb}_vlen$vlen
        # Static libstdc++: the binary does not depend on the runtime library path
        if ! "$VERILATOR" --binary --timing -Wno-fatal -Wno-lint -Wno-style \
                +define+SARG_VLEN="$vlen" --top-module "tb_$tb" -F filelist.f "$src" \
                -Mdir "$obj" -j 0 -LDFLAGS -static-libstdc++ > "$obj.build.log" 2>&1; then
            echo "FAIL tb_$tb VLEN=$vlen: build failed, see $obj.build.log"
            fail=1
            continue
        fi
        for seed in $SEEDS; do
            out=$("$obj/Vtb_$tb" +seed="$seed" ${OPS:++ops=$OPS} 2>&1)
            line=$(grep -E '^(PASS|FAIL)' <<< "$out")
            echo "tb_$tb seed=$seed: ${line:-FAIL (no result)}"
            if [ -z "$line" ] || [[ $line == FAIL* ]]; then
                grep -E 'MISMATCH|NOT COVERED|Error|error' <<< "$out" | head -5
                fail=1
            fi
        done
    done
done
exit $fail
