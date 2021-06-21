/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : instruction_queue.v
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

typedef logic [$clog2(INSTRUCTION_QUEUE_NUM_ENTRIES)-1:0] instruction_queue_entry;
typedef reg [$clog2(INSTRUCTION_QUEUE_NUM_ENTRIES)-1:0] reg_instruction_queue_entry;


module instruction_queue(
    input logic            clk_i,            // Clock Singal
    input logic            rstn_i,           // Negated Reset Signal

    input instr_entry_t    instruction_i,    // All instruction input signals   
    input logic            flush_i,          // Flush all entries to 0
    input logic            read_head_i,      // Read tail of the ciruclar buffer

    output instr_entry_t   instruction_o,    // All intruction output signals
    output logic           full_o,           // IQ is full
    output logic           empty_o           // IQ is empty TODO: check if empty signal is necessary
);

reg_instruction_queue_entry head;
reg_instruction_queue_entry tail;

rr_exe_instr_t stored_instruction_q;

//Num must be 1 bit bigger than head an tail
logic [$clog2(INSTRUCTION_QUEUE_NUM_ENTRIES):0] num;

logic write_enable;
logic read_enable;


// User can write to the head of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.valid & (num < INSTRUCTION_QUEUE_NUM_ENTRIES);

// User can read the tail of the buffer if there is data stored in the queue
// or in this cycle a new entry is written
assign read_enable = read_head_i & (num > 0) ;


instr_entry_t instruction_bufffer[0:INSTRUCTION_QUEUE_NUM_ENTRIES-1];

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if (~rstn_i) begin
        stored_instruction_q <= 'h0;
    end else begin          
        // Write tail
        if (write_enable) begin
            instruction_bufffer[tail] <= instruction_i;
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
        head <= head + {2'b00, read_enable};
        tail <= tail + {2'b00, write_enable};
        num  <= num  + {3'b0, write_enable} - {3'b0, read_enable};
    end
end


assign instruction_o = (~read_enable)? 'h0 : instruction_bufffer[head];
assign empty_o = (num == 0);
assign full_o  = ((num == INSTRUCTION_QUEUE_NUM_ENTRIES) | ~rstn_i);

endmodule

