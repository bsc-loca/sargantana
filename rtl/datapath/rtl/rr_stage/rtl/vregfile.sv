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

module vregfile 
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input   logic                        clk_i,
    input   logic                        rstn_i,
    // write port input
    input   logic      [NUM_SIMD_WB-1:0] write_enable_i,
    input   phvreg_t   [NUM_SIMD_WB-1:0] write_addr_i,
    input   bus_simd_t [NUM_SIMD_WB-1:0] write_data_i,

    // read ports input
    input   phvreg_t                     read_addr1_i,
    input   phvreg_t                     read_addr2_i,
    input   phvreg_t                     read_addr_old_vd_i,
    input   phvreg_t                     read_addrm_i,
    input   logic                        use_mask_i,
    // read port output
    output  bus_simd_t                   read_data1_o,
    output  bus_simd_t                   read_data2_o,
    output  bus_simd_t                   read_data_old_vd_o,
    output  bus_mask_t                   read_mask_o
); 

reg_simd_t registers [NUM_PHISICAL_VREGISTERS-1:0];
bus_simd_t bypass_data1;
bus_simd_t bypass_data2;
bus_simd_t bypass_data_old_vd;
bus_simd_t bypass_mask;
logic bypass1;
logic bypass2;
logic bypass_old_vd;
logic bypassm;

always_comb begin
    bypass_data1 = 'h0;
    bypass_data2 = 'h0;
    bypass_data_old_vd = 'h0;
    bypass_mask  = 'h0;
    bypass1 = 1'b0;
    bypass2 = 1'b0;
    bypass_old_vd = 1'b0;
    bypassm = 1'b0;

    for (int i = 0; i<NUM_SIMD_WB; ++i) begin
        if ((write_addr_i[i] == read_addr1_i) && write_enable_i[i]) begin
            bypass_data1        |= write_data_i[i];
            bypass1             |= 1'b1;
        end

        if ((write_addr_i[i] == read_addr2_i) && write_enable_i[i]) begin
            bypass_data2        |= write_data_i[i];
            bypass2             |= 1'b1;
        end

        if ((write_addr_i[i] == read_addr_old_vd_i) && write_enable_i[i]) begin
            bypass_data_old_vd  |= write_data_i[i];
            bypass_old_vd       |= 1'b1;
        end

        if ((use_mask_i && (write_addr_i[i] == read_addrm_i)) && write_enable_i[i]) begin
            bypass_mask         |= write_data_i[i];
            bypassm             |= 1'b1;
        end
    end

    if (bypass1) begin
        read_data1_o = bypass_data1;
    end else begin
        read_data1_o = registers[read_addr1_i];
    end

    if (bypass2) begin
        read_data2_o = bypass_data2;
    end else begin
        read_data2_o = registers[read_addr2_i];
    end

    if (bypass_old_vd) begin
        read_data_old_vd_o = bypass_data_old_vd;
    end else begin
        read_data_old_vd_o = registers[read_addr_old_vd_i];
    end

    if (use_mask_i) begin
        if (bypassm) begin
            read_mask_o = bypass_mask[VMAXELEM-1:0];
        end else begin
            read_mask_o = registers[read_addrm_i][VMAXELEM-1:0];
        end
    end else begin
        read_mask_o = '1;
    end
end

always_ff @(posedge clk_i)  begin
    if (~rstn_i) begin
        for (int i = 0; i<NUM_PHISICAL_VREGISTERS; ++i) begin
            registers[i] <= '0;
        end
    end else begin
        for (int i = 0; i<NUM_SIMD_WB; ++i) begin
            if (write_enable_i[i]) begin
                registers[write_addr_i[i]] <= write_data_i[i];
            end
        end
    end


end

endmodule
