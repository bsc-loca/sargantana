import drac_pkg::*, hpdcache_pkg::*;


import "DPI-C" function void memory_init (input string path);
import "DPI-C" function void memory_read (input bit [31:0] addr, output bit [512-1:0] data);
import "DPI-C" function void memory_write (input bit [31:0] addr, input bit [(512/8)-1:0] byte_enable, input bit [512-1:0] data);
import "DPI-C" function void memory_amo (input bit [31:0] addr, input bit [3:0] size, input bit [3:0] amo_op, input bit [512-1:0] data, output bit [512-1:0] result);
import "DPI-C" function void memory_symbol_addr(input string symbol, output bit [63:0] addr);

import "DPI-C" function int  tohost(input bit [63:0] data);

module mem_channel #(
    parameter SIZE = 16,
    parameter DELAY = 20,
    parameter ADDR_WIDTH = 49,
    parameter DATA_WIDTH = 512,
    parameter TAG_WIDTH = 8
)(
    input logic clk_i,
    input logic rstn_i,

    output logic                        req_ready_o,
    input logic                         req_valid_i,
    input logic [ADDR_WIDTH-1:0]        req_addr_i,
    input logic [2:0]                   req_size_i,
    input logic [TAG_WIDTH-1:0]         req_id_i,
    input logic [DATA_WIDTH-1:0]        req_data_i,
    input logic [(DATA_WIDTH/8)-1:0]    req_be_i,
    input logic [1:0]                   req_command_i,
    input logic [3:0]                   req_atomic_i,

    output logic                        rsp_valid_o,
    output logic [TAG_WIDTH-1:0]        rsp_id_o,
    output logic [DATA_WIDTH-1:0]       rsp_data_o,
    output logic                        rsp_is_atomic_o,
    input logic                         rsp_ready_i
);
    // *** Time reference ***

    logic [63:0] cycles;

    always_ff @(posedge clk_i) begin
        if(~rstn_i) begin
            cycles <= 0;
        end else begin
            cycles <= cycles + 1;
        end
    end

    // *** FIFO structure ***

    typedef struct packed {
        logic [ADDR_WIDTH-1:0]      addr;
        logic [TAG_WIDTH-1:0]       tag;
        logic [2:0]                 size;
        logic [DATA_WIDTH-1:0]      data;
        logic [(DATA_WIDTH/8)-1:0]  be;
        logic [1:0]                 cmd;
        logic [3:0]                 atomic_op;
        logic [63:0]                timestamp;
    } mem_op_t;

    mem_op_t memory [0:SIZE-1];
    logic [$clog2(SIZE)-1:0] write_ptr, read_ptr;
    logic [$clog2(SIZE)-1:0] count;

    logic empty, full;

    assign empty = count == 0;
    assign full  = count == SIZE;

    mem_op_t head, new_data;
    assign head = memory[read_ptr];

    always_comb begin
        new_data.addr       = req_addr_i;
        new_data.tag        = req_id_i;
        new_data.size       = req_size_i;
        new_data.data       = req_data_i;
        new_data.be         = req_be_i;
        new_data.cmd        = req_command_i;
        new_data.atomic_op  = req_atomic_i;
        new_data.timestamp  = cycles;
    end

    logic fifo_write, fifo_read; // FIFO Controls

    assign fifo_write = req_valid_i & ~full;

    always_ff @(posedge clk_i) begin
        if (fifo_write) memory[write_ptr] <= new_data;
    end

    always_ff @(posedge clk_i) begin
        if(~rstn_i) begin
            write_ptr <= 0;
            read_ptr <= 0;
            count <= 0;
        end else begin
            if (fifo_write) write_ptr <= write_ptr + 1'b1;
            if (fifo_read && ~empty) read_ptr <= read_ptr + 1'b1;
            case({fifo_write,fifo_read})
                2'b00, 2'b11: count <= count;
                2'b01: count <= count - 1'b1;
                2'b10: count <= count + 1'b1;
            endcase
        end
    end

    // *** Control Logic ***

    typedef enum logic [1:0] {
        S_WAIT_DELAY, S_MEM_INTERFACE, S_WAIT_READY
    } state_t;

    state_t state;

    // Next-state logic
    always_ff @(posedge clk_i) begin
        if(~rstn_i) begin
            state <= S_WAIT_DELAY;
        end else begin
            case(state)
                S_WAIT_DELAY: // Waiting for the next memory op. to be "ready"
                    if (!empty && (cycles >= (head.timestamp + DELAY))) state <= S_MEM_INTERFACE;
                    else state <= S_WAIT_DELAY;
                S_MEM_INTERFACE:  // Interface with memory DPI
                    state <= S_WAIT_READY;
                S_WAIT_READY: // Wait for requester to accept the response
                    if (rsp_ready_i) state <= S_WAIT_DELAY;
                    else state <= S_WAIT_READY;
            endcase
        end
    end

    // Interface with memory DPI
    logic [TAG_WIDTH-1:0]  next_tag;
    logic [DATA_WIDTH-1:0] next_data;
    logic next_atomic;
    always_ff @(posedge clk_i) begin
        logic [DATA_WIDTH-1:0] readed_data;
        if(~rstn_i) begin
            next_tag <= 0;
            next_data <= 0;
            next_atomic <= 1'b0;
        end else begin
            if (state == S_MEM_INTERFACE) begin
                next_tag <= head.tag;
                case (head.cmd)
                    2'b00: begin // Read
                        memory_read(head.addr, readed_data);
                        next_atomic <= 1'b0;
                        next_data <= readed_data;
                    end
                    2'b01: begin // Write
                        memory_write(head.addr, head.be, head.data);
                        next_data <= 0;
                        next_atomic <= 1'b0;
                    end
                    2'b10: begin // Atomic
                        memory_amo(head.addr, head.size, head.atomic_op, head.data, readed_data);
                        next_atomic <= head.atomic_op != 4'b1101; //STEX are treated differently
                        next_data <= readed_data;
                    end
                    2'b11: begin // Used for tohost, put dummy data
                        next_data <= 0;
                        next_atomic <= 1'b0;
                    end
                endcase
            end
        end
    end

    // Pop from queue after interfacing with memory
    assign fifo_read = state == S_MEM_INTERFACE; 

    // *** Channel Outputs ***

    assign req_ready_o = !full;
    assign rsp_valid_o = state == S_WAIT_READY;
    assign rsp_id_o = next_tag;
    assign rsp_data_o = next_data;
    assign rsp_is_atomic_o = next_atomic;

endmodule

module l2_behav #(
    parameter LINE_SIZE = 512,
    parameter ADDR_SIZE = 32,
    parameter INST_DELAY = 20,
    parameter DATA_DELAY = 20

) (
    input logic                     clk_i,
    input logic                     rstn_i,

    // *** iCache Interface ***

    input logic  [25:0]             ic_addr_i,
    input logic                     ic_valid_i,
    output logic [LINE_SIZE-1:0]    ic_line_o, // TODO: Change it to 512 bits, modifying iCache FSM
    output logic                    ic_ready_o,
    output logic                    ic_valid_o,
    output logic [1:0]              ic_seq_num_o,

    // *** dCache Interface ***

    // Miss reads

    input addr_t                    dc_mr_addr_i,
    input logic                     dc_mr_valid_i,
    input logic                     dc_mr_ready_i,
    input logic [7:0]               dc_mr_tag_i,
    input logic [3:0]               dc_mr_word_size_i,
    output logic [LINE_SIZE-1:0]    dc_mr_data_o,
    output logic                    dc_mr_ready_o,
    output logic                    dc_mr_valid_o,
    output logic [7:0]              dc_mr_tag_o,
    output logic                    dc_mr_last_o,

    // Writeback

    output logic                 dc_wb_req_ready_o,
    input logic                  dc_wb_req_valid_i,
    input hpdcache_mem_addr_t    dc_wb_req_addr_i,
    input hpdcache_mem_len_t     dc_wb_req_len_i,
    input hpdcache_mem_size_t    dc_wb_req_size_i,
    input hpdcache_mem_id_t      dc_wb_req_id_i,
    output hpdcache_mem_id_t     dc_wb_req_base_id_o,

    output logic                 dc_wb_req_data_ready_o,
    input logic                  dc_wb_req_data_valid_i,
    input hpdcache_mem_data_t    dc_wb_req_data_i,
    input hpdcache_mem_be_t      dc_wb_req_be_i,
    input logic                  dc_wb_req_last_i,

    input logic                  dc_wb_resp_ready_i,
    output logic                 dc_wb_resp_valid_o,
    output hpdcache_mem_error_e  dc_wb_resp_error_o,
    output hpdcache_mem_id_t     dc_wb_resp_id_o,

    // Uncacheable writeback

    output logic                 dc_uc_wr_req_ready_o,
    input logic                  dc_uc_wr_req_valid_i,
    input hpdcache_mem_addr_t    dc_uc_wr_req_addr_i,
    input hpdcache_mem_len_t     dc_uc_wr_req_len_i,
    input hpdcache_mem_size_t    dc_uc_wr_req_size_i,
    input hpdcache_mem_id_t      dc_uc_wr_req_id_i,
    input hpdcache_mem_command_e dc_uc_wr_req_command_i,
    input hpdcache_mem_atomic_e  dc_uc_wr_req_atomic_i,
    output hpdcache_mem_id_t     dc_uc_wr_req_base_id_o,

    output logic                 dc_uc_wr_req_data_ready_o,
    input logic                  dc_uc_wr_req_data_valid_i,
    input hpdcache_mem_data_t    dc_uc_wr_req_data_i,
    input hpdcache_mem_be_t      dc_uc_wr_req_be_i,
    input logic                  dc_uc_wr_req_last_i,

    input logic                  dc_uc_wr_resp_ready_i,
    output logic                 dc_uc_wr_resp_valid_o,
    output logic                 dc_uc_wr_resp_is_atomic_o,
    output hpdcache_mem_error_e  dc_uc_wr_resp_error_o,
    output hpdcache_mem_id_t     dc_uc_wr_resp_id_o,

    // Uncacheable read

    output logic                 dc_uc_rd_req_ready_o,
    input logic                  dc_uc_rd_req_valid_i,
    input hpdcache_mem_addr_t    dc_uc_rd_req_addr_i,
    input hpdcache_mem_len_t     dc_uc_rd_req_len_i,
    input hpdcache_mem_size_t    dc_uc_rd_req_size_i,
    input hpdcache_mem_id_t      dc_uc_rd_req_id_i,
    input hpdcache_mem_command_e dc_uc_rd_req_command_i,
    input hpdcache_mem_atomic_e  dc_uc_rd_req_atomic_i,
    output hpdcache_mem_id_t     dc_uc_rd_req_base_id_o,

    output logic                   dc_uc_rd_valid_o,
    output hpdcache_mem_error_e    dc_uc_rd_error_o,
    output hpdcache_mem_id_t       dc_uc_rd_id_o,
    output hpdcache_mem_data_t     dc_uc_rd_data_o,
    output logic                   dc_uc_rd_last_o,
    input logic                    dc_uc_rd_ready_i
);

    logic [63:0] tohost_addr;

    // Memory DPI
    initial begin
        string path;
        if ($value$plusargs("load=%s", path)) begin
            memory_init(path);
            memory_symbol_addr("tohost", tohost_addr);
        end else begin
            $fatal(1, "No path provided for ELF to be loaded into the simulator's memory. Please provide one using +load=<path>");
        end
    end

    // *** iCache memory channel logic ***

    logic [$clog2(INST_DELAY)+1:0] ic_counter;
    logic [$clog2(INST_DELAY)+1:0] ic_next_counter;

    logic  [25:0] ic_addr_int;
    logic request_q;

    // ic_counter stuff
    assign ic_next_counter = (ic_counter > 0) ? ic_counter-1 : 0;
    assign ic_seq_num_o = 2'b11 - ic_counter[1:0];

    // Register holding the full 512 bits of the line
    logic [LINE_SIZE-1:0] ic_line;

    // ic_counter procedure
    always_ff @(posedge clk_i, negedge rstn_i) begin : proc_ic_counter
        if(~rstn_i) begin
            ic_counter <= 'h0;
            request_q <= 1'b0;
	        ic_valid_o <= 1'b0;
        end else if (ic_valid_i && !request_q) begin
            ic_counter <= INST_DELAY + 1;
	        ic_valid_o  <= 1'b0;
	        request_q <= 1'b1;
   	        ic_addr_int <= ic_addr_i;
        end else if (request_q && ic_counter > 0) begin
            ic_counter <= ic_next_counter;
	        ic_addr_int <= ic_addr_i;
   	        request_q <= 1'b1;
	        if (~|ic_next_counter && ~ic_valid_i) begin
                memory_read({ic_addr_int[25:0], 6'b0}, ic_line);
	            ic_valid_o <= 1'b1;
	        end else begin
	            ic_valid_o <= 1'b0;
	        end
        end else begin
        	ic_valid_o  <= 1'b0;
	        request_q <= 1'b0;
        end
    end 

    always_comb begin
        if (ic_valid_o) ic_line_o = ic_line;
        else            ic_line_o = 0      ;
    end

    // *** dCache miss-read channel ***

    mem_channel mr_channel (
        .clk_i,
        .rstn_i,

        .req_ready_o(dc_mr_ready_o),
        .req_valid_i(dc_mr_valid_i),
        .req_addr_i(dc_mr_addr_i),
        .req_size_i(dc_mr_word_size_i),
        .req_id_i(dc_mr_tag_i),
        .req_data_i(0),         // Read-only channel
        .req_be_i(0),           // Read-only channel
        .req_command_i(2'b00),  // Read-only channel
        .req_atomic_i(0),       // No atomics

        .rsp_valid_o(dc_mr_valid_o),
        .rsp_id_o(dc_mr_tag_o),
        .rsp_data_o(dc_mr_data_o),
        .rsp_is_atomic_o(), // No atomics
        .rsp_ready_i(dc_mr_ready_i)
    );

    assign dc_mr_last_o = dc_mr_valid_o;

    // *** dCache writeback channel ***

    mem_channel wb_channel (
        .clk_i,
        .rstn_i,

        .req_ready_o(dc_wb_req_ready_o),
        .req_valid_i(dc_wb_req_valid_i & dc_wb_req_data_valid_i),
        .req_addr_i(dc_wb_req_addr_i),
        .req_size_i(dc_wb_req_size_i),
        .req_id_i(dc_wb_req_id_i),
        .req_data_i(dc_wb_req_data_i),
        .req_be_i(dc_wb_req_be_i),
        .req_command_i(2'b01), // Write-only channel
        .req_atomic_i(0),      // No atomics

        .rsp_valid_o(dc_wb_resp_valid_o),
        .rsp_id_o(dc_wb_resp_id_o),
        .rsp_data_o(), // No data response
        .rsp_is_atomic_o(), // No atomics
        .rsp_ready_i(dc_wb_resp_ready_i)
    );

    assign dc_wb_req_data_ready_o = dc_wb_req_ready_o;

    assign dc_wb_resp_error_o = HPDCACHE_MEM_RESP_OK;

    // *** dCache uncacheable write channel ***

    logic is_tohost;

    logic uncached_write_valid, atomic_response, uncached_write_ready;
    logic [LINE_SIZE-1:0] atomic_data;

    mem_channel uc_write_channel (
        .clk_i,
        .rstn_i,

        .req_ready_o(dc_uc_wr_req_ready_o),
        .req_valid_i(dc_uc_wr_req_valid_i & dc_uc_wr_req_data_valid_i),
        .req_addr_i(dc_uc_wr_req_addr_i),
        .req_size_i(dc_uc_wr_req_size_i),
        .req_id_i(dc_uc_wr_req_id_i),
        .req_data_i(dc_uc_wr_req_data_i),
        .req_be_i(dc_uc_wr_req_be_i),
        .req_command_i(is_tohost ? 2'b11 : dc_uc_wr_req_command_i),
        .req_atomic_i(dc_uc_wr_req_atomic_i),

        .rsp_valid_o(uncached_write_valid),
        .rsp_id_o(dc_uc_wr_resp_id_o),
        .rsp_data_o(atomic_data),
        .rsp_is_atomic_o(atomic_response),
        .rsp_ready_i(uncached_write_ready)
    );

    assign dc_uc_wr_req_data_ready_o = dc_uc_wr_req_ready_o;

    // tohost logic for simulations

    assign is_tohost = dc_uc_wr_req_valid_i & dc_uc_wr_req_data_valid_i && dc_uc_wr_req_addr_i == tohost_addr;

    always_ff @(posedge clk_i, negedge rstn_i) begin
        logic [14:0] exit_code;
        if(~rstn_i) begin
        end else if (is_tohost) begin
            if (tohost(dc_uc_wr_req_data_i[63:0])) begin
                exit_code = dc_uc_wr_req_data_i[15:1];

                if (exit_code == 0) begin
                    $write("%c[1;32m", 27);
                    $write("Run finished correctly");
                    $write("%c[0m\n", 27);
                    $finish;
                end else begin
                    $write("%c[1;31m", 27);
                    $write("Simulation ended with error code %d", exit_code);
                    $write("%c[0m\n", 27);
                    `ifdef VERILATOR // Use $error because Verilator doesn't support exit codes in $finish
                        $error;
                    `else
                        $finish(exit_code);
                    `endif
                end
            end
        end
    end 

    // *** dCache uncacheable read channel ***

    logic uncached_read_valid, uncached_read_ready;
    logic [LINE_SIZE-1:0] uncached_read_data;
    logic [7:0] uncached_read_tag;

    mem_channel uc_read_channel (
        .clk_i,
        .rstn_i,

        .req_ready_o(dc_uc_rd_req_ready_o),
        .req_valid_i(dc_uc_rd_req_valid_i),
        .req_addr_i(dc_uc_rd_req_addr_i),
        .req_size_i(dc_uc_rd_req_size_i),
        .req_id_i(dc_uc_rd_req_tag_i),
        .req_data_i(dc_uc_rd_req_data_i),
        .req_be_i(dc_uc_rd_req_be_i),
        .req_command_i(dc_uc_rd_req_command_i),
        .req_atomic_i(dc_uc_rd_req_atomic_i),

        .rsp_valid_o(uncached_read_valid),
        .rsp_id_o(uncached_read_tag),
        .rsp_data_o(uncached_read_data),
        .rsp_is_atomic_o(), // No atomics
        .rsp_ready_i(uncached_read_ready)
    );

    // Mux for uncached read responses & atomic responses

    always_comb begin
        dc_uc_rd_data_o = 0;
        dc_uc_rd_id_o = 0;
        dc_uc_rd_last_o = 0;
        dc_uc_rd_valid_o = 0;
        uncached_read_ready = 0;

        dc_uc_wr_resp_valid_o = 0;
        dc_uc_wr_resp_is_atomic_o = 0;
        uncached_write_ready = 0;

        if (uncached_read_valid) begin
            dc_uc_rd_data_o = uncached_read_data;
            dc_uc_rd_id_o = uncached_read_tag;
            dc_uc_rd_last_o = 1'b1;
            dc_uc_rd_valid_o = 1'b1;
            uncached_read_ready = dc_uc_rd_ready_i;
        end
        
        if (uncached_write_valid) begin
            if (atomic_response & ~uncached_read_valid) begin // If there is an atomic response and the uncached read channel is available
                dc_uc_rd_data_o = atomic_data;
                dc_uc_rd_id_o = 0; // TODO: Not sure if this is correct
                dc_uc_rd_last_o = 1'b1;
                dc_uc_rd_valid_o = 1'b1;
                uncached_read_ready = 1'b0; // Do not read from the read memory channel

                dc_uc_wr_resp_valid_o = 1'b1;
                dc_uc_wr_resp_is_atomic_o = 1'b1;
                uncached_write_ready = dc_uc_wr_resp_ready_i;
            end else if (~atomic_response) begin // If it is just an uncached write ack
                dc_uc_wr_resp_valid_o = 1'b1;
                dc_uc_wr_resp_is_atomic_o = 1'b1;
                uncached_write_ready = dc_uc_wr_resp_ready_i;
            end
        end
    end

    assign dc_uc_wr_resp_error_o = HPDCACHE_MEM_RESP_OK;
    assign dc_uc_rd_resp_error_o = HPDCACHE_MEM_RESP_OK;

endmodule
