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

//`default_nettype none

module regfile_fp 
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input   logic                                 clk_i,
    input   logic                                 rstn_i,
    // write port input
    input   logic   [drac_pkg::NUM_FP_WB-1:0]     write_enable_i,
    input   phreg_t [drac_pkg::NUM_FP_WB-1:0]     write_addr_i,
    input   bus64_t [drac_pkg::NUM_FP_WB-1:0]     write_data_i,

    // read ports input
    input   phreg_t                               read_addr1_i,
    input   phreg_t                               read_addr2_i,
    input   phreg_t                               read_addr3_i,
    // read port output
    output  bus64_t                               read_data1_o,
    output  bus64_t                               read_data2_o,
    output  bus64_t                               read_data3_o

); 
// reg 0 should be 0 why waste 1 register for this...
reg64_t registers [NUM_PHYSICAL_FREGISTERS-1:0];
bus64_t bypass_data1;
bus64_t bypass_data2;
bus64_t bypass_data3;
logic   [drac_pkg::NUM_FP_WB-1:0] bypass1;
logic   [drac_pkg::NUM_FP_WB-1:0] bypass2;
logic   [drac_pkg::NUM_FP_WB-1:0] bypass3;

// these assigns select data of register at position x 
// if x = 0 then return 0

always_comb begin
    bypass_data1 = 64'b0;
    bypass_data2 = 64'b0;
    bypass_data3 = 64'b0;

    for (int i = 0; i<drac_pkg::NUM_FP_WB; ++i) begin
        if ((write_addr_i[i] == read_addr1_i) && write_enable_i[i]) begin
            bypass_data1 |= write_data_i[i];
            bypass1[i]    = 1'b1;
        end else begin
            bypass_data1 |= 64'b0;
            bypass1[i]    = 1'b0;
        end

        if ((write_addr_i[i] == read_addr2_i) && write_enable_i[i]) begin
            bypass_data2 |= write_data_i[i];
            bypass2[i]    = 1'b1;
        end else begin
            bypass_data2 |= 64'b0;
            bypass2[i]    = 1'b0;
        end

        if ((write_addr_i[i] == read_addr3_i) && write_enable_i[i]) begin
            bypass_data3 |= write_data_i[i];
            bypass3[i]    = 1'b1;
        end else begin
            bypass_data3 |= 64'b0;
            bypass3[i]    = 1'b0;
        end
    end

    if (|bypass1) begin
        read_data1_o = bypass_data1;
    end else begin
        read_data1_o = registers[read_addr1_i];
    end

    if (|bypass2) begin
        read_data2_o = bypass_data2;
    end else begin
        read_data2_o = registers[read_addr2_i];
    end

    if (|bypass3) begin
        read_data3_o = bypass_data3;
    end else begin
        read_data3_o = registers[read_addr3_i];
    end
end

always_ff @(posedge clk_i)  begin
    if (~rstn_i) begin
        registers[0] <= 64'h00;
        registers[1] <= 64'h01;
        registers[2] <= 64'h02;

        for (int i = 3; i < NUM_PHYSICAL_FREGISTERS; ++i) begin
            registers[i] <= '0;
        end
    end else begin
        for (int i = 0; i<drac_pkg::NUM_FP_WB; ++i) begin
            if (write_enable_i[i]) begin
                registers[write_addr_i[i]] <= write_data_i[i];
            end
        end
    end
end

endmodule
