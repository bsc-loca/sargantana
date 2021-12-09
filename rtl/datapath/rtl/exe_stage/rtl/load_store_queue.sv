/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : load_store_queue.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author      | Description
 *  0.1        | Victor.SP   |
 *  0.2        | Max Doblas  | Adding an Store Buffer  
 * -----------------------------------------------
 */

import drac_pkg::*;


typedef logic [$clog2(LSQ_NUM_ENTRIES)-1:0] lsq_entry_pointer;

module load_store_queue(
    input logic                clk_i,            // Clock Singal
    input logic                rstn_i,           // Negated Reset Signal

    input rr_exe_mem_instr_t   instruction_i,    // All instruction input signals
     
    input logic                flush_i,          // Flush all entries
    input logic                read_next_i,      // Read next instruction of the ciruclar buffer
    input logic                reset_next_i,     // Reset next instruction to the exec pointer
    input logic                advance_head_i,   // Advance head pointer one position
    input logic                rob_store_ack_i,
    input gl_index_t           rob_store_gl_idx_i,  // Signal from commit enables writes.
    output logic               blocked_store_o,

    output rr_exe_mem_instr_t  next_instr_exe_o, // Next Instruction to be executed 
       
    output logic               full_o,           // Lsq is full
    output logic               empty_o,          // Lsq is empty
    
    output logic               pmu_load_after_store_o  // Load blocked by ongoing store
);

// store buff signals
logic st_buff_full;
logic st_buff_empty;
logic st_buff_collision;
logic sb_write_enable;
rr_exe_mem_instr_t st_buff_inst_out;
logic is_next_store;
logic is_next_load;


store_buffer store_buffer_inst(
    .clk_i(clk_i),  
    .rstn_i(rstn_i),
    .write_enable_i(sb_write_enable),
    .instruction_i(control_table[head]),
    .flush_i(flush_i),
    .advance_head_i(read_enable_sb),
    .load_addr_i(control_table[head].data_rs1),
    .load_size_i(control_table[head].instr.mem_size),
    .finish_instr_o(st_buff_inst_out),
    .empty_o(st_buff_empty),
    .full_o(st_buff_full),
    .collision_o(st_buff_collision)
);

// Points to the next available entry
lsq_entry_pointer tail;

// Points to the next executable entry
lsq_entry_pointer next;

// Points to the oldest executed entry
lsq_entry_pointer head;

//Num must be 1 bit bigger than head an tail
logic [$clog2(LSQ_NUM_ENTRIES):0] num;
logic [$clog2(LSQ_NUM_ENTRIES):0] num_to_exe;
logic [$clog2(LSQ_NUM_ENTRIES):0] num_on_fly;
logic [$clog2(LSQ_NUM_ENTRIES):0] num_to_recover;

// Internal Control Signals
logic write_enable;
logic read_enable;
logic read_enable_lsq;
logic read_enable_sb;
logic advance_head_enable;

// User can write to the tail of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.instr.valid & (num_to_exe < LSQ_NUM_ENTRIES);

// User can read the next executable instruction of the buffer if there is data
// stored in the queue
assign read_enable = read_next_i & !empty_o & (~reset_next_i);

// User can advance the head of the buffer if there is data stored in the queue
assign advance_head_enable = advance_head_i & ((num_on_fly > 0) | read_enable);

// FIFO Memory structure
rr_exe_mem_instr_t control_table[0:LSQ_NUM_ENTRIES-1];
// recover table
rr_exe_mem_instr_t recover_table[0:1];
logic recover_head;
logic recover_tail;

always_ff @(posedge clk_i)
begin
    // Write tail
    if (write_enable) begin
        control_table[tail] <= instruction_i;
    end
end

always_ff @(posedge clk_i)
begin
    if (read_enable) begin
        recover_table[recover_tail] <= next_instr_exe_o;
    end
end

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if(~rstn_i) begin
        head <= 3'h0;
        next <= 3'h0;
        tail <= 3'b0;
        num  <= 4'b0;
        num_to_exe   <= 4'b0;
        num_on_fly   <= 4'b0;
        num_to_recover  <= 4'b0;
        recover_head <= 1'b0;
        recover_tail <= 1'b0;
    end
    else if (flush_i) begin
        head <= 3'h0;
        next <= 3'h0;
        tail <= 3'b0;
        num  <= 4'b0;
        num_to_exe   <= 4'b0;
        num_on_fly   <= 4'b0;
        num_to_recover  <= 4'b0;
        recover_head <= 1'b0;
        recover_tail <= 1'b0;
    end
    else if (reset_next_i) begin
        head <= head + {2'b00, read_enable_lsq};
        tail <= tail + {2'b00, write_enable};
        num_to_exe <= num_to_exe + {3'b0, write_enable} - {3'b0, read_enable_lsq};
        num_on_fly <= 4'b0;
        num_to_recover  <= num_on_fly;
        recover_head <= recover_head;
        recover_tail <= recover_head;
    end
    else begin
        head <= head + {2'b00, read_enable_lsq};
        tail <= tail + {2'b00, write_enable};
        num_to_exe      <= num_to_exe + {3'b0, write_enable} - {3'b0, read_enable_lsq};
        num_on_fly      <= num_on_fly + {2'b00, read_enable} - {3'b0, advance_head_enable};
        num_to_recover  <= num_to_recover > 0 ? num_to_recover - {3'b0, read_enable} : 4'b0;
        recover_head <= recover_head + advance_head_enable;
        recover_tail <= recover_tail + read_enable;
    end
end

always_comb begin
    read_enable_lsq = 1'b0;
    read_enable_sb = 1'b0;
    sb_write_enable = 1'b0;
    if (read_enable && num_to_recover > 0) begin

    end else if (read_enable && rob_store_ack_i && !st_buff_empty && st_buff_inst_out.gl_index == rob_store_gl_idx_i) begin
        read_enable_sb = 1'b1;
    end else if (read_enable && rob_store_ack_i && is_next_store && control_table[head].gl_index == rob_store_gl_idx_i) begin
        read_enable_lsq = 1'b1;
    end else if (read_enable && is_next_load && !st_buff_collision) begin
        read_enable_lsq = 1'b1;
    end else if ((!read_enable || !rob_store_ack_i || control_table[head].gl_index != rob_store_gl_idx_i) && is_next_store && !st_buff_full) begin
        sb_write_enable = 1'b1;
        read_enable_lsq = 1'b1;
    end
end 

always_comb begin
    next_instr_exe_o = 'h0;
    if (read_enable && num_to_recover > 0) begin
        next_instr_exe_o = recover_table[recover_tail];
    end else if (read_enable && rob_store_ack_i && !st_buff_empty && st_buff_inst_out.gl_index == rob_store_gl_idx_i) begin
        next_instr_exe_o = st_buff_inst_out;
    end else if (read_enable && rob_store_ack_i && is_next_store && control_table[head].gl_index == rob_store_gl_idx_i) begin
        next_instr_exe_o = control_table[head];
    end else if (read_enable && is_next_load && !st_buff_collision) begin
        next_instr_exe_o = control_table[head];
    end
end

always_comb begin
    blocked_store_o = 1'b1;
    if (num_to_recover != '0) begin
        blocked_store_o = 1'b0;
    end else if (!st_buff_empty && rob_store_ack_i && (st_buff_inst_out.gl_index == rob_store_gl_idx_i)) begin
        blocked_store_o = 1'b0;
    end else if (st_buff_empty && is_next_store && rob_store_ack_i && (control_table[head].gl_index == rob_store_gl_idx_i)) begin
        blocked_store_o = 1'b0;
    end else if (is_next_load && !st_buff_collision) begin
        blocked_store_o = 1'b0;
    end
end

assign empty_o = (num_to_exe == '0 && st_buff_empty && num_to_recover == '0);
assign full_o  = ((num_to_exe == LSQ_NUM_ENTRIES) | flush_i | ~rstn_i);

assign is_next_load = num_to_exe > '0 && (control_table[head].instr.mem_type == LOAD);

assign is_next_store = num_to_exe > '0 && (control_table[head].instr.mem_type == STORE     || 
                                        control_table[head].instr.mem_type == AMO);

assign pmu_load_after_store_o = st_buff_collision;

endmodule

