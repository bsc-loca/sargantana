/*
 * Copyright 2025 BSC*
 * *Barcelona Supercomputing Center (BSC)
 *
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 * Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 * may not use this file except in compliance with the License, or, at your
 * option, the Apache License version 2.0. You may obtain a copy of the
 * License at
 *
 * https://solderpad.org/licenses/SHL-2.1/
 *
 * Unless required by applicable law or agreed to in writing, any work
 * distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */

/* Streaming test of vredtree against a behavioral model of the RVV integer
* reductions (VREDSUM/AND/OR/XOR/MAX/MAXU/MIN/MINU, VWREDSUM/VWREDSUMU) for
* every legal SEW, with random vl (also past VLEN/SEW) and masks, and corner
* element values. A new instruction is issued on most cycles; its result is
* checked when it leaves the tree, log2(VLEN/SEW) + 1 cycles later (SEW of
* the source elements), with instr_to_out_i, sew_to_out_i and
* data_old_vd driven in that cycle as simd_unit does. When the result would
* leave together with an earlier one the instruction is held back (a bubble),
* as simd_unit stalls it. Bubbles are other instruction types with random
* operands. Random asynchronous resets drop the instructions in flight.
* The whole VLEN-bit result is checked: element 0 and data_old_vd above it.
* With vl=0 or no active element the module returns vs1[0] (simd_unit does
* not write vd for vl=0).
* Build and run for VLEN 128/256/512 with ../run_tbs.sh vredtree, or by hand
* (from the core tree root):
*   verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style \
*     +define+SARG_VLEN=<vlen> --top-module tb_vredtree -F filelist.f \
*     rtl/datapath/rtl/exe_stage/rtl/simd/tb/tb_vredtree/tb_vredtree.sv
*   ./obj_dir/Vtb_vredtree +seed=<n> +ops=<n>     (prints PASS/FAIL)
*/
module tb_vredtree;
  import drac_pkg::*;
  import riscv_pkg::*;

  localparam int STAGE_SEW8 = $clog2(VLEN / 8);
  localparam int RING       = 16;                   // > longest latency (STAGE_SEW8 + 1)

  logic        clk = 0, rstn = 0;
  instr_type_t instr, instr_out;
  sew_t        sew, sew_out;
  logic [VMAXELEM_LOG:0] vl;
  bus_simd_t   vs1, vs2, old_vd, res;
  bus_mask_t   vm;

  vredtree dut (.clk_i(clk), .rstn_i(rstn), .instr_type_i(instr), .sew_i(sew), .vl_i(vl),
                .data_vs1_i(vs1), .data_vs2_i(vs2), .data_old_vd(old_vd), .data_vm_i(vm),
                .instr_to_out_i(instr_out), .sew_to_out_i(sew_out),
                .red_data_vd_o(res));

  localparam int NOPS = 13;
  localparam instr_type_t OPS [NOPS] = '{VREDSUM, VREDAND, VREDOR, VREDXOR, VREDMAX,
    VREDMAXU, VREDMIN, VREDMINU, VWREDSUM, VWREDSUMU, VADD, VMUL, VMAX};   // the last 3 are bubbles

  function automatic bit is_red(instr_type_t i);
    return i inside {VREDSUM, VREDAND, VREDOR, VREDXOR, VREDMAX, VREDMAXU, VREDMIN, VREDMINU, VWREDSUM, VWREDSUMU};
  endfunction
  function automatic bit is_wide(instr_type_t i);
    return i inside {VWREDSUM, VWREDSUMU};
  endfunction

  // Element w bits wide at the bottom of x, extended to 128 bits
  function automatic logic [127:0] ext(logic [127:0] x, int w, bit s);
    logic [127:0] r = '0;
    for (int b = 0; b < 128; b++) r[b] = (b < w) ? x[b] : (s & x[w-1]);
    return r;
  endfunction

  // Random vector built from per-element corner values
  function automatic bus_simd_t gen(int ew);
    bus_simd_t r;
    for (int i = 0; i < VLEN/32; i++) r[i*32 +: 32] = $urandom;
    if ($urandom_range(0, 3) == 0) return r;
    for (int i = 0; i < VLEN/ew; i++) begin
      logic [63:0] e;
      case ($urandom_range(0, 7))
        0: e = '0;
        1: e = 64'd1;
        2: e = '1;
        3: e = 64'd1 << (ew-1);                     // min signed
        4: e = ~(64'd1 << (ew-1));                  // max signed
        5: e = 64'($urandom_range(0, 3));
        default: e = {$urandom, $urandom};
      endcase
      for (int b = 0; b < ew; b++) r[i*ew + b] = e[b];
    end
    return r;
  endfunction

  // Expected red_data_vd_o
  function automatic bus_simd_t model(instr_type_t i, sew_t s, int unsigned n_vl, bus_simd_t a1,
                                      bus_simd_t a2, bus_mask_t m, bus_simd_t old);
    int sw = 8 << s;                                // source element width
    int rw = is_wide(i) ? 2*sw : sw;                // result width
    logic [127:0] keep = (128'd1 << rw) - 1;
    logic [127:0] acc  = ext(a1[63:0], rw, 1'b0) & keep;
    bus_simd_t r = old;
    for (int e = 0; e < VLEN/sw; e++) begin
      if (e < n_vl && m[e]) begin
        logic [127:0] x = ext(a2 >> (e*sw), sw, is_wide(i) && (i == VWREDSUM)) & keep;
        logic signed [127:0] xs = $signed(ext(x, rw, 1'b1));
        logic signed [127:0] as = $signed(ext(acc, rw, 1'b1));
        case (i)
          VREDAND:  acc = acc & x;
          VREDOR:   acc = acc | x;
          VREDXOR:  acc = acc ^ x;
          VREDMAXU: acc = (x > acc) ? x : acc;
          VREDMINU: acc = (x < acc) ? x : acc;
          VREDMAX:  acc = (xs > as) ? x : acc;
          VREDMIN:  acc = (xs < as) ? x : acc;
          default:  acc = acc + x;                  // VREDSUM, VWREDSUM, VWREDSUMU
        endcase
        acc &= keep;
      end
    end
    for (int b = 0; b < rw; b++) r[b] = acc[b];
    return r;
  endfunction

  // Results in flight, indexed by the cycle they leave the tree
  typedef struct {
    bit                    valid;
    instr_type_t           instr;
    sew_t                  sew;
    logic [VMAXELEM_LOG:0] vl;
    bus_simd_t             vs1, vs2, old_vd, res;
    bus_mask_t             vm;
  } exp_t;
  exp_t sb [RING];

  longint unsigned cyc = 0, nops = 0, nchk = 0, errs = 0, nrst = 0, nheld = 0, max_ops;
  int unsigned cov [NOPS][4];
  int unsigned n_none = 0, n_vl0 = 0, n_vlmax = 0;

  always #5 clk = ~clk;

  initial begin
    int unsigned seed;
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    if (!$value$plusargs("ops=%d", max_ops)) max_ops = 100000;
    void'($urandom(seed));
    instr = VADD; sew = SEW_8; vl = '0; vs1 = '0; vs2 = '0; vm = '0;
    instr_out = VADD; sew_out = SEW_8; old_vd = '0;
    #2 rstn = 1;
  end

  // Drive the output side and check what leaves now, then issue on negedge
  always @(negedge clk) begin
    automatic int slot = int'(cyc % RING);
    automatic int k;
    automatic exp_t x;
    // Random asynchronous reset: everything in flight is lost
    if ($urandom_range(0, 1999) == 0) begin
      rstn = 0;
      #1 rstn = 1;
      foreach (sb[j]) sb[j].valid = 0;
      nrst++;
    end
    if (sb[slot].valid) begin
      x = sb[slot];
      instr_out = x.instr;
      sew_out   = x.sew;
      old_vd    = x.old_vd;
      #1;
      nchk++;
      if (res !== x.res) begin
        errs++;
        if (errs <= 10)
          $display("MISMATCH cyc=%0d %s sew=%0d vl=%0d vm=%h vs1=%h got=%h exp=%h", cyc, x.instr.name(),
                   8 << x.sew, x.vl, x.vm, x.vs1[63:0], res[127:0], x.res[127:0]);
      end
      sb[slot].valid = 0;
    end else begin
      instr_out = VADD;                             // nothing leaves
      sew_out   = sew_t'($urandom_range(0, 3));
      old_vd    = gen(64);
      #1;
    end
    // Next instruction
    k = $urandom_range(0, NOPS-1);
    instr = OPS[k];
    sew = sew_t'(is_wide(instr) ? $urandom_range(0, 2) : $urandom_range(0, 3));
    vs1 = gen(8 << sew);
    vs2 = gen(8 << sew);
    vm  = gen(8)[VLEN/8-1:0];
    case ($urandom_range(0, 7))
      0: vm = '1;
      1: vm = '0;
      default: ;
    endcase
    case ($urandom_range(0, 7))
      0, 1, 2: vl = (VMAXELEM_LOG+1)'(VLEN / (8 << sew));                      // VLMAX for LMUL=1
      3:       vl = (VMAXELEM_LOG+1)'($urandom_range(0, VLEN/8));            // also past VLEN/SEW
      default: vl = (VMAXELEM_LOG+1)'($urandom_range(0, VLEN / (8 << sew)));
    endcase
    if (is_red(instr)) begin
      automatic int lat = STAGE_SEW8 + 1 - int'(sew);
      automatic int due = int'((cyc + lat) % RING);
      if (sb[due].valid) begin
        instr = VADD;                               // leaves with an earlier one: held back
        nheld++;
      end else begin
        sb[due].valid  = 1;
        sb[due].instr  = instr;
        sb[due].sew    = sew;
        sb[due].vl     = vl;
        sb[due].vs1    = vs1;
        sb[due].vs2    = vs2;
        sb[due].vm     = vm;
        sb[due].old_vd = gen(64);
        sb[due].res    = model(instr, sew, vl, vs1, vs2, vm, sb[due].old_vd);
        cov[k][sew]++;
        nops++;
        if (vl == 0) n_vl0++;
        if (vl == VLEN / (8 << sew)) n_vlmax++;
        begin
          automatic bit any = 0;
          for (int e = 0; e < VLEN / (8 << sew); e++) any |= (e < vl) && vm[e];
          if (!any) n_none++;
        end
      end
    end
    cyc++;
    if (nops >= max_ops) begin
      for (int i = 0; i < NOPS; i++) begin
        if (is_red(OPS[i]))
          for (int s = 0; s < (is_wide(OPS[i]) ? 3 : 4); s++)
            if (cov[i][s] == 0) begin
              errs++;
              $display("NOT COVERED %s sew=%0d", OPS[i].name(), 8 << s);
            end
      end
      $display("%s VLEN=%0d cycles=%0d ops=%0d checked=%0d held=%0d resets=%0d vl0=%0d vlmax=%0d no_active=%0d errs=%0d",
               errs ? "FAIL" : "PASS", VLEN, cyc, nops, nchk, nheld, nrst, n_vl0, n_vlmax, n_none, errs);
      $finish;
    end
  end
endmodule
