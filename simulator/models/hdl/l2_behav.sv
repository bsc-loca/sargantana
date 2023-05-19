import drac_pkg::*;

module l2_behav #(
    parameter LINE_SIZE = 128,
    parameter ADDR_SIZE = 32,
    parameter INST_DELAY = 20,
    parameter DATA_DELAY = 2

) (
    input logic                     clk_i,
    input logic                     rstn_i,

    // *** iCache Interface ***

    input logic  [25:0]             ic_addr_i,
    input logic                     ic_valid_i,
    output logic [LINE_SIZE-1:0]    ic_line_o,
    output logic                    ic_ready_o,
    output logic                    ic_valid_o,
    output logic [1:0]              ic_seq_num_o,

    // *** dCache Interface ***

    input addr_t                    dc_addr_i,
    input logic                     dc_valid_i,
    input logic [7:0]               dc_tag_i,
    input logic [4:0]               dc_cmd_i,
    input bus_simd_t                dc_wr_data_i,
    input logic [3:0]               dc_word_size_i,
    output logic [LINE_SIZE-1:0]    dc_line_o,
    output logic                    dc_ready_o,
    output logic                    dc_valid_o,
    output logic [7:0]              dc_tag_o
);

    import "DPI-C" function bit memory_read (input bit [31:0] addr, output bit [LINE_SIZE-1:0] data);
    import "DPI-C" function bit memory_write (input bit [31:0] addr, input bit [3:0] size, input bit [LINE_SIZE-1:0] data);

    // *** iCache memory channel logic ***

    logic [$clog2(INST_DELAY)+1:0] ic_counter;
    logic [$clog2(INST_DELAY)+1:0] ic_next_counter;

    logic  [25:0] ic_addr_int;
    logic request_q;

    // ic_counter stuff
    assign ic_next_counter = (ic_counter > 0) ? ic_counter-1 : 0;
    assign ic_seq_num_o = 2'b11 - ic_counter[1:0];

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
            memory_read({ic_addr_int[25:0], 2'b11 - ic_counter[1:0], 4'h0}, ic_line_o);
        end else begin
            ic_line_o = 0;
        end
    end

    // *** dCache memory channel logic ***

    typedef enum {
        IDLE, STORE_WRITE, WAIT
    } perfect_memory_state_t;

    logic [$clog2(DATA_DELAY):0] counter;
    logic [$clog2(DATA_DELAY):0] next_counter;

    logic  [ADDR_SIZE-1:0]    addr_int;
    assign addr_int = 'h100+({4'b0,dc_addr_i[31:4]}-'h010);

    logic [LINE_SIZE-1:0] line_d, line_q;
    logic [LINE_SIZE-1:0] mem_out;
    logic [ADDR_SIZE-1:0] addr_d, addr_q;
    logic [ADDR_SIZE-1:0] addr_int_d, addr_int_q;
    logic [3:0] word_size_d, word_size_q;
    logic valid_d, valid_q;
    logic [7:0] tag_d, tag_q;
    logic [4:0] cmd_d, cmd_q;

    logic [7:0]  mem_byte;
    logic [15:0] mem_half;
    logic [31:0] mem_word;
    logic [63:0] mem_dword;

    assign mem_byte  = mem_out[{dc_addr_i[3:0], 3'b0} +: 8];
    assign mem_half  = mem_out[{dc_addr_i[3:1], 4'b0} +: 16];
    assign mem_word  = mem_out[{dc_addr_i[3:2], 5'b0} +: 32];
    assign mem_dword = mem_out[{dc_addr_i[3], 6'b0}   +: 64];

    logic wr_ena;

    assign wr_ena = dc_cmd_i != 5'b00000 && dc_cmd_i != 5'b00110;

    logic [63:0] amo_mem_val, amo_core_val;
    addr_t lr_addr_d, lr_addr_q;
    logic reserved_d, reserved_q;

    assign amo_mem_val = word_size_q == 3 ? mem_dword : {{32{mem_word[31]}}, mem_word};
    assign amo_core_val = word_size_q == 3 ? dc_wr_data_i[63:0] : {{32{dc_wr_data_i[31]}}, dc_wr_data_i[31:0]};

    perfect_memory_state_t state, next_state;

    assign dc_ready_o = (counter == 0);
    assign dc_line_o = line_q;
    assign dc_tag_o = tag_q;
    assign dc_valid_o = (counter == 1) ? valid_q : 1'b0;

    always_ff @(posedge clk_i, negedge rstn_i) begin : proc_dc_counter
        if(~rstn_i) begin
            counter     <= 0;
            line_q      <= 0;
            valid_q     <= 0;
            tag_q       <= 0;
            addr_q      <= 0;
            addr_int_q  <= 0;
            word_size_q <= 0;
            state       <= IDLE;
            cmd_q       <= 0;
            reserved_q  <= 0;
            lr_addr_q   <= 0;
        end else begin
            counter     <= next_counter;
            line_q      <= line_d;
            valid_q     <= valid_d;
            tag_q       <= tag_d;
            addr_q      <= addr_d;
            addr_int_q  <= addr_int_d;
            word_size_q <= word_size_d;
            state       <= next_state;
            cmd_q       <= cmd_d;
            reserved_q  <= reserved_d;
            lr_addr_q   <= lr_addr_d;
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
                if (dc_ready_o && dc_valid_i) begin
                    next_counter = DATA_DELAY;
                    valid_d      = 1'b1;
                    tag_d        = dc_tag_i;
                    addr_d       = dc_addr_i;
                    addr_int_d   = addr_int;
                    word_size_d  = dc_word_size_i;
                    next_state   = wr_ena ? STORE_WRITE : WAIT;
                    cmd_d = dc_cmd_i;
                end else begin
                    next_counter = 0;
                    valid_d      = 0'b0;
                    tag_d        = 0'b0;
                    addr_d       = 0;
                    addr_int_d   = 0;
                    word_size_d  = 0;
                    next_state   = IDLE;
                    cmd_d = 0;
                end

                //Hold line output
                if (dc_ready_o && dc_valid_i) begin
                    if (dc_cmd_i == 5'b00111) begin // Store Conditional
                        line_d = reserved_q == 1'b1 && dc_addr_i == lr_addr_q ? 1'b0 : 1'b1;
                        reserved_d = 1'b0;
                        lr_addr_d = 0;
                    end else begin
                        memory_read({dc_addr_i[31:4], 4'b0}, mem_out);
                        case (dc_word_size_i)
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
                        if (dc_cmd_i == 5'b00110) begin // Load reserve
                            reserved_d = 1'b1;
                            lr_addr_d = dc_addr_i;
                        end
                    end
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
            case(cmd_q)
                5'b00111: if (line_q == 0) memory_write(addr_q, word_size_q, amo_core_val); // sc
                5'b00100: memory_write(addr_q, word_size_q, amo_core_val); // amoswap
                5'b01000: memory_write(addr_q, word_size_q, amo_mem_val + amo_core_val); // amoadd
                5'b01001: memory_write(addr_q, word_size_q, amo_mem_val ^ amo_core_val); // amoxor
                5'b01011: memory_write(addr_q, word_size_q, amo_mem_val & amo_core_val); // amoand
                5'b01010: memory_write(addr_q, word_size_q, amo_mem_val | amo_core_val); // amoor
                5'b01100: memory_write(addr_q, word_size_q, $signed(amo_mem_val) < $signed(amo_core_val) ? amo_mem_val : amo_core_val); // amomin
                5'b01101: memory_write(addr_q, word_size_q, $signed(amo_mem_val) > $signed(amo_core_val) ? amo_mem_val : amo_core_val); // amomax
                5'b01110: memory_write(addr_q, word_size_q, amo_mem_val < amo_core_val ? amo_mem_val : amo_core_val); // amominu
                5'b01111: memory_write(addr_q, word_size_q, amo_mem_val > amo_core_val ? amo_mem_val : amo_core_val); // amomaxu
                5'b00001: memory_write(addr_q, word_size_q, dc_wr_data_i);
                default: ;
            endcase
        end
    end
endmodule
