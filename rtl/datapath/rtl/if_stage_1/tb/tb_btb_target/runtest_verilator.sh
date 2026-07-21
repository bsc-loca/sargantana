#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd
)

ROOT_DIR=$(
    git -C "$SCRIPT_DIR" rev-parse --show-toplevel
)

TMP_BASE="${TMPDIR:-/tmp}"
OBJ_DIR=$(
    mktemp -d "${TMP_BASE%/}/sargantana_tb_btb_target.XXXXXX"
)

cleanup()
{
    rm -rf -- "$OBJ_DIR"
}

trap cleanup EXIT

verilator \
    --binary \
    --timing \
    -Wno-fatal \
    -Wno-TIMESCALEMOD \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    -Wno-WIDTHCONCAT \
    -Wno-ASCRANGE \
    --top-module tb_if_stage_btb_target \
    --Mdir "$OBJ_DIR" \
    "$ROOT_DIR/includes/riscv_pkg.sv" \
    "$ROOT_DIR/rtl/datapath/rtl/exe_stage/rtl/fpu/src/common_cells/src/cf_math_pkg.sv" \
    "$ROOT_DIR/rtl/datapath/rtl/exe_stage/rtl/fpu/src/fpnew_pkg.sv" \
    "$ROOT_DIR/includes/drac_pkg.sv" \
    "$ROOT_DIR/rtl/datapath/rtl/if_stage_1/rtl/bimodal_predictor.sv" \
    "$ROOT_DIR/rtl/datapath/rtl/if_stage_1/rtl/branch_predictor.sv" \
    "$ROOT_DIR/rtl/datapath/rtl/if_stage_1/rtl/if_stage_1.sv" \
    "$SCRIPT_DIR/tb_btb_target.sv"

"$OBJ_DIR/Vtb_if_stage_btb_target"
