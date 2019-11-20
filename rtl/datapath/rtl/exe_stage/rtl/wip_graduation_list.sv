/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : rob.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author     | Description
 *  0.1        | Victor.SP  |  
 * -----------------------------------------------
 */

import drac_pkg::*;

module mem_unit #
    (    
        parameter integer NUM_ENTRIES  = 32,
        parameter integer NUM_PORTS = 1
    )
    (
    input wire                            clk_i,             // Clock Singal
    input wire                            rstn_i,            // Negated Reset Signal

    // Input Signals of first instruction from decode
    input rob_instruction_in_interface_t  intruction_i[NUM_PORTS],       

    input wire                            read_head_i,      // Read oldest instruction

    // Output Signals from added instructions
    output rob_index                      assigned_rob_entry_o[NUM_PORTS],

    output rob_instruction_in_interface_t intruction_o[NUM_PORTS],

    output logic                          full_o,           // Rob has no free entries 
    output logic                          empty_o           // Rob has no filled entries
);

typedef reg [54:0] rob_entry;


logic [$clog2(NUM_ENTRIES)-1:0] head;
logic [$clog2(NUM_ENTRIES)-1:0] tail;

//Num must be 1 bit bigger than head an tail
logic [$clog2(NUM_ENTRIES_ROB):0] num;

logic write_enable;
logic read_enable;

// User can write to the head of the buffer if the new data is valid and
// there are any free entry
assign write_enable = intruction_i.valid & (num < NUM_ENTRIES);

// User can read the tail of the buffer if there is data stored in the queue
// or in this cycle a new entry is written
assign read_enable = read_head_i & ((num > 0) | intruction_i.valid) ;

`ifndef SRAM_MEMORIES

    reg [1:0] valid_bit [0:NUM_ENTRIES_ROB-1]; 
    reg rob_entry entries [0:NUM_ENTRIES_ROB-1];

    `ifndef SYNTHESIS
        // Initialize all the entries of lsq with the initial state
        integer i;
        initial 
        begin for(i = 0; i < NUM_ENTRIES ; i = i + 1) begin
                  valid_bit[i] = 1'b0;
              end
        end
    `endif
    
    always@(posedge clk_i, negedge rstn_i)
    begin
        if (~rstn_i) begin
            for(i = 0; i < NUM_ENTRIES ; i = i + 1) begin
                  valid_bit[i] = 1'b0;
            end
        end else begin
            if (read_enable) begin
                if ((num == 0) & (instruction_i.valid)) begin
                    instruction_o[0].valid <= instruction_i[0].valid;
                    instruction_o[0].destination_register <= instruction_i[0].destination_register;

                end else begin
                    instruction_o[0] <= {valid_bit[head], entries[head]};
                end
            end else begin
                instruction_o[0].valid <= 1'b0;
            end

        if (write_enable & ~(read_enable & num == 0)) begin
            valid_bit[tail] <= 1'b0;
            entries[tail] <= {instruction_i.destination_register,
                              instruction_i.source_register_1,
                              instruction_i.source_register_2,
                              instruction_i.program_counter};
        end
    end
`else

`endif

always@(posedge clk_i, negedge rstn_i)
begin
    if(~rstn_i | flush_i) begin
        head <= 5'b0;
        tail <= 5'b0;
        num  <= 5'b0;
    end
    else begin
        ls_queue_entry_o <= tail;
        tail <= tail + {4'b00, write_enable};
        head <= head + {4'b00, read_enable};
        num  <= num  + {4'b00, write_enable} - {4s'b00, read_enable};
    end
end

assign empty_o = (num == 0);
assign full_o  = (num == NUM_ENTRIES);

endmodule
