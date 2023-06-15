import drac_pkg::*, hpdcache_pkg::*;

typedef struct packed {
    addr_t        addr;
    logic [7:0]   tag;
    logic [3:0]   size;
    logic [511:0] data;
    logic [15:0]  be;
    logic [63:0]  timestamp;
    logic         wr_natomic;
    logic [3:0]   atomic_op;
} mem_op_t;

module mem_channel #(
    parameter DEPTH = 16
)(
    input logic clk_i,
    input logic rstn_i,
    input mem_op_t data_i,
    input logic write_i,
    input logic read_i,
    output mem_op_t data_o,
    output logic full_o,
    output logic empty_o
);

    mem_op_t memory [0:DEPTH-1];
    logic [$clog2(DEPTH)-1:0] write_ptr, read_ptr;
    logic [$clog2(DEPTH)-1:0] count;

    assign empty_o = count == 0;
    assign full_o  = count == DEPTH;
    assign data_o  = memory[read_ptr];

    always_ff @(posedge clk_i) begin
        if (write_i) memory[write_ptr] <= data_i;
    end

    always_ff @(posedge clk_i) begin
        if(~rstn_i) begin
            write_ptr <= 0;
            read_ptr <= 0;
            count <= 0;
        end else begin
            if (write_i) write_ptr <= write_ptr + 1'b1;
            if (read_i && ~empty_o) read_ptr <= read_ptr + 1'b1;
            case({write_i,read_i})
                2'b00, 2'b11: count <= count;
                2'b01: count <= count - 1'b1;
                2'b10: count <= count + 1'b1;
            endcase
        end
    end

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
    output logic [127:0]    ic_line_o, // TODO: Preguntar-li a la noelia quina sera la mida del bus de la NoC
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

    output logic                   dc_uc_rd_valid_o,
    output hpdcache_mem_error_e    dc_uc_rd_error_o,
    output hpdcache_mem_id_t       dc_uc_rd_id_o,
    output hpdcache_mem_data_t     dc_uc_rd_data_o,
    output logic                   dc_uc_rd_last_o,
    input logic                    dc_uc_rd_ready_i
);

    import "DPI-C" function void memory_read (input bit [31:0] addr, output bit [LINE_SIZE-1:0] data);
    import "DPI-C" function void memory_write (input bit [31:0] addr, input bit [15:0] byte_enable, input bit [LINE_SIZE-1:0] data);
    import "DPI-C" function void memory_amo (input bit [31:0] addr, input bit [3:0] size, input bit [3:0] amo_op, input bit [LINE_SIZE-1:0] data, output bit [LINE_SIZE-1:0] result);
    import "DPI-C" function void torture_dump_amo_write (input bit [31:0] addr, input bit [3:0] size, input bit [LINE_SIZE-1:0] data);

    // *** Time reference ***

    logic [63:0] cycles;

    always_ff @(posedge clk_i) begin
        if(~rstn_i) begin
            cycles <= 0;
        end else begin
            cycles <= cycles + 1;
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
            ic_counter <= INST_DELAY + 4;
	        ic_valid_o  <= 1'b0;
	        request_q <= 1'b1;
   	        ic_addr_int <= ic_addr_i;
        end else if (request_q && ic_counter > 0) begin
            ic_counter <= ic_next_counter;
	        ic_addr_int <= ic_addr_i;
   	        request_q <= 1'b1;
	        if ((ic_next_counter < 4) && (!ic_valid_i)) begin
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
        if (ic_valid_o) begin
            ic_line_o = ic_line[{2'b11 - ic_counter[1:0], 7'b0} +: 128];
        end else begin
            ic_line_o = 0;
        end
    end

    // *** dCache miss-read channel ***

    mem_op_t mr_ch_write_data;
    logic mr_ch_write;
    logic mr_ch_read;
    mem_op_t mr_ch_read_data;
    logic mr_ch_full;
    logic mr_ch_empty;

    mem_channel mr_channel (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .data_i(mr_ch_write_data),
        .write_i(mr_ch_write),
        .read_i(mr_ch_read),
        .data_o(mr_ch_read_data),
        .full_o(mr_ch_full),
        .empty_o(mr_ch_empty)
    );
    
    assign dc_mr_ready_o = ~mr_ch_full;

    assign mr_ch_write = dc_mr_valid_i & dc_mr_ready_o;

    always_comb begin
        mr_ch_write_data.addr      = dc_mr_addr_i;
        mr_ch_write_data.tag       = dc_mr_tag_i;
        mr_ch_write_data.size      = dc_mr_word_size_i;
        mr_ch_write_data.timestamp = cycles;
    end

    assign mr_ch_read = !mr_ch_empty && (cycles >= (mr_ch_read_data.timestamp + DATA_DELAY)) && dc_mr_ready_i;

    always_ff @(posedge clk_i) begin
        if (mr_ch_read) begin
            logic [LINE_SIZE-1:0] readed_contents;
            memory_read(mr_ch_read_data.addr, readed_contents);

            dc_mr_data_o  <= readed_contents;
            dc_mr_valid_o <= 1'b1;
            dc_mr_tag_o   <= mr_ch_read_data.tag;
            dc_mr_last_o  <= 1'b1;
        end else begin
            dc_mr_data_o  <= 0;
            dc_mr_valid_o <= 1'b0;
            dc_mr_tag_o   <= 0;
            dc_mr_last_o  <= 1'b0;
        end
    end

    // *** dCache writeback channel ***

    mem_op_t wb_ch_write_data;
    logic wb_ch_write;
    logic wb_ch_read;
    mem_op_t wb_ch_read_data;
    logic wb_ch_full;
    logic wb_ch_empty;

    mem_channel wb_channel (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .data_i(wb_ch_write_data),
        .write_i(wb_ch_write),
        .read_i(wb_ch_read),
        .data_o(wb_ch_read_data),
        .full_o(wb_ch_full),
        .empty_o(wb_ch_empty)
    );
    
    assign dc_wb_req_ready_o = ~wb_ch_full;
    assign dc_wb_req_data_ready_o = ~wb_ch_full;

    assign wb_ch_write = dc_wb_req_valid_i & dc_wb_req_data_valid_i & ~wb_ch_full;

    always_comb begin
        wb_ch_write_data.addr      = dc_wb_req_addr_i;
        wb_ch_write_data.tag       = dc_wb_req_id_i;
        wb_ch_write_data.size      = dc_wb_req_size_i;
        wb_ch_write_data.data      = dc_wb_req_data_i;
        wb_ch_write_data.be        = dc_wb_req_be_i;
        wb_ch_write_data.timestamp = cycles;
    end

    assign wb_ch_read = !wb_ch_empty && (cycles >= (wb_ch_read_data.timestamp + DATA_DELAY)) && dc_wb_resp_ready_i;

    always_ff @(posedge clk_i) begin
        if(wb_ch_read) begin
            memory_write(wb_ch_read_data.addr, wb_ch_read_data.be, wb_ch_read_data.data);
            dc_wb_resp_valid_o <= 1'b1;
            dc_wb_resp_id_o <= wb_ch_read_data.tag;
        end else begin
            dc_wb_resp_valid_o <= 1'b0;
            dc_wb_resp_id_o <= 0;
        end
    end

    assign dc_wb_resp_error_o = HPDCACHE_MEM_RESP_OK;


    // *** dCache uncacheable write channel ***

    mem_op_t uc_wr_ch_write_data;
    logic uc_wr_ch_write;
    logic uc_wr_ch_read;
    mem_op_t uc_wr_ch_read_data;
    logic uc_wr_ch_full;
    logic uc_wr_ch_empty;

    mem_channel uc_wr_channel (
        .clk_i(clk_i),
        .rstn_i(rstn_i),
        .data_i(uc_wr_ch_write_data),
        .write_i(uc_wr_ch_write),
        .read_i(uc_wr_ch_read),
        .data_o(uc_wr_ch_read_data),
        .full_o(uc_wr_ch_full),
        .empty_o(uc_wr_ch_empty)
    );
    
    assign dc_uc_wr_req_ready_o = ~uc_wr_ch_full;
    assign dc_uc_wr_req_data_ready_o = ~uc_wr_ch_full;

    assign uc_wr_ch_write = dc_uc_wr_req_valid_i & dc_uc_wr_req_data_valid_i & ~uc_wr_ch_full;

    always_comb begin
        uc_wr_ch_write_data.addr       = dc_uc_wr_req_addr_i;
        uc_wr_ch_write_data.tag        = dc_uc_wr_req_id_i;
        uc_wr_ch_write_data.size       = dc_uc_wr_req_size_i;
        uc_wr_ch_write_data.data       = dc_uc_wr_req_data_i;
        uc_wr_ch_write_data.be         = dc_uc_wr_req_be_i;
        uc_wr_ch_write_data.timestamp  = cycles;
        uc_wr_ch_write_data.wr_natomic = dc_uc_wr_req_command_i == HPDCACHE_MEM_WRITE;
        uc_wr_ch_write_data.atomic_op  = dc_uc_wr_req_atomic_i;
    end


    function void amo_write(input bit [31:0] addr, input bit [15:0] byte_enable, input bit [LINE_SIZE-1:0] data);
        memory_write(addr, byte_enable, data);
        //torture_dump_amo_write(addr, size, data); TODO!!!!
    endfunction

    assign uc_wr_ch_read = !uc_wr_ch_empty && (cycles >= (uc_wr_ch_read_data.timestamp + DATA_DELAY)) && dc_uc_wr_resp_ready_i;

    always_ff @(posedge clk_i) begin
        if(uc_wr_ch_read) begin
            if (uc_wr_ch_read_data.wr_natomic) begin
                memory_write(uc_wr_ch_read_data.addr, uc_wr_ch_read_data.be, uc_wr_ch_read_data.data);
                dc_uc_rd_valid_o <= 1'b0;
                dc_uc_rd_data_o <= 0;
                dc_uc_rd_last_o <= 1'b0;
            end else begin
                logic [LINE_SIZE-1:0] readed_contents;
                memory_amo(uc_wr_ch_read_data.addr, uc_wr_ch_read_data.size, uc_wr_ch_read_data.atomic_op, uc_wr_ch_read_data.data, readed_contents);
                dc_uc_rd_valid_o <= 1'b1;
                dc_uc_rd_data_o <= readed_contents;
                dc_uc_rd_last_o <= 1'b1;
            end
            dc_uc_wr_resp_valid_o <= 1'b1;
            dc_uc_wr_resp_id_o <= uc_wr_ch_read_data.tag;
            dc_uc_wr_resp_is_atomic_o <= ~uc_wr_ch_read_data.wr_natomic;
        end else begin
            dc_uc_wr_resp_valid_o <= 1'b0;
            dc_uc_wr_resp_id_o <= 0;
            dc_uc_wr_resp_is_atomic_o <= 1'b0;

            dc_uc_rd_valid_o <= 1'b0;
            dc_uc_rd_data_o <= 0;
            dc_uc_rd_last_o <= 1'b0;
        end
    end

    assign dc_uc_wr_resp_error_o = HPDCACHE_MEM_RESP_OK;

endmodule
