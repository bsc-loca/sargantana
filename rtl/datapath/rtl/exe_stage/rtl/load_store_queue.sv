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


typedef logic [$clog2(LSQ_NUM_ENTRIES)-1:0] ls_queue_entry;
typedef reg [$clog2(LSQ_NUM_ENTRIES)-1:0] reg_ls_queue_entry;

/*
typedef logic [$bits(exe_wb_instr_t):0] control_cell;
typedef reg [$bits(exe_wb_instr_t):0] reg_control_cell;
*/

module load_store_queue(
    input wire             clk_i,            // Clock Singal
    input wire             rstn_i,           // Negated Reset Signal

    input rr_exe_instr_t   instruction_i,    // All instruction input signals
    input bus64_t          data_rs1_i,       // Data operand 1
    input bus64_t          data_rs2_i,       // Data operand 2
     
    input wire             flush_i,          // Flush all entries to 0
    input wire             read_next_i,      // Read next instruction of the ciruclar buffer
    input wire             reset_next_i,     // Reset next instruction to the head
    input wire             advance_head_i,   // Advance head one position

    output rr_exe_instr_t  instruction_o,    // All intruction output signals
    output bus64_t         data_rs1_o,       // Data operand 1
    output bus64_t         data_rs2_o,       // Data operand 2

    output ls_queue_entry  ls_queue_entry_o, // Assignated lsq entrie      
    output logic           full_o,           // Lsq is full
    output logic           empty_o           // Lsq is empty TODO: check if empty signal is necessary
);

reg_ls_queue_entry head;
reg_ls_queue_entry tail;
reg_ls_queue_entry next;

rr_exe_instr_t stored_instruction_q;
bus64_t stored_rs1_q;
bus64_t stored_rs2_q;

//Num must be 1 bit bigger than head an tail
logic [$clog2(LSQ_NUM_ENTRIES):0] num;
logic [$clog2(LSQ_NUM_ENTRIES):0] num_to_read;

logic write_enable;
logic read_enable;
logic advance_enable;


// User can write to the tail of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.instr.valid & (num < LSQ_NUM_ENTRIES);

// User can read the next instruction of the buffer if there is data stored in the queue
// or in this cycle a new entry is written
assign read_enable = read_next_i & (num_to_read > 0) & (~reset_next_i);

// User can advance the head of the buffer if there is data stored in the queue
// or in this cycle a new entry is written
assign advance_enable = advance_head_i & (num > 0) & (~reset_next_i);


`ifndef SRAM_MEMORIES

    // FIFO Memory structure

    reg64_t data_table [0:LSQ_NUM_ENTRIES-1]; 
    regPC_t addr_table [0:LSQ_NUM_ENTRIES-1];
    rr_exe_instr_t control_table[0:LSQ_NUM_ENTRIES-1];

    
    always_ff @(posedge clk_i, negedge rstn_i)
    begin
        if (~rstn_i) begin
            stored_instruction_q <= 'h0;
            stored_rs1_q <= 'h0;
            stored_rs2_q <= 'h0;
        end else begin          
            // Write tail
            if (write_enable) begin
                addr_table[tail] <= data_rs1_i;
                data_table[tail] <= data_rs2_i;
                control_table[tail] <= instruction_i;
            end
        end
    end

`else

`endif

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if(~rstn_i) begin
        head <= 3'h0;
        next <= 3'h0;
        tail <= 3'b0;
        num  <= 4'b0;
        num_to_read <= 4'b0;
        ls_queue_entry_o <= 3'b0;
    end
    else if (flush_i) begin
        head <= 3'h0;
        next <= 3'h0;
        tail <= 3'b0;
        num  <= 4'b0;
        num_to_read <= 4'b0;
        ls_queue_entry_o <= 3'b0;
    end
    else if (reset_next_i) begin
        ls_queue_entry_o <= tail;
        next <= head;
        head <= head;
        tail <= tail + {2'b00, write_enable};
        num_to_read <= num  + {3'b0, write_enable};
        num  <= num  + {3'b0, write_enable};
    end
    else begin
        ls_queue_entry_o <= tail;
        next <= next + {2'b00, read_enable};
        head <= head + {2'b00, advance_enable};
        tail <= tail + {2'b00, write_enable};
        num_to_read <= num_to_read  + {3'b0, write_enable} - {3'b0, read_enable};
        num  <= num  + {3'b0, write_enable} - {3'b0, advance_enable};
    end
end


assign instruction_o = (~read_enable)? 'h0 : control_table[next];
assign data_rs1_o = (~read_enable)? 'h0 : addr_table[next];
assign data_rs2_o = (~read_enable)? 'h0 : data_table[next];


assign empty_o = (num_to_read == 0);
assign full_o  = ((num == LSQ_NUM_ENTRIES) | flush_i | ~rstn_i);

endmodule

