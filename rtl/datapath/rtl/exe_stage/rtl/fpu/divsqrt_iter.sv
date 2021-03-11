// Copyright 2018 ETH Zurich and University of Bologna.
//
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.

// Author:  Lei Li <lile@iis.ee.ethz.ch> 
//
// Additional contributions by: Mate Kovac <mate.kovac@fer.hr>
//
// Change history: 04/02/2020 - Removed Div_start_dly_SI input, changed module name
//                 03/03/2020 - Renamed inputs, outputs and internal signals
//

module divsqrt_iter #(
   parameter int unsigned WIDTH = 25
)(
   input  logic [WIDTH-1:0] a_i,
   input  logic [WIDTH-1:0] b_i,
   input  logic             div_enable_i,
   input  logic             sqrt_enable_i,
   input  logic [1:0]       d_i,

   output logic [1:0]       d_o,
   output logic [WIDTH-1:0] sum_o,
   output logic             carry_o
);
   logic sqrt_carry_in;
   logic carry_in;

   assign d_o[0]           = ~d_i[0];
   assign d_o[1]           = ~(d_i[1] ^ d_i[0]);
   assign sqrt_carry_in    = sqrt_enable_i && (d_i[1] | d_i[0]);
   assign carry_in         = div_enable_i ? 1'b0 : sqrt_carry_in;
   assign {carry_o, sum_o} = a_i + b_i + carry_in;

endmodule
