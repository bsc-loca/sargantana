#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
    pwd
)"

ROOT_DIR="$(
    cd -- "$SCRIPT_DIR/../../../../../.."
    pwd
)"

OBJ_DIR="${TMPDIR:-/tmp}/sargantana_tb_gstage_map_check_obj"

rm -rf "$OBJ_DIR"

verilator \
    --binary \
    --timing \
    -Wall \
    -Wno-fatal \
    -Wno-DECLFILENAME \
    -Wno-UNUSEDSIGNAL \
    -Wno-UNUSEDPARAM \
    -Wno-WIDTHEXPAND \
    -Wno-WIDTHTRUNC \
    -Wno-WIDTHCONCAT \
    -Wno-ASCRANGE \
    -DCONF_SARGANTANA_PHY_ADDR_SIZE=42 \
    -I"$ROOT_DIR/includes" \
    --top-module tb_gstage_map_check \
    --Mdir "$OBJ_DIR" \
    "$ROOT_DIR/includes/riscv_pkg.sv" \
    "$ROOT_DIR/rtl/datapath/rtl/exe_stage/rtl/fpu/src/common_cells/src/cf_math_pkg.sv" \
    "$ROOT_DIR/rtl/datapath/rtl/exe_stage/rtl/fpu/src/fpnew_pkg.sv" \
    "$ROOT_DIR/includes/drac_pkg.sv" \
    "$ROOT_DIR/rtl/datapath/rtl/if_stage_1/rtl/bimodal_predictor.sv" \
    "$ROOT_DIR/rtl/datapath/rtl/if_stage_1/rtl/branch_predictor.sv" \
    "$ROOT_DIR/rtl/datapath/rtl/if_stage_1/rtl/if_stage_1.sv" \
    "$SCRIPT_DIR/tb_gstage_map_check.sv"

"$OBJ_DIR/Vtb_gstage_map_check"
