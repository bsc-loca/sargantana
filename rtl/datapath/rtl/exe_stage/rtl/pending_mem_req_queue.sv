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
    input logic            clk_i,            // Clock Singal
    input logic            rstn_i,           // Negated Reset Signal

    input rr_exe_instr_t   instruction_i,    // All instruction input signals
    input reg_t            tag_i,            // Tag of the incoming instruction

    input logic            replay_valid_i,   // A replay is being executed
    input reg_t            tag_next_i,       // Instruction that finishes
    input bus64_t          replay_data_i,    // Replay asociated data
    input logic            flush_i,          // Flush all entries
    input logic            advance_head_i,   // Advance head pointer one position

    output rr_exe_instr_t  finish_instr_o,   // Next Instruction to Write Back
       
    output logic           full_o            // pmrq is full

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
assign write_enable = instruction_i.instr.valid & (num < PMRQ_NUM_ENTRIES);

// User can read the next executable instruction of the buffer if there is data
// stored in the queue
assign read_enable = (num > 0);

// User can advance the head of the buffer if there is data stored in the queue
assign advance_head_enable = advance_head_i & (num > 0);


`ifndef SRAM_MEMORIES

    // FIFO Memory structure
    rr_exe_mem_instr_t instruction_table    [0:PMRQ_NUM_ENTRIES-1];
    reg_t              tag_table            [0:PMRQ_NUM_ENTRIES-1];
    logic              control_bits_table   [0:PMRQ_NUM_ENTRIES-1];
    
    always_ff @(posedge clk_i)
    begin
        // Write tail
        if (write_enable) begin
            instruction_table[tail]  <= instruction_i;
            tag_table[tail]          <= tag_i;
            control_bits_table[tail] <= 1'b0;
        end
        
        // Table initial state
        if(replay_valid_i) begin
            for (integer j = 0; j <= PMRQ_NUM_ENTRIES; j++) begin
                if (tag_table[j] == tag_next_i) begin
                    control_bits_table[j] = 1'b1;
                    instruction_table[j].instr.imm = replay_data_i;
                end
            end
        end
    end

`else

`endif

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
        tail <= tail + {2'b00, write_enable};
        num  <= num  + {3'b0, write_enable} - {3'b0, advance_head_enable};
    end
end

assign finish_instr_o = ((num > 0) & control_bits_table[head]) ? instruction_table[head] : 'h0;

assign full_o  = ((num == (PMRQ_NUM_ENTRIES - 3'h3)) | flush_i | ~rstn_i);

endmodule

