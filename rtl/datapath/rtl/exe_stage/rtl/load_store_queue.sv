/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : load_store_queue.v
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


typedef logic [$clog2(LSQ_NUM_ENTRIES)-1:0] lsq_entry_pointer;

module load_store_queue(
    input logic                clk_i,            // Clock Singal
    input logic                rstn_i,           // Negated Reset Signal

    input rr_exe_mem_instr_t   instruction_i,    // All instruction input signals
     
    input logic                flush_i,          // Flush all entries
    input logic                read_next_i,      // Read next instruction of the ciruclar buffer
    input logic                reset_next_i,     // Reset next instruction to the exec pointer
    input logic                advance_head_i,   // Advance head pointer one position

    output rr_exe_mem_instr_t  next_instr_exe_o, // Next Instruction to be executed 
       
    output logic               full_o,           // Lsq is full
    output logic               empty_o,          // Lsq is empty
    
    output logic               pmu_load_after_store_o  // Load blocked by ongoing store
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

// Internal Control Signals
logic write_enable;
logic read_enable;
logic advance_head_enable;

// User can write to the tail of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.instr.valid & (num < LSQ_NUM_ENTRIES);

// User can read the next executable instruction of the buffer if there is data
// stored in the queue
assign read_enable = read_next_i & (num_to_exe > 0) & (~reset_next_i);

// User can advance the head of the buffer if there is data stored in the queue
assign advance_head_enable = advance_head_i & ((num_on_fly > 0) | read_enable);

// FIFO Memory structure
rr_exe_mem_instr_t control_table[0:LSQ_NUM_ENTRIES-1];

always_ff @(posedge clk_i)
begin
    // Write tail
    if (write_enable) begin
        control_table[tail] <= instruction_i;
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
    end
    else if (flush_i) begin
        head <= 3'h0;
        next <= 3'h0;
        tail <= 3'b0;
        num  <= 4'b0;
        num_to_exe   <= 4'b0;
        num_on_fly   <= 4'b0;
    end
    else if (reset_next_i) begin
        next <= head;
        head <= head;
        tail <= tail + {2'b00, write_enable};
        num  <= num  + {3'b0, write_enable} - {3'b0, advance_head_enable};
        num_to_exe   <= num_to_exe + {3'b0, write_enable} + num_on_fly;
        num_on_fly   <= 4'b0;
    end
    else begin
        next <= next + {2'b00, read_enable};
        head <= head + {2'b00, advance_head_enable};
        tail <= tail + {2'b00, write_enable};
        num  <= num  + {3'b0, write_enable} - {3'b0, advance_head_enable};
        num_to_exe   <= num_to_exe + {3'b0, write_enable} - {3'b0, read_enable};
        num_on_fly   <= num_on_fly + {2'b00, read_enable} - {3'b0, advance_head_enable};
    end
end


assign next_instr_exe_o = (~read_enable)? 'h0 : control_table[next];

assign empty_o = (num_to_exe == 0);
assign full_o  = ((num == LSQ_NUM_ENTRIES) | flush_i | ~rstn_i);

assign pmu_load_after_store_o = ~read_enable && num_to_exe > 0 && 
                                (control_table[next].instr.instr_type == LB || 
                                control_table[next].instr.instr_type == LH  ||
                                control_table[next].instr.instr_type == LW  ||
                                control_table[next].instr.instr_type == LD  ||
                                control_table[next].instr.instr_type == LBU ||
                                control_table[next].instr.instr_type == LHU ||
                                control_table[next].instr.instr_type == LWU) &&  
                                (control_table[next-1].instr.instr_type == SD       || 
                                control_table[next-1].instr.instr_type == SW        ||
                                control_table[next-1].instr.instr_type == SH        ||
                                control_table[next-1].instr.instr_type == SB        ||
                                control_table[next-1].instr.instr_type == AMO_MAXWU ||
                                control_table[next-1].instr.instr_type == AMO_MAXDU ||
                                control_table[next-1].instr.instr_type == AMO_MINWU ||
                                control_table[next-1].instr.instr_type == AMO_MINDU ||
                                control_table[next-1].instr.instr_type == AMO_MAXW  ||
                                control_table[next-1].instr.instr_type == AMO_MAXD  ||
                                control_table[next-1].instr.instr_type == AMO_MINW  ||
                                control_table[next-1].instr.instr_type == AMO_MIND  ||
                                control_table[next-1].instr.instr_type == AMO_ORW   ||
                                control_table[next-1].instr.instr_type == AMO_ORD   ||
                                control_table[next-1].instr.instr_type == AMO_ANDW  ||
                                control_table[next-1].instr.instr_type == AMO_ANDD  ||
                                control_table[next-1].instr.instr_type == AMO_XORW  ||
                                control_table[next-1].instr.instr_type == AMO_XORD  ||
                                control_table[next-1].instr.instr_type == AMO_ADDW  ||
                                control_table[next-1].instr.instr_type == AMO_ADDD  ||
                                control_table[next-1].instr.instr_type == AMO_SWAPW ||
                                control_table[next-1].instr.instr_type == AMO_SWAPD ||
                                control_table[next-1].instr.instr_type == AMO_SCW   ||
                                control_table[next-1].instr.instr_type == AMO_SCD   ||
                                control_table[next-1].instr.instr_type == AMO_LRW   ||
                                control_table[next-1].instr.instr_type == AMO_LRD);

endmodule

