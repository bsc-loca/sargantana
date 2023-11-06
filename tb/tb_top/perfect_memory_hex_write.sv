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
    parameter LINE_SIZE = 128,
    parameter ADDR_SIZE = 32,
    parameter DELAY = 2,
    localparam HEX_LOAD_ADDR = 'h0F0

) (
    input logic                     clk_i,
    input logic                     rstn_i,
    input addr_t                    addr_i,
    input logic                     valid_i,
    input logic [7:0]               tag_i,
    input logic                     wr_ena_i,
    input bus_simd_t                wr_data_i,
    input logic [3:0]               word_size_i,
    output logic [LINE_SIZE-1:0]    line_o,
    output logic                    ready_o,
    output logic                    valid_o,
    output logic [7:0]              tag_o
);
    typedef enum {
        IDLE, STORE_WRITE, WAIT
    } perfect_memory_state_t;

    localparam BASE = 128;
    logic [BASE-1:0] memory [SIZE/BASE];
    logic [$clog2(DELAY):0] counter;
    logic [$clog2(DELAY):0] next_counter;

    logic  [ADDR_SIZE-1:0]    addr_int;
    assign addr_int = 'h100+({4'b0,addr_i[31:4]}-'h010);

    logic [LINE_SIZE-1:0] line_d, line_q;
    logic [ADDR_SIZE-1:0] addr_d, addr_q;
    logic [ADDR_SIZE-1:0] addr_int_d, addr_int_q;
    logic [3:0] word_size_d, word_size_q;
    logic valid_d, valid_q;
    logic tag_d, tag_q;

    perfect_memory_state_t state, next_state;

    assign ready_o = (counter == 0);
    assign line_o = line_q;
    assign tag_o = tag_q;
    assign valid_o = (counter == 1) ? valid_q : 1'b0;

    always_ff @(posedge clk_i, negedge rstn_i) begin : proc_counter
        if(~rstn_i) begin
            counter     <= 0;
            line_q      <= 0;
            valid_q     <= 0;
            tag_q       <= 0;
            addr_q      <= 0;
            addr_int_q  <= 0;
            word_size_q <= 0;
            state       <= IDLE;
        end else begin
            counter     <= next_counter;
            line_q      <= line_d;
            valid_q     <= valid_d;
            tag_q       <= tag_d;
            addr_q      <= addr_d;
            addr_int_q  <= addr_int_d;
            word_size_q <= word_size_d;
            state       <= next_state;
        end
    end 

    always_comb begin
        case (state)
            IDLE: begin
                //State in which the memory is waiting for a request
                //- If a request comes in, we hold the outputs and wait for
                //  the counter to reach 0.
                //- If the request is a load, we load and hold the data in
                //  this cycle.
                //- If the request is a store, we wait a cycle for the core
                //  to send the data.
                
                //Hold output signals and initialize counter
                if (ready_o && valid_i) begin
                    next_counter = DELAY;
                    valid_d      = 1'b1;
                    tag_d        = tag_i;
                    addr_d       = addr_i;
                    addr_int_d   = addr_int;
                    word_size_d  = word_size_i;
                    next_state   = wr_ena_i ? STORE_WRITE : WAIT;
                end else begin
                    next_counter = 0;
                    valid_d      = 0'b0;
                    tag_d        = 0'b0;
                    addr_d       = 0;
                    addr_int_d   = 0;
                    word_size_d  = 0;
                    next_state   = IDLE;
                end

                //Hold line output
                if (ready_o && valid_i) begin
                    // this case is quite harcoded following the hex 
                    // hexadecimal dump of riscv isa test that has
                    // 128 bits per line
                    case (word_size_i)
                        4'b0000: begin
                            case (addr_i[3:0])
                                4'b0000: begin
                                    line_d = {{56{memory[addr_int][7]}},memory[addr_int][7:0]};
                                end
                                4'b0001: begin
                                    line_d = {{56{memory[addr_int][15]}},memory[addr_int][15:8]};
                                end
                                4'b0010: begin
                                    line_d = {{56{memory[addr_int][23]}},memory[addr_int][23:16]};
                                end
                                4'b0011: begin
                                    line_d = {{56{memory[addr_int][31]}},memory[addr_int][31:24]};
                                end
                                4'b0100: begin
                                    line_d = {{56{memory[addr_int][39]}},memory[addr_int][39:32]};
                                end
                                4'b0101: begin
                                    line_d = {{56{memory[addr_int][47]}},memory[addr_int][47:40]};
                                end
                                4'b0110: begin
                                    line_d = {{56{memory[addr_int][55]}},memory[addr_int][55:48]};
                                end
                                4'b0111: begin
                                    line_d = {{56{memory[addr_int][63]}},memory[addr_int][63:56]};
                                end
                                4'b1000: begin
                                    line_d = {{56{memory[addr_int][71]}},memory[addr_int][71:64]};
                                end
                                4'b1001: begin
                                    line_d = {{56{memory[addr_int][79]}},memory[addr_int][79:72]};
                                end
                                4'b1010: begin
                                    line_d = {{56{memory[addr_int][87]}},memory[addr_int][87:80]};
                                end
                                4'b1011: begin
                                    line_d = {{56{memory[addr_int][95]}},memory[addr_int][95:88]};
                                end
                                4'b1100: begin
                                    line_d = {{56{memory[addr_int][103]}},memory[addr_int][103:96]};
                                end
                                4'b1101: begin
                                    line_d = {{56{memory[addr_int][111]}},memory[addr_int][111:104]};
                                end
                                4'b1110: begin
                                    line_d = {{56{memory[addr_int][119]}},memory[addr_int][119:112]};
                                end
                                4'b1111: begin
                                    line_d = {{56{memory[addr_int][127]}},memory[addr_int][127:120]};
                                end
                            endcase 
                        end
                        4'b0001: begin
                            case (addr_i[3:1])
                                3'b000: begin
                                    line_d = {{48{memory[addr_int][15]}},memory[addr_int][15:0]};
                                end
                                3'b001: begin
                                    line_d = {{48{memory[addr_int][31]}},memory[addr_int][31:16]};
                                end
                                3'b010: begin
                                    line_d = {{48{memory[addr_int][47]}},memory[addr_int][47:32]};
                                end
                                3'b011: begin
                                    line_d = {{48{memory[addr_int][63]}},memory[addr_int][63:48]};
                                end
                                3'b100: begin
                                    line_d = {{48{memory[addr_int][79]}},memory[addr_int][79:64]};
                                end
                                3'b101: begin
                                    line_d = {{48{memory[addr_int][95]}},memory[addr_int][95:80]};
                                end
                                3'b110: begin
                                    line_d = {{48{memory[addr_int][111]}},memory[addr_int][111:96]};
                                end
                                3'b111: begin
                                    line_d = {{48{memory[addr_int][127]}},memory[addr_int][127:112]};
                                end
                            endcase 
                        end
                        4'b0010: begin
                            case (addr_i[3:2])
                                2'b00: begin
                                    line_d = {{32{memory[addr_int][31]}},memory[addr_int][31:0]};
                                end
                                2'b01: begin
                                    line_d = {{32{memory[addr_int][63]}},memory[addr_int][63:32]};
                                end
                                2'b10: begin
                                    line_d = {{32{memory[addr_int][95]}},memory[addr_int][95:64]};
                                end
                                2'b11: begin
                                    line_d = {{32{memory[addr_int][127]}},memory[addr_int][127:96]};
                                end
                            endcase 
                        end
                        4'b0011: begin
                            case (addr_i[3])
                                1'b0: begin
                                    line_d = {{64{memory[addr_int][63]}},memory[addr_int][63:0]};
                                end
                                1'b1: begin
                                    line_d = {{64{memory[addr_int][127]}},memory[addr_int][127:64]};
                                end
                            endcase 
                        end
                        4'b0100: begin
                            case (addr_i[3:0])
                                4'b0000: begin
                                    line_d = {56'b0,memory[addr_int][7:0]};
                                end
                                4'b0001: begin
                                    line_d = {56'b0,memory[addr_int][15:8]};
                                end
                                4'b0010: begin
                                    line_d = {56'b0,memory[addr_int][23:16]};
                                end
                                4'b0011: begin
                                    line_d = {56'b0,memory[addr_int][31:24]};
                                end
                                4'b0100: begin
                                    line_d = {56'b0,memory[addr_int][39:32]};
                                end
                                4'b0101: begin
                                    line_d = {56'b0,memory[addr_int][47:40]};
                                end
                                4'b0110: begin
                                    line_d = {56'b0,memory[addr_int][55:48]};
                                end
                                4'b0111: begin
                                    line_d = {56'b0,memory[addr_int][63:56]};
                                end
                                4'b1000: begin
                                    line_d = {56'b0,memory[addr_int][71:64]};
                                end
                                4'b1001: begin
                                    line_d = {56'b0,memory[addr_int][79:72]};
                                end
                                4'b1010: begin
                                    line_d = {56'b0,memory[addr_int][87:80]};
                                end
                                4'b1011: begin
                                    line_d = {56'b0,memory[addr_int][95:88]};
                                end
                                4'b1100: begin
                                    line_d = {56'b0,memory[addr_int][103:96]};
                                end
                                4'b1101: begin
                                    line_d = {56'b0,memory[addr_int][111:104]};
                                end
                                4'b1110: begin
                                    line_d = {56'b0,memory[addr_int][119:112]};
                                end
                                4'b1111: begin
                                    line_d = {56'b0,memory[addr_int][127:120]};
                                end
                            endcase 
                        end
                        4'b0101: begin
                            case (addr_i[3:1])
                                3'b000: begin
                                    line_d = {48'b0,memory[addr_int][15:0]};
                                end
                                3'b001: begin
                                    line_d = {48'b0,memory[addr_int][31:16]};
                                end
                                3'b010: begin
                                    line_d = {48'b0,memory[addr_int][47:32]};
                                end
                                3'b011: begin
                                    line_d = {48'b0,memory[addr_int][63:48]};
                                end
                                3'b100: begin
                                    line_d = {48'b0,memory[addr_int][79:64]};
                                end
                                3'b101: begin
                                    line_d = {48'b0,memory[addr_int][95:80]};
                                end
                                3'b110: begin
                                    line_d = {48'b0,memory[addr_int][111:96]};
                                end
                                3'b111: begin
                                    line_d = {48'b0,memory[addr_int][127:112]};
                                end
                            endcase 
                        end
                        4'b0110: begin
                            case (addr_i[3:2])
                                2'b00: begin
                                    line_d = {32'b0,memory[addr_int][31:0]};
                                end
                                2'b01: begin
                                    line_d = {32'b0,memory[addr_int][63:32]};
                                end
                                2'b10: begin
                                    line_d = {32'b0,memory[addr_int][95:64]};
                                end
                                2'b11: begin
                                    line_d = {32'b0,memory[addr_int][127:96]};
                                end
                            endcase 
                        end
                        4'b0111: begin
                            case (addr_i[3])
                                1'b0: begin
                                    line_d = {64'b0,memory[addr_int][63:0]};
                                end
                                1'b1: begin
                                    line_d = {64'b0,memory[addr_int][127:64]};
                                end
                            endcase 
                        end
                        4'b1000: begin
                            line_d = memory[addr_int][127:0];
                        end
                        default: begin
                            line_d = 0;
                        end
                    endcase
                end else begin
                    line_d = line_q;
                end
            end
            STORE_WRITE: begin
                //Cycle in which memory is written
                //The core takes an extra cycle to send the
                //store data, that's why this state exists
                
                next_counter = counter-1;
                valid_d      = valid_q;
                tag_d        = tag_q;
                line_d       = line_q;
                addr_d       = addr_q;
                addr_int_d   = addr_int_q;
                word_size_d  = word_size_q;
                next_state   = WAIT;
            end
            WAIT: begin
                //Cycles waiting for the counter to be over
                
                next_counter = counter-1;
                valid_d      = valid_q;
                tag_d        = tag_q;
                line_d       = line_q;
                addr_d       = addr_q;
                addr_int_d   = addr_int_q;
                word_size_d  = word_size_q;
                if (counter == 1) begin
                    next_state = IDLE;
                end else begin
                    next_state = WAIT;
                end
            end
        endcase    
    end

    // Here we could add a write in order to also check the saving of data
    always_ff @(posedge clk_i, negedge rstn_i) begin : proc_load_memory
        if(~rstn_i) begin
            $readmemh("test.riscv.hex", memory, HEX_LOAD_ADDR);
        end else if (state == STORE_WRITE) begin
            /*for (integer i = 0; i < LINE_SIZE/8; i++) begin
                memory[addr + i] 
            end*/
            case (word_size_q)
                4'b0000: begin
                    case (addr_q[3:0])
                        4'b0000: begin
                            memory[addr_int_q][7:0] = wr_data_i[7:0];
                        end
                        4'b0001: begin
                            memory[addr_int_q][15:8] = wr_data_i[7:0];
                        end
                        4'b0010: begin
                            memory[addr_int_q][23:16] = wr_data_i[7:0];
                        end
                        4'b0011: begin
                            memory[addr_int_q][31:24] = wr_data_i[7:0];
                        end
                        4'b0100: begin
                            memory[addr_int_q][39:32] = wr_data_i[7:0];
                        end
                        4'b0101: begin
                            memory[addr_int_q][47:40] = wr_data_i[7:0];
                        end
                        4'b0110: begin
                            memory[addr_int_q][55:48] = wr_data_i[7:0];
                        end
                        4'b0111: begin
                            memory[addr_int_q][63:56] = wr_data_i[7:0];
                        end
                        4'b1000: begin
                            memory[addr_int_q][71:64] = wr_data_i[7:0];
                        end
                        4'b1001: begin
                            memory[addr_int_q][79:72] = wr_data_i[7:0];
                        end
                        4'b1010: begin
                            memory[addr_int_q][87:80] = wr_data_i[7:0];
                        end
                        4'b1011: begin
                            memory[addr_int_q][95:88] = wr_data_i[7:0];
                        end
                        4'b1100: begin
                            memory[addr_int_q][103:96] = wr_data_i[7:0];
                        end
                        4'b1101: begin
                            memory[addr_int_q][111:104] = wr_data_i[7:0];
                        end
                        4'b1110: begin
                            memory[addr_int_q][119:112] = wr_data_i[7:0];
                        end
                        4'b1111: begin
                            memory[addr_int_q][127:120] = wr_data_i[7:0];
                        end
                    endcase 
                end
                4'b0001: begin
                    case (addr_q[3:1])
                        3'b000: begin
                            memory[addr_int_q][15:0] = wr_data_i[15:0];
                        end
                        3'b001: begin
                            memory[addr_int_q][31:16] = wr_data_i[15:0];
                        end
                        3'b010: begin
                            memory[addr_int_q][47:32] = wr_data_i[15:0];
                        end
                        3'b011: begin
                            memory[addr_int_q][63:48] = wr_data_i[15:0];
                        end
                        3'b100: begin
                            memory[addr_int_q][79:64] = wr_data_i[15:0];
                        end
                        3'b101: begin
                            memory[addr_int_q][95:80] = wr_data_i[15:0];
                        end
                        3'b110: begin
                            memory[addr_int_q][111:96] = wr_data_i[15:0];
                        end
                        3'b111: begin
                            memory[addr_int_q][127:112] = wr_data_i[15:0];
                        end
                    endcase 
                end
                4'b0010: begin
                    case (addr_q[3:2])
                        2'b00: begin
                            memory[addr_int_q][31:0] = wr_data_i[31:0];
                        end
                        2'b01: begin
                            memory[addr_int_q][63:32] = wr_data_i[31:0];
                        end
                        2'b10: begin
                            memory[addr_int_q][95:64] = wr_data_i[31:0];
                        end
                        2'b11: begin
                            memory[addr_int_q][127:96] = wr_data_i[31:0];
                        end
                    endcase 
                end
                4'b0011: begin
                    case (addr_q[3])
                        1'b0: begin
                            memory[addr_int_q][63:0] = wr_data_i[63:0];
                        end
                        1'b1: begin
                            memory[addr_int_q][127:64] = wr_data_i[63:0];
                        end
                    endcase
                end
                4'b1000: begin
                    memory[addr_int_q][127:0] = wr_data_i;
                end
                default: begin
                end
            endcase
        end
    end
endmodule
