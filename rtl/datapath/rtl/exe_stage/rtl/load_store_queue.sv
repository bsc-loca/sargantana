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

//`default_nettype none
import drac_pkg::*;

localparam NUM_ENTRIES = 8; // Number of entries in circular buffer


typedef logic [$clog2(NUM_ENTRIES)-1:0] ls_queue_entry;
typedef reg [$clog2(NUM_ENTRIES)-1:0] reg_ls_queue_entry;

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
    input wire             read_head_i,      // Read tail of the ciruclar buffer

    output rr_exe_instr_t  instruction_o,    // All intruction output signals
    output bus64_t         data_rs1_o,       // Data operand 1
    output bus64_t         data_rs2_o,       // Data operand 2

    output ls_queue_entry  ls_queue_entry_o, // Assignated lsq entrie      
    output logic           full_o,           // Lsq is full
    output logic           empty_o           // Lsq is empty TODO: check if empty signal is necessary
);

reg_ls_queue_entry head;
reg_ls_queue_entry tail;

//Num must be 1 bit bigger than head an tail
logic [$clog2(NUM_ENTRIES):0] num;

logic write_enable;
logic read_enable;


// User can write to the head of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.instr.valid & (num < NUM_ENTRIES);

// User can read the tail of the buffer if there is data stored in the queue
// or in this cycle a new entry is written
assign read_enable = read_head_i & ((num > 0) | instruction_i.instr.valid) ;


`ifndef SRAM_MEMORIES

    // FIFO Memory structure

    reg64_t data_table [0:NUM_ENTRIES-1]; 
    regPC_t addr_table [0:NUM_ENTRIES-1];
    rr_exe_instr_t control_table[0:NUM_ENTRIES-1];

    
    always_ff @(posedge clk_i)
    begin
        // Read Head
        if (read_enable) begin
            // Special case bypass from tail to head
            if ((num == 0) & (instruction_i.instr.valid)) begin
                instruction_o <= instruction_i;
                data_rs1_o <= data_rs1_i;
                data_rs2_o <= data_rs2_i;
            end else begin 
                instruction_o <= control_table[head];
                data_rs1_o <= addr_table[head];
                data_rs2_o <= data_table[head];

            end
        end else begin // When not reading an entry
            instruction_o.instr.valid <= 0;
            data_rs1_o <= 64'h0;
            data_rs2_o <= 64'h0;
        end
        
        // Write tail
        if (write_enable & ~(read_enable & num == 0)) begin
            addr_table[tail] <= data_rs1_i;
            data_table[tail] <= data_rs2_i;
            control_table[tail] <= instruction_i;
        end
    end

`else

`endif

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if(~rstn_i | flush_i) begin
        head <= 3'b0;
        tail <= 3'b0;
        num  <= 4'b0;
        ls_queue_entry_o <= 3'b0;
    end
    else begin
        ls_queue_entry_o <= tail;
        head <= head + {2'b00, read_enable};
        tail <= tail + {2'b00, write_enable};
        num  <= num  + {3'b0, write_enable} - {3'b0, read_enable};
    end
end

assign empty_o = (num == 0);
assign full_o  = ((num == NUM_ENTRIES) | flush_i | ~rstn_i);

endmodule

