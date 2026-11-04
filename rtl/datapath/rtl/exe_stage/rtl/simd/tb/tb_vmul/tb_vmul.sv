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

/* Streaming test of vmul against a behavioral model of the RVV integer
* multiplications it serves (every instruction type functional_unit sends it,
* every legal SEW). A new operation is issued on most cycles; its result is
* checked when it leaves the module, 1 cycle later for SEW<64 and 2 for
* SEW=64. Bubbles are other instruction types with any SEW, as functional_unit
* feeds every instruction to vmul: e.g. a vsetivli still carries the previous
* SEW, so a SEW=64 non-multiplication right before a SEW<64 multiplication
* must not take the output. As in simd_unit, a multiplication is held back
* (a bubble) when its result would leave together with the previous one
* (SEW<64 right after a SEW=64 multiplication).
* Random asynchronous resets drop the operations in flight.
* data_vd_o is always checked, full_data_o for the single-width ones.
* Build and run for VLEN 128/256/512 with ../run_tbs.sh vmul, or by hand
* (from the core tree root):
*   verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style \
*     +define+SARG_VLEN=<vlen> --top-module tb_vmul -F filelist.f \
*     rtl/datapath/rtl/exe_stage/rtl/simd/tb/tb_vmul/tb_vmul.sv
*   ./obj_dir/Vtb_vmul +seed=<n> +ops=<n>     (prints PASS/FAIL)
*/
module tb_vmul;
  import drac_pkg::*;
  import riscv_pkg::*;

  logic        clk = 0, rstn = 0;
  instr_type_t instr;
  sew_t        sew;
  bus64_t      vs1, vs2, vd;
  bus128_t     full;

  vmul dut (.clk_i(clk), .rstn_i(rstn), .instr_type_i(instr), .sew_i(sew),
            .data_vs1_i(vs1), .data_vs2_i(vs2), .data_vd_o(vd), .full_data_o(full));

  localparam int NOPS = 19;
  localparam instr_type_t OPS [NOPS] = '{VMUL, VMULH, VMULHU, VMULHSU, VSMUL,
    VMADD, VNMSUB, VMACC, VNMSAC, VWMUL, VWMULU, VWMULSU, VWMACC, VWMACCU,
    VWMACCSU, VWMACCUS, VADD, VAND, VSLL};   // the last 3 are bubbles (other units)

  function automatic bit is_wide(instr_type_t i);
    return i inside {VWMUL, VWMULU, VWMULSU, VWMACC, VWMACCU, VWMACCSU, VWMACCUS};
  endfunction
  function automatic bit is_mul(instr_type_t i);
    return i inside {VMUL, VMULH, VMULHU, VMULHSU, VSMUL, VMADD, VNMSUB, VMACC, VNMSAC} || is_wide(i);
  endfunction
  // RVV signedness of data_vs1_i and data_vs2_i (the multiplicands)
  function automatic bit s1_signed(instr_type_t i);
    return !(i inside {VMULHU, VWMULU, VWMACCU, VMULHSU, VWMULSU, VWMACCUS});
  endfunction
  function automatic bit s2_signed(instr_type_t i);
    return !(i inside {VMULHU, VWMULU, VWMACCU, VWMACCSU});
  endfunction

  // Element w bits wide at the bottom of x, extended to 128 bits
  function automatic logic [127:0] ext(logic [63:0] x, int w, bit s);
    logic [127:0] r = '0;
    for (int b = 0; b < 128; b++) r[b] = (b < w) ? x[b] : (s & x[w-1]);
    return r;
  endfunction

  // Random operand built from per-element corner values
  function automatic logic [63:0] gen(int ew);
    logic [63:0] r = {$urandom, $urandom};
    if ($urandom_range(0, 3) == 0) return r;
    for (int i = 0; i < 64/ew; i++) begin
      logic [63:0] e;
      case ($urandom_range(0, 7))
        0: e = '0;                                  // 0
        1: e = 64'd1;                               // 1
        2: e = '1;                                  // -1 / max unsigned
        3: e = 64'd1 << (ew-1);                     // min signed
        4: e = ~(64'd1 << (ew-1));                  // max signed
        5: e = 64'($urandom_range(0, 3));           // small
        default: e = {$urandom, $urandom};
      endcase
      for (int b = 0; b < ew; b++) r[i*ew + b] = e[b];
    end
    return r;
  endfunction

  // Expected data_vd_o and full_data_o
  task automatic model(input instr_type_t i, input sew_t s, input logic [63:0] a, input logic [63:0] b,
                       output logic [63:0] exp_vd, output logic [127:0] exp_full);
    int ew = 8 << s;
    bit mh = i inside {VMULH, VMULHU, VMULHSU};
    exp_vd = '0;
    exp_full = '0;
    for (int e = 0; e < 64/ew; e++) begin
      // Low 128 bits of the exact product (all that is ever read)
      logic [127:0] p = ext(a >> (e*ew), ew, s1_signed(i)) * ext(b >> (e*ew), ew, s2_signed(i));
      if (is_wide(i)) begin
        if (e < 32/ew) for (int k = 0; k < 2*ew; k++) exp_vd[e*2*ew + k] = p[k];
      end else begin
        for (int k = 0; k < ew; k++)   exp_vd[e*ew + k] = mh ? p[ew + k] : p[k];
        for (int k = 0; k < 2*ew; k++) exp_full[e*2*ew + k] = p[k];
      end
    end
  endtask

  // Results in flight, indexed by the cycle they leave the module
  typedef struct {
    bit          valid;
    instr_type_t instr;
    sew_t        sew;
    logic [63:0] vs1, vs2, vd;
    logic [127:0] full;
  } exp_t;
  exp_t sb [4];

  longint unsigned cyc = 0, nops = 0, nchk = 0, errs = 0, nrst = 0, nheld = 0, max_ops;
  int unsigned cov [NOPS][4];

  always #5 clk = ~clk;

  initial begin
    int unsigned seed;
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    if (!$value$plusargs("ops=%d", max_ops)) max_ops = 200000;
    void'($urandom(seed));
    instr = VADD; sew = SEW_8; vs1 = '0; vs2 = '0;
    #2 rstn = 1;
  end

  // Check what leaves now and issue the next operation on negedge
  always @(negedge clk) begin
    automatic int slot = int'(cyc % 4);
    automatic int k;
    automatic exp_t x;
    // Random asynchronous reset: everything in flight is lost
    if ($urandom_range(0, 1999) == 0) begin
      rstn = 0;
      #1 rstn = 1;
      foreach (sb[j]) sb[j].valid = 0;
      nrst++;
    end
    #1;
    if (sb[slot].valid) begin
      x = sb[slot];
      nchk++;
      if (vd !== x.vd || (!is_wide(x.instr) && full !== x.full)) begin
        errs++;
        if (errs <= 10)
          $display("MISMATCH cyc=%0d %s sew=%0d vs1=%h vs2=%h vd=%h exp=%h full=%h exp=%h", cyc,
                   x.instr.name(), 8 << x.sew, x.vs1, x.vs2, vd, x.vd, full, x.full);
      end
      sb[slot].valid = 0;
    end
    // Next operation
    k = $urandom_range(0, NOPS-1);
    instr = OPS[k];
    sew = sew_t'(is_wide(instr) ? $urandom_range(0, 2) : $urandom_range(0, 3));
    vs1 = gen(8 << sew);
    vs2 = gen(8 << sew);
    if (is_mul(instr)) begin
      automatic int lat = (sew == SEW_64) ? 2 : 1;
      automatic int due = int'((cyc + lat) % 4);
      if (sb[due].valid) begin
        instr = VADD;                               // leaves with the previous one: held back
        nheld++;
      end else begin
        sb[due].valid = 1;
        sb[due].instr = instr;
        sb[due].sew   = sew;
        sb[due].vs1   = vs1;
        sb[due].vs2   = vs2;
        model(instr, sew, vs1, vs2, sb[due].vd, sb[due].full);
        cov[k][sew]++;
        nops++;
      end
    end
    cyc++;
    if (nops >= max_ops) begin
      for (int i = 0; i < NOPS; i++) begin
        if (is_mul(OPS[i]))
          for (int s = 0; s < (is_wide(OPS[i]) ? 3 : 4); s++)
            if (cov[i][s] == 0) begin
              errs++;
              $display("NOT COVERED %s sew=%0d", OPS[i].name(), 8 << s);
            end
      end
      $display("%s VLEN=%0d cycles=%0d ops=%0d checked=%0d held=%0d resets=%0d errs=%0d",
               errs ? "FAIL" : "PASS", VLEN, cyc, nops, nchk, nheld, nrst, errs);
      $finish;
    end
  end
endmodule
