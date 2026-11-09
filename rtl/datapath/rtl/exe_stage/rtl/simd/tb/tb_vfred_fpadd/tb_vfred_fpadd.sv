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

/* Lockstep test of vfred_fpadd against the fpnew_top it replaces (FP32 and
* FP64, tied as in vfredtree/vfredoladder): random and corner operands, every
* rounding mode, random asynchronous resets; result_o and status_o must match
* on every clock phase. Build (from the core tree root):
*   verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-WIDTH \
*     --top-module tb_vfred_fpadd -F <defines.f> -F filelist.f \
*     rtl/datapath/rtl/exe_stage/rtl/simd/tb/tb_vfred_fpadd/tb_vfred_fpadd.sv
*   ./obj_dir/Vtb_vfred_fpadd +seed=<n>     (prints PASS/FAIL)
*/
module tb_vfred_fpadd;
  import fpnew_pkg::*;
  logic clk = 0, rstn = 0;
  logic [63:0] a32, b32, a64, b64;
  logic [2:0] rnd32, rnd64;
  logic [63:0] r_ref32, r_new32, r_ref64, r_new64;
  status_t s_ref32, s_new32, s_ref64, s_new64;
  logic [2:0][63:0] ops32, ops64;
  assign ops32 = {{32'h0, b32[31:0]}, {32'h0, a32[31:0]}, 64'h0};
  assign ops64 = {b64, a64, 64'h0};

  fpnew_top #(.Features(drac_pkg::SARG_ADDMUL_RV64D), .Implementation(drac_pkg::SARG_ADDMUL_ONLY)) ref32 (
    .clk_i(clk), .rst_ni(rstn), .flush_i('0), .operands_i(ops32), .rnd_mode_i(roundmode_e'(rnd32)),
    .op_i(ADD), .op_mod_i(1'b0), .src_fmt_i(FP32), .dst_fmt_i(FP32), .int_fmt_i(INT32),
    .simd_mask_i('0), .vectorial_op_i('0), .tag_i('0), .in_valid_i(1'b1), .out_ready_i(1'b1),
    .in_ready_o(), .result_o(r_ref32), .status_o(s_ref32), .tag_o(), .out_valid_o(), .busy_o(), .early_valid_o());
  fpnew_top #(.Features(drac_pkg::SARG_ADDMUL_RV64D), .Implementation(drac_pkg::SARG_ADDMUL_ONLY)) ref64 (
    .clk_i(clk), .rst_ni(rstn), .flush_i('0), .operands_i(ops64), .rnd_mode_i(roundmode_e'(rnd64)),
    .op_i(ADD), .op_mod_i(1'b0), .src_fmt_i(FP64), .dst_fmt_i(FP64), .int_fmt_i(INT64),
    .simd_mask_i('0), .vectorial_op_i('0), .tag_i('0), .in_valid_i(1'b1), .out_ready_i(1'b1),
    .in_ready_o(), .result_o(r_ref64), .status_o(s_ref64), .tag_o(), .out_valid_o(), .busy_o(), .early_valid_o());
  // FP32 dut gets random upper bits (must be ignored)
  vfred_fpadd #(.FpFormat(FP32)) dut32 (.clk_i(clk), .rstn_i(rstn), .srca_i(a32), .srcb_i(b32),
    .rnd_mode_i(roundmode_e'(rnd32)), .result_o(r_new32), .status_o(s_new32));
  vfred_fpadd #(.FpFormat(FP64)) dut64 (.clk_i(clk), .rstn_i(rstn), .srca_i(a64), .srcb_i(b64),
    .rnd_mode_i(roundmode_e'(rnd64)), .result_o(r_new64), .status_o(s_new64));

  function automatic logic [63:0] rnd64v();
    return {$urandom, $urandom};
  endfunction
  // special-value generator: fmt 0 = FP32 (in low bits), 1 = FP64
  function automatic logic [63:0] gen(input bit f64, input logic [63:0] other);
    int unsigned k = $urandom_range(0, 19);
    logic [63:0] x = rnd64v();
    int unsigned eb = f64 ? 11 : 8, mb = f64 ? 52 : 23;
    logic [63:0] emask = ((64'd1 << eb) - 1) << mb, mmask = (64'd1 << mb) - 1, smask = 64'd1 << (eb+mb);
    logic [63:0] r;
    case (k)
      0: r = x & smask;                            // +-0
      1: r = (x & smask) | emask;                  // +-inf
      2: r = (x & (smask|mmask)) | emask | (64'd1 << (mb-1)); // qNaN
      3: begin r = (x & (smask|mmask)) | emask; r[mb-1] = 0; if ((r & mmask) == 0) r[0] = 1; end // sNaN
      4: r = x & (smask|mmask);                    // subnormal
      5: r = (x & smask) | (64'd1 << mb);          // min normal
      6: r = (x & smask) | (emask - (64'd1 << mb)) | mmask; // max normal
      7: r = other ^ smask;                        // -other
      8: r = (x & ~(emask)) | ((other & emask) + (64'(int'($urandom_range(0,6)) - 3) << mb) & emask); // close exponent
      9: r = (x & ~emask) | (((other & emask) >> mb) + 64'($urandom_range(0,120)) - 60 << mb & emask); // near exps
      10: r = other ^ smask ^ 64'($urandom_range(0,3)); // near cancellation
      11: r = (x & (smask|mmask)) | (64'(($urandom_range(0,1)) ? 1 : 2) << mb); // tiny normals
      default: r = x;
    endcase
    if (!f64) r = {x[63:32], r[31:0]};
    return r;
  endfunction

  longint errs = 0, cyc = 0, valid_cyc = 0;
  initial begin
    int unsigned seed;
    if (!$value$plusargs("seed=%d", seed)) seed = 1;
    void'($urandom(seed));
    a32 = 0; b32 = 0; a64 = 0; b64 = 0; rnd32 = 0; rnd64 = 0;
    #1 rstn = 0; #4 rstn = 1;
  end
  always #5 clk = ~clk;
  // drive new inputs on negedge, random async resets
  always @(negedge clk) begin
    a32 <= gen(0, a32); b32 <= gen(0, a32);
    a64 <= gen(1, a64); b64 <= gen(1, a64);
    rnd32 <= 3'($urandom_range(0,7)); rnd64 <= 3'($urandom_range(0,7));
    if ($urandom_range(0, 999) == 0) begin
      #($urandom_range(1,4)) rstn = 0;
      #($urandom_range(1,25)) rstn = 1;
    end
  end
  // compare continuously (sampled just before each edge and mid-cycle)
  always @(clk or rstn) begin
    #0;
    #1;
    if ({r_ref32, s_ref32, r_ref64, s_ref64} !== {r_new32, s_new32, r_new64, s_new64}) begin
      errs++;
      if (errs < 10) $display("MISMATCH t=%0t rstn=%b 32: ref %h/%b new %h/%b | 64: ref %h/%b new %h/%b", $time, rstn,
        r_ref32, s_ref32, r_new32, s_new32, r_ref64, s_ref64, r_new64, s_new64);
    end
  end
  always @(posedge clk) begin
    cyc++;
    if (ref64.out_valid_o) valid_cyc++;
    if (cyc == 2000000) begin
      $display("%s cycles=%0d valid=%0d errs=%0d", errs ? "FAIL" : "PASS", cyc, valid_cyc, errs);
      $finish;
    end
  end
endmodule
