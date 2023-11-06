/*
 * Copyright 2023 BSC*
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

import drac_pkg::*;

// this is a specific module to read hexdumps of riscv tests 
module perfect_memory_hex_write #(
    parameter SIZE = 32*1024 * 8,
    parameter LINE_SIZE = 64,
    parameter ADDR_SIZE = 32,
    parameter DELAY = 3,
    localparam HEX_LOAD_ADDR = 'h0F0

) (
    input logic                     clk_i,
    input logic                     rstn_i,
    input addr_t                    addr_i,
    input logic                     valid_i,
    input logic                     wr_ena_i,
    input bus64_t                   wr_data_i,
    input logic [3:0]               word_size_i,
    output logic [LINE_SIZE-1:0]    line_o,
    output logic                    ready_o
);
    localparam BASE = 128;
    logic [BASE-1:0] memory [SIZE/BASE];
    logic [$clog2(DELAY)-1:0] counter;
    logic [$clog2(DELAY)-1:0] next_counter;

    logic  [ADDR_SIZE-1:0]    addr_int;
    assign addr_int = 'h100+({4'b0,addr_i[31:4]}-'h010);

    // counter stuff
    assign next_counter = (counter > 0) ? counter-1 : 0;
    assign ready_o = (counter == 0);

    // counter procedure
    always_ff @(posedge clk_i, negedge rstn_i) begin : proc_counter
        if(~rstn_i) begin
            counter  <= 0;
        end else if (ready_o && valid_i) begin
            counter <= DELAY;
        end else begin
            counter <= next_counter;
        end
     end 


    always_comb begin
        // this case is quite harcoded following the hex 
        // hexadecimal dump of riscv isa test that has
        // 128 bits per line
        case (word_size_i)
            4'b0000: begin
                case (addr_i[3:0])
                    4'b0000: begin
                        line_o = {{56{memory[addr_int][7]}},memory[addr_int][7:0]};
                    end
                    4'b0001: begin
                        line_o = {{56{memory[addr_int][15]}},memory[addr_int][15:8]};
                    end
                    4'b0010: begin
                        line_o = {{56{memory[addr_int][23]}},memory[addr_int][23:16]};
                    end
                    4'b0011: begin
                        line_o = {{56{memory[addr_int][31]}},memory[addr_int][31:24]};
                    end
                    4'b0100: begin
                        line_o = {{56{memory[addr_int][39]}},memory[addr_int][39:32]};
                    end
                    4'b0101: begin
                        line_o = {{56{memory[addr_int][47]}},memory[addr_int][47:40]};
                    end
                    4'b0110: begin
                        line_o = {{56{memory[addr_int][55]}},memory[addr_int][55:48]};
                    end
                    4'b0111: begin
                        line_o = {{56{memory[addr_int][63]}},memory[addr_int][63:56]};
                    end
                    4'b1000: begin
                        line_o = {{56{memory[addr_int][71]}},memory[addr_int][71:64]};
                    end
                    4'b1001: begin
                        line_o = {{56{memory[addr_int][79]}},memory[addr_int][79:72]};
                    end
                    4'b1010: begin
                        line_o = {{56{memory[addr_int][87]}},memory[addr_int][87:80]};
                    end
                    4'b1011: begin
                        line_o = {{56{memory[addr_int][95]}},memory[addr_int][95:88]};
                    end
                    4'b1100: begin
                        line_o = {{56{memory[addr_int][103]}},memory[addr_int][103:96]};
                    end
                    4'b1101: begin
                        line_o = {{56{memory[addr_int][111]}},memory[addr_int][111:104]};
                    end
                    4'b1110: begin
                        line_o = {{56{memory[addr_int][119]}},memory[addr_int][119:112]};
                    end
                    4'b1111: begin
                        line_o = {{56{memory[addr_int][127]}},memory[addr_int][127:120]};
                    end
                endcase 
            end
            4'b0001: begin
                case (addr_i[3:1])
                    3'b000: begin
                        line_o = {{48{memory[addr_int][15]}},memory[addr_int][15:0]};
                    end
                    3'b001: begin
                        line_o = {{48{memory[addr_int][31]}},memory[addr_int][31:16]};
                    end
                    3'b010: begin
                        line_o = {{48{memory[addr_int][47]}},memory[addr_int][47:32]};
                    end
                    3'b011: begin
                        line_o = {{48{memory[addr_int][63]}},memory[addr_int][63:48]};
                    end
                    3'b100: begin
                        line_o = {{48{memory[addr_int][79]}},memory[addr_int][79:64]};
                    end
                    3'b101: begin
                        line_o = {{48{memory[addr_int][95]}},memory[addr_int][95:80]};
                    end
                    3'b110: begin
                        line_o = {{48{memory[addr_int][111]}},memory[addr_int][111:96]};
                    end
                    3'b111: begin
                        line_o = {{48{memory[addr_int][127]}},memory[addr_int][127:112]};
                    end
                endcase 
            end
            4'b0010: begin
                case (addr_i[3:2])
                    2'b00: begin
                        line_o = {{32{memory[addr_int][31]}},memory[addr_int][31:0]};
                    end
                    2'b01: begin
                        line_o = {{32{memory[addr_int][63]}},memory[addr_int][63:32]};
                    end
                    2'b10: begin
                        line_o = {{32{memory[addr_int][95]}},memory[addr_int][95:64]};
                    end
                    2'b11: begin
                        line_o = {{32{memory[addr_int][127]}},memory[addr_int][127:96]};
                    end
                endcase 
            end
            4'b0011: begin
                case (addr_i[3])
                    1'b0: begin
                        line_o = memory[addr_int][63:0];
                    end
                    1'b1: begin
                        line_o = memory[addr_int][127:64];
                    end
                endcase 
            end
            4'b0100: begin
                case (addr_i[3:0])
                    4'b0000: begin
                        line_o = {56'b0,memory[addr_int][7:0]};
                    end
                    4'b0001: begin
                        line_o = {56'b0,memory[addr_int][15:8]};
                    end
                    4'b0010: begin
                        line_o = {56'b0,memory[addr_int][23:16]};
                    end
                    4'b0011: begin
                        line_o = {56'b0,memory[addr_int][31:24]};
                    end
                    4'b0100: begin
                        line_o = {56'b0,memory[addr_int][39:32]};
                    end
                    4'b0101: begin
                        line_o = {56'b0,memory[addr_int][47:40]};
                    end
                    4'b0110: begin
                        line_o = {56'b0,memory[addr_int][55:48]};
                    end
                    4'b0111: begin
                        line_o = {56'b0,memory[addr_int][63:56]};
                    end
                    4'b1000: begin
                        line_o = {56'b0,memory[addr_int][71:64]};
                    end
                    4'b1001: begin
                        line_o = {56'b0,memory[addr_int][79:72]};
                    end
                    4'b1010: begin
                        line_o = {56'b0,memory[addr_int][87:80]};
                    end
                    4'b1011: begin
                        line_o = {56'b0,memory[addr_int][95:88]};
                    end
                    4'b1100: begin
                        line_o = {56'b0,memory[addr_int][103:96]};
                    end
                    4'b1101: begin
                        line_o = {56'b0,memory[addr_int][111:104]};
                    end
                    4'b1110: begin
                        line_o = {56'b0,memory[addr_int][119:112]};
                    end
                    4'b1111: begin
                        line_o = {56'b0,memory[addr_int][127:120]};
                    end
                endcase 
            end
            4'b0101: begin
                case (addr_i[3:1])
                    3'b000: begin
                        line_o = {48'b0,memory[addr_int][15:0]};
                    end
                    3'b001: begin
                        line_o = {48'b0,memory[addr_int][31:16]};
                    end
                    3'b010: begin
                        line_o = {48'b0,memory[addr_int][47:32]};
                    end
                    3'b011: begin
                        line_o = {48'b0,memory[addr_int][63:48]};
                    end
                    3'b100: begin
                        line_o = {48'b0,memory[addr_int][79:64]};
                    end
                    3'b101: begin
                        line_o = {48'b0,memory[addr_int][95:80]};
                    end
                    3'b110: begin
                        line_o = {48'b0,memory[addr_int][111:96]};
                    end
                    3'b111: begin
                        line_o = {48'b0,memory[addr_int][127:112]};
                    end
                endcase 
            end
            4'b0110: begin
                case (addr_i[3:2])
                    2'b00: begin
                        line_o = {32'b0,memory[addr_int][31:0]};
                    end
                    2'b01: begin
                        line_o = {32'b0,memory[addr_int][63:32]};
                    end
                    2'b10: begin
                        line_o = {32'b0,memory[addr_int][95:64]};
                    end
                    2'b11: begin
                        line_o = {32'b0,memory[addr_int][127:96]};
                    end
                endcase 
            end
            default: begin
                line_o = 0;
            end
        endcase
    end

    // Here we could add a write in order to also check the saving of data
    always_ff @(posedge clk_i, negedge rstn_i) begin : proc_load_memory
        if(~rstn_i) begin
            $readmemh("test.riscv.hex", memory, HEX_LOAD_ADDR);
        end else if (wr_ena_i) begin
            /*for (integer i = 0; i < LINE_SIZE/8; i++) begin
                memory[addr + i] 
            end*/
            case (word_size_i)
                4'b0000: begin
                    case (addr_i[3:0])
                        4'b0000: begin
                            memory[addr_int][7:0] = wr_data_i[7:0];
                        end
                        4'b0001: begin
                            memory[addr_int][15:8] = wr_data_i[7:0];
                        end
                        4'b0010: begin
                            memory[addr_int][23:16] = wr_data_i[7:0];
                        end
                        4'b0011: begin
                            memory[addr_int][31:24] = wr_data_i[7:0];
                        end
                        4'b0100: begin
                            memory[addr_int][39:32] = wr_data_i[7:0];
                        end
                        4'b0101: begin
                            memory[addr_int][47:40] = wr_data_i[7:0];
                        end
                        4'b0110: begin
                            memory[addr_int][55:48] = wr_data_i[7:0];
                        end
                        4'b0111: begin
                            memory[addr_int][63:56] = wr_data_i[7:0];
                        end
                        4'b1000: begin
                            memory[addr_int][71:64] = wr_data_i[7:0];
                        end
                        4'b1001: begin
                            memory[addr_int][79:72] = wr_data_i[7:0];
                        end
                        4'b1010: begin
                            memory[addr_int][87:80] = wr_data_i[7:0];
                        end
                        4'b1011: begin
                            memory[addr_int][95:88] = wr_data_i[7:0];
                        end
                        4'b1100: begin
                            memory[addr_int][103:96] = wr_data_i[7:0];
                        end
                        4'b1101: begin
                            memory[addr_int][111:104] = wr_data_i[7:0];
                        end
                        4'b1110: begin
                            memory[addr_int][119:112] = wr_data_i[7:0];
                        end
                        4'b1111: begin
                            memory[addr_int][127:120] = wr_data_i[7:0];
                        end
                    endcase 
                end
                4'b0001: begin
                    case (addr_i[3:1])
                        3'b000: begin
                            memory[addr_int][15:0] = wr_data_i[15:0];
                        end
                        3'b001: begin
                            memory[addr_int][31:16] = wr_data_i[15:0];
                        end
                        3'b010: begin
                            memory[addr_int][47:32] = wr_data_i[15:0];
                        end
                        3'b011: begin
                            memory[addr_int][63:48] = wr_data_i[15:0];
                        end
                        3'b100: begin
                            memory[addr_int][79:64] = wr_data_i[15:0];
                        end
                        3'b101: begin
                            memory[addr_int][95:80] = wr_data_i[15:0];
                        end
                        3'b110: begin
                            memory[addr_int][111:96] = wr_data_i[15:0];
                        end
                        3'b111: begin
                            memory[addr_int][127:112] = wr_data_i[15:0];
                        end
                    endcase 
                end
                4'b0010: begin
                    case (addr_i[3:2])
                        2'b00: begin
                            memory[addr_int][31:0] = wr_data_i[31:0];
                        end
                        2'b01: begin
                            memory[addr_int][63:32] = wr_data_i[31:0];
                        end
                        2'b10: begin
                            memory[addr_int][95:64] = wr_data_i[31:0];
                        end
                        2'b11: begin
                            memory[addr_int][127:96] = wr_data_i[31:0];
                        end
                    endcase 
                end
                4'b0011: begin
                    case (addr_i[3])
                        1'b0: begin
                            memory[addr_int][63:0] = wr_data_i;
                        end
                        1'b1: begin
                            memory[addr_int][127:64] = wr_data_i;
                        end
                    endcase
                end
                default: begin
                end
            endcase
        end
    end
endmodule : perfect_memory_hex_write
