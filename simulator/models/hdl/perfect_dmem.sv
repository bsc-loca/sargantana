/* -----------------------------------------------
* Project Name   : DRAC
* File           : perfect_memory_hex.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP |        |
*  0.2        | Gerard.C   |        | Added FSM
* -----------------------------------------------
*/
//`include "drac_pkg.sv"
import drac_pkg::*;

// this is a specific module to read hexdumps of riscv tests 
module perfect_dmem #(
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
    logic [LINE_SIZE-1:0] mem_out;
    logic [ADDR_SIZE-1:0] addr_d, addr_q;
    logic [ADDR_SIZE-1:0] addr_int_d, addr_int_q;
    logic [3:0] word_size_d, word_size_q;
    logic valid_d, valid_q;
    logic tag_d, tag_q;

    logic [7:0]  mem_byte;
    logic [15:0] mem_half;
    logic [31:0] mem_word;
    logic [63:0] mem_dword;

    assign mem_byte  = mem_out[{addr_i[3:0], 3'b0} +: 8];
    assign mem_half  = mem_out[{addr_i[3:1], 4'b0} +: 16];
    assign mem_word  = mem_out[{addr_i[3:2], 5'b0} +: 32];
    assign mem_dword = mem_out[{addr_i[3], 6'b0}   +: 64];

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

    import "DPI-C" function bit memory_read (input bit [31:0] addr, output bit [LINE_SIZE-1:0] data);
    import "DPI-C" function bit memory_write (input bit [31:0] addr, input bit [3:0] size, input bit [LINE_SIZE-1:0] data);

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
                    memory_read({addr_i[31:4], 4'b0}, mem_out);
                    case (word_size_i)
                        4'b0000: line_d = {{120{mem_byte[7]}},mem_byte};
                        4'b0001: line_d = {{112{mem_half[15]}},mem_half};
                        4'b0010: line_d = {{96{mem_word[31]}},mem_word};
                        4'b0011: line_d = {{64{mem_dword[63]}},mem_dword};
                        4'b0100: line_d = {120'b0,mem_byte};
                        4'b0101: line_d = {112'b0,mem_half};
                        4'b0110: line_d = {96'b0,mem_word};
                        4'b0111: line_d = {64'b0,mem_dword};
                        4'b1000: line_d = mem_out;
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
        if (rstn_i && state == STORE_WRITE) begin
            memory_write(addr_q, word_size_q, wr_data_i);
        end
    end
endmodule
