/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : freelist.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author      | Description
 *  0.1        | Victor.SP   |  
 * -----------------------------------------------
 */

// TODO: Add checkpointing to recover state fast.

//`default_nettype none
import drac_pkg::*;

typedef logic [REGFILE_WIDTH-1:0] free_list_entry;
typedef reg [REGFILE_WIDTH-1:0] reg_free_list_entry;

localparam NUM_ENTRIES = 32; // Number of entries in circular buffer

module free_list(
    input wire             clk_i,               // Clock Singal
    input wire             rstn_i,              // Negated Reset Signal
    input wire             read_head_i,         // Read tail of the ciruclar buffer
    input wire             add_free_register_i, // Add new free register
    input reg_t            free_register_i,     // Register to be freed           

    output reg_t           new_register_o,      // First free register
    output logic           empty_o              // Free list is empty
);

reg_free_list_entry head;
reg_free_list_entry tail;

//Num must be 1 bit bigger than head an tail
logic [$clog2(NUM_ENTRIES):0] num;

logic write_enable;
logic read_enable;


// User can write to the tail of the buffer to add new register
assign write_enable = add_free_register_i;

// User can read the head of the buffer if there is any free register or 
// in this cycle a new register is written
assign read_enable = read_head_i & ((num > 0) | add_free_register_i) ;


`ifndef SRAM_MEMORIES

    // FIFO Memory structure

    reg_t register_table [0:NUM_ENTRIES-1];

    `ifndef SYNTHESIS
        // Initialize all the entries of lsq with the initial state
        integer i;
        initial 
        begin for(i = 0; i < NUM_ENTRIES ; i = i + 1) begin
                register_table[i] = 'h0;
              end
        end
    `endif
    
    always @(posedge clk_i)
    begin
        // Read Head
        if (read_enable) begin
            // Special case bypass from tail to head
            if ((num == 0) & (add_free_register_i)) begin
                new_register_o <= free_register_i; 
            end else begin 
                new_register_o <= register_table[head];

            end
        end else begin // When not reading an entry
            instruction_o.addr <= 6'h0;
        end
        
        // Write tail
        if (write_enable & ~(read_enable & num == 0)) begin
            register_table[tail] <= free_register_i;
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

endmodule

