/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : store_buffer.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Max Doblas Font
 * Email(s)       : max.doblas@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author      | Description
 *  0.1        | Max Doblas  | 
 * -----------------------------------------------
 */

module store_buffer
    import drac_pkg::*;
(
    input logic                 clk_i,            // Clock Singal
    input logic                 rstn_i,           // Negated Reset Signal
    input logic                 write_enable_i,

    input rr_exe_mem_instr_t    instruction_i,    // All instruction input signals

    input logic                 flush_i,          // Flush all entries
    input logic                 advance_head_i,   // Advance head pointer one position

    input bus64_t               load_addr_i,      // Addr of a new load  
    input logic [3:0]           load_size_i,

    output rr_exe_mem_instr_t   finish_instr_o,   // Next Instruction to Write Back
    
    output logic                empty_o,            // st buf is empty
    output logic                full_o,           // st buf is full

    output logic                collision_o       // the new load collides with a store
);

typedef logic [$clog2(ST_BUF_NUM_ENTRIES)-1:0] st_buf_entry_pointer;

function [$clog2(ST_BUF_NUM_ENTRIES)-1:0] trunc_sum_st_buf(input [$clog2(ST_BUF_NUM_ENTRIES):0] val_in);
  trunc_sum_st_buf = val_in[$clog2(ST_BUF_NUM_ENTRIES)-1:0];
endfunction

function [$clog2(ST_BUF_NUM_ENTRIES):0] trunc_sum_st_buf_plus(input [$clog2(ST_BUF_NUM_ENTRIES)+1:0] val_in);
  trunc_sum_st_buf_plus = val_in[$clog2(ST_BUF_NUM_ENTRIES):0];
endfunction

// Points to the next available entry
st_buf_entry_pointer tail;

// Points to the oldest executed entry
st_buf_entry_pointer head;

//Num must be 1 bit bigger than head an tail
logic [$clog2(ST_BUF_NUM_ENTRIES):0] num;

// Internal Control Signals
logic write_enable;
logic read_enable;
logic advance_head_enable;

// Collision detection signals
logic collision;

// User can write to the tail of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.instr.valid & (num < ST_BUF_NUM_ENTRIES) & write_enable_i;

// User can read the next executable instruction of the buffer if there is data
// stored in the queue
assign read_enable = (num > 0);

// User can advance the head of the buffer if there is data stored in the queue
assign advance_head_enable = advance_head_i & (num > 0);


// FIFO Memory structure
rr_exe_mem_instr_t instruction_table [ST_BUF_NUM_ENTRIES-1:0];
logic [ST_BUF_NUM_ENTRIES-1:0] valid_table;

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if (~rstn_i) begin
        for (integer j = 0; j < ST_BUF_NUM_ENTRIES; j++) begin
            valid_table[j] <= 1'b0;
            instruction_table[j] <= '0;
        end
    end
    else if (flush_i) begin
        for (integer j = 0; j < ST_BUF_NUM_ENTRIES; j++) begin
            valid_table[j] <= 1'b0;
        end
    end else begin
        if (write_enable) begin
            instruction_table[tail]  <= instruction_i;
            valid_table[tail]        <= 1'b1;
        end

        if (advance_head_enable) begin
            valid_table[head] <= 1'b0;
        end
    end
end

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if(~rstn_i) begin
        head <= 3'h0;
        tail <= 3'b0;
        num  <= 4'b0;
    end
    else if (flush_i) begin
        head <= 3'h0;
        tail <= 3'b0;
        num  <= 4'b0;
    end
    else begin
        head <= trunc_sum_st_buf(head + {2'b00, advance_head_enable});
        tail <= trunc_sum_st_buf(tail + {2'b00, write_enable});
        num  <= trunc_sum_st_buf_plus(num  + {3'b0, write_enable} - {3'b0, advance_head_enable});
    end
end

always_comb begin : collision_detector
    collision = 1'b0;
    for (integer j = 0; j < ST_BUF_NUM_ENTRIES; j++) begin
        if (valid_table[j]) begin
            if ((load_size_i == 4'b1010) || (instruction_table[j].instr.mem_size == 4'b1010)) begin
                collision |= instruction_table[j].data_rs1[11:6] == load_addr_i[11:6];
            end else if ((load_size_i == 4'b1001) || (instruction_table[j].instr.mem_size == 4'b1001)) begin
                collision |= instruction_table[j].data_rs1[11:5] == load_addr_i[11:5];
            end else if ((load_size_i == 4'b1000) || (instruction_table[j].instr.mem_size == 4'b1000)) begin
                collision |= instruction_table[j].data_rs1[11:4] == load_addr_i[11:4];
            end else if ((load_size_i == 4'b0011) || (instruction_table[j].instr.mem_size == 4'b0011)) begin
                collision |= instruction_table[j].data_rs1[11:3] == load_addr_i[11:3];
            end else if ((load_size_i[1:0] == 2'b10) || (instruction_table[j].instr.mem_size[1:0] == 2'b10)) begin
                collision |= instruction_table[j].data_rs1[11:2] == load_addr_i[11:2];
            end else if ((load_size_i[1:0] == 2'b01) || (instruction_table[j].instr.mem_size[1:0] == 2'b01)) begin
                collision |= instruction_table[j].data_rs1[11:1] == load_addr_i[11:1];
            end else if ((load_size_i[1:0] == 2'b00) || (instruction_table[j].instr.mem_size[1:0] == 2'b00)) begin
                collision |= instruction_table[j].data_rs1[11:0] == load_addr_i[11:0];
            end
        end
    end
end

assign collision_o = collision;

assign finish_instr_o = ((num > 0)) ? instruction_table[head] : 'h0;

assign empty_o  = num == '0;
assign full_o  = ((num >= (ST_BUF_NUM_ENTRIES - 1)) | flush_i | ~rstn_i);

endmodule

