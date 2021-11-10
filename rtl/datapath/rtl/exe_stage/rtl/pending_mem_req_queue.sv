/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : pending_mem_req_queue.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author      | Description
 *  0.1        | Victor.SP  |  
 * -----------------------------------------------
 */

import drac_pkg::*;


typedef logic [$clog2(PMRQ_NUM_ENTRIES)-1:0] pmrq_entry_pointer;

module pending_mem_req_queue(
    input logic                 clk_i,                  // Clock Singal
    input logic                 rstn_i,                 // Negated Reset Signal

    input rr_exe_mem_instr_t    instruction_i,          // All instruction input signals
    input reg_t                 tag_i,                  // Tag of the incoming instruction
    input logic                 unaligned_inst_i,       // Unaligned instruction
    input logic                 unaligned_res_valid_i,  // Unaligned result incoming
    input bus_simd_t            unaligned_res_data_i,   // Unaligned result data

    input logic                 replay_valid_i,         // A replay is being executed
    input logic                 response_valid_i,       // A response is being executed
    input reg_t                 tag_next_i,             // Instruction that finishes
    input bus_simd_t            replay_data_i,          // Replay asociated data
    
    input logic                 flush_i,                // Flush all entries
    input logic                 advance_head_i,         // Advance head pointer one position
    input logic                 mv_back_tail_i,         // Move Back tail pointer one position

    output rr_exe_mem_instr_t   finish_instr_o,         // Next Instruction to Write Back
    output logic                unalign_instr_o,        // Is unaligned instruction
    output bus_simd_t           unalign_result_o,       // Unaligned output part 2
       
    output logic                full_o                  // pmrq is full
);

// Points to the next available entry
pmrq_entry_pointer tail;

// Points to the oldest executed entry
pmrq_entry_pointer head;

//Num must be 1 bit bigger than head an tail
logic [$clog2(PMRQ_NUM_ENTRIES):0] num;

// Internal Control Signals
logic write_enable;
logic read_enable;
logic advance_head_enable;

// User can write to the tail of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.instr.valid & (num < PMRQ_NUM_ENTRIES) & (!mv_back_tail_i);

// User can read the next executable instruction of the buffer if there is data
// stored in the queue
assign read_enable = (num > 0);

// User can advance the head of the buffer if there is data stored in the queue
assign advance_head_enable = advance_head_i & (num > 0);

assign mv_back_head_enable = mv_back_tail_i & (!instruction_i.instr.valid) & (num > 0);


// FIFO Memory structure, stores instructions
rr_exe_mem_instr_t instruction_table    [0:PMRQ_NUM_ENTRIES-1];
// Tag Storage
reg_t          tag_table                [0:PMRQ_NUM_ENTRIES-1];
// Instruction already finished
logic          finish_bit_table         [0:PMRQ_NUM_ENTRIES-1];
// Instruction is unaligned vector
logic          unaligned_bit_table      [0:PMRQ_NUM_ENTRIES-1];
// Unaligned vector access part 2
bus_simd_t     unaligned_result_table   [0:PMRQ_NUM_ENTRIES-1];
// Unaligned vector access must wait for other part
logic          unaligned_nowait_table   [0:PMRQ_NUM_ENTRIES-1];

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if (~rstn_i) begin
        for (integer j = 0; j < PFPQ_NUM_ENTRIES; j++) begin
            finish_bit_table[j] <= 1'b0;
	    unaligned_bit_table[j] <= 1'b0;
	    unaligned_nowait_table[j] <= 1'b0;
	end
    end else begin
	if (write_enable) begin     // Write tail
            instruction_table[tail]      <= instruction_i;
            tag_table[tail]              <= tag_i;

            unaligned_bit_table[tail]    <= unaligned_inst_i;
            unaligned_nowait_table[tail] <= 1'b0;
            if (unaligned_res_valid_i) begin
               instruction_table[tail].data_rs2 <= unaligned_res_data_i; 
               finish_bit_table[tail]           <= 1'b1;
            end else begin
               instruction_table[tail].data_rs2 <= 'h0;
               finish_bit_table[tail]           <= 1'b0;
            end
	end

        // Table initial state
        for (integer j = 0; j < PMRQ_NUM_ENTRIES; j++) begin
            if (replay_valid_i && (tag_table[j] == tag_next_i)) begin
                finish_bit_table[j] <= 1'b1;
                instruction_table[j].data_rs2 <= replay_data_i;
            end
            if (replay_valid_i && ((tag_table[j] + 1'b1) == tag_next_i)) begin
               unaligned_result_table[j] <= replay_data_i;
               unaligned_nowait_table[j] <= 1'b1;
            end
            if (response_valid_i && unaligned_bit_table[j] && 
               (tag_table[j] == tag_next_i)) begin
               finish_bit_table[j] <= 1'b1;
               instruction_table[j].data_rs2 <= replay_data_i;
            end
            if (response_valid_i && unaligned_bit_table[j] &&
               ((tag_table[j] + 1'b1) == tag_next_i) && 
                (!write_enable || j != tail)) begin
               unaligned_result_table[j] <= replay_data_i;
               unaligned_nowait_table[j] <= 1'b1;
            end
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
        head <= head + {2'b00, advance_head_enable};
        tail <= tail + {2'b00, write_enable} - {2'b0, mv_back_head_enable};
        num  <= num  + {3'b0, write_enable} - {3'b0, advance_head_enable} 
                - {3'b0, mv_back_head_enable};
    end
end

assign finish_instr_o = ((num > 0) & finish_bit_table[head] &
                         (!unaligned_bit_table[head] | unaligned_nowait_table[head])) ?
                         instruction_table[head] : 'h0;
assign unalign_result_o = ((num > 0) & finish_bit_table[head] &
                           (!unaligned_bit_table[head] | unaligned_nowait_table[head])) ?
                            unaligned_result_table[head] : 'h0;
assign unalign_instr_o = finish_bit_table[head] & unaligned_bit_table[head] & unaligned_nowait_table[head];

assign full_o  = ((num >= (PMRQ_NUM_ENTRIES - 3'h3)) | flush_i | ~rstn_i);

endmodule
