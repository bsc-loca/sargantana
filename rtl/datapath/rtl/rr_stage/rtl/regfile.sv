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

module regfile 
    import drac_pkg::*;
    import riscv_pkg::*;
#(
    parameter int NUM_READ_PORTS = 2,
    parameter int NUM_WRITEBACK_PORTS = 1,
    parameter int NUM_REGISTERS = 32,
    parameter logic HARDWIRED_ZERO = 1'b1,
    parameter type reg_type = logic,
    parameter type data_type = logic
)
(
    input   logic                                 clk_i,
    input   logic                                 rstn_i,
    // write port input
    input   logic     [NUM_WRITEBACK_PORTS-1:0]   write_enable_i,
    input   reg_type  [NUM_WRITEBACK_PORTS-1:0]   write_addr_i,
    input   data_type [NUM_WRITEBACK_PORTS-1:0]   write_data_i,

    // read ports input
    input   reg_type [NUM_READ_PORTS-1:0]         read_addr_i,
    // read port output
    output  data_type [NUM_READ_PORTS-1:0]        read_data_o
);

// reg 0 should be 0 why waste 1 register for this...
localparam LOWEST_REGISTER = HARDWIRED_ZERO ? 1 : 0;

data_type registers [NUM_REGISTERS-1:LOWEST_REGISTER];

data_type [NUM_READ_PORTS-1:0] bypass_data;
logic [NUM_READ_PORTS-1:0] [NUM_WRITEBACK_PORTS-1:0] bypass_enable;

// Bypass logic
always_comb begin
    bypass_data = '0;
    bypass_enable = '0;
    for (int i = 0; i < NUM_WRITEBACK_PORTS; i++) begin
        for (int j = 0; j < NUM_READ_PORTS; j++) begin
            if ((write_addr_i[i] == read_addr_i[j]) && write_enable_i[i]) begin
                bypass_data[j] = write_data_i[i];
                bypass_enable[j][i] = 1'b1;
            end
        end
    end
end

// Read port logic
always_comb begin
    for (int i = 0; i < NUM_READ_PORTS; i++) begin
        if (HARDWIRED_ZERO & (read_addr_i[i] == 0)) begin
            read_data_o[i] = '0;
        end else if (|bypass_enable[i]) begin
            read_data_o[i] = bypass_data[i];
        end else begin
            read_data_o[i] = registers[read_addr_i[i]];
        end
    end
end

// Write port logic
always_ff @(posedge clk_i)  begin
    if (~rstn_i) begin
        for (int i = LOWEST_REGISTER; i < NUM_REGISTERS; ++i) begin
            registers[i] <= '0;
        end
    end else begin
        for (int i = 0; i < NUM_WRITEBACK_PORTS; i++) begin
            if (write_enable_i[i] && (~HARDWIRED_ZERO || (write_addr_i[i] > 0))) begin
                registers[write_addr_i[i]] <= write_data_i[i];
            end
        end
    end
end

endmodule
