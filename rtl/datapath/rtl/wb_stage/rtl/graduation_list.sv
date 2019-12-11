/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : graduation_list.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria Pardos
 *                  David Álvarez Robert
 * Email(s)       : victor.soria@bsc.es
 *                  david.alvarez@bsc.es
 * -----------------------------------------------
 */

import drac_pkg::*;

module graduation_list #
    (
        // How many different instructions can the GL keep. Must be multiple of 2.
        parameter integer NUM_ENTRIES  = 32
    )
    (
    input wire                            clk_i,             // Clock Singal
    input wire                            rstn_i,            // Negated Reset Signal

    // Input Signals of first instruction from decode
    input gl_instruction_t                instruction_i,

    input wire                            read_head_i,      // Read oldest instruction
    input wire                            read_tail_i,      // Read newest instruction

    input gl_index                        instruction_writeback_i, // Mark instruction as finished
    input wire                            instruction_writeback_enable_i, // Write enabled for finished
    input exception_t                     instruction_exc_data_i, // Data of the generated exception

    // Output Signals from added instructions
    output gl_index                       assigned_gl_entry_o,

    output gl_instruction_t               instruction_o,

    output logic                          full_o,           // GL has no free entries
    output logic                          empty_o           // GL has no filled entries
);


parameter ENTRY_BITS = $clog2(NUM_ENTRIES);

logic [ENTRY_BITS-1:0] head;
logic [ENTRY_BITS-1:0] tail;

//Num must be 1 bit bigger than head an tail
logic [ENTRY_BITS:0] num;

logic write_enable;
logic read_enable;
logic read_inverse_enable;

genvar g;

// User can write to the head of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.valid & (int'(num) < NUM_ENTRIES);

// User can read the head of the buffer if there is data stored in the queue
// or in this cycle a new entry is written
assign read_enable = read_head_i & ((num > 0) | instruction_i.valid) & ~read_tail_i;
assign read_inverse_enable = read_tail_i & (num > 0);


`ifndef SRAM_MEMORIES

    reg [0:0] valid_bit [0:NUM_ENTRIES-1];
    gl_instruction_t entries [0:NUM_ENTRIES-1];

    always@(posedge clk_i, negedge rstn_i)
    begin
        if (~rstn_i) begin
            for(i = 0; i < NUM_ENTRIES ; i = i + 1) begin
                  valid_bit[i] = 1'b0;
            end
        end else begin
            if (read_enable) begin
                if ((num == 0) & (instruction_i.valid)) begin
                    instruction_o <= instruction_i;
                end else begin
                    instruction_o <= {valid_bit[head], entries[head]};
                end
            end else if (read_inverse_enable) begin
                instruction_o <= {valid_bit[$unsigned(int'(tail) - 1) % NUM_ENTRIES], entries[$unsigned(int'(tail) - 1) % NUM_ENTRIES]};
            end else begin
                instruction_o.valid <= 1'b0;
            end
        end

        if (write_enable & ~(read_enable & num == 0)) begin
            valid_bit[tail] <= 1'b0;
            entries[tail] <= instruction_i;
        end

        if (rstn_i & instruction_writeback_enable_i) begin
            // Assume this is a correct index
            valid_bit[instruction_writeback_i] <= 1'b1;
            entries[instruction_exc_i].exception <= instruction_exc_data_i;
        end
    end
`else

`endif

always@(posedge clk_i, negedge rstn_i)
begin
    if(~rstn_i) begin
        head <= {ENTRY_BITS{1'b0}};
        tail <= {ENTRY_BITS{1'b0}};
        num  <= {ENTRY_BITS+1{1'b0}};
    end else begin
        assigned_gl_entry_o[0] <= gl_index'(tail);
        tail <= tail + {{ENTRY_BITS-1{1'b0}}, write_enable} - {{ENTRY_BITS-1{1'b0}}, read_inverse_enable};
        head <= head + {{ENTRY_BITS-1{1'b0}}, read_enable};
        num  <= num + {{ENTRY_BITS-1{1'b0}}, write_enable} - {{ENTRY_BITS-1{1'b0}}, read_enable} - {{ENTRY_BITS-1{1'b0}}, read_inverse_enable};
    end
end

assign empty_o = (num == 0);
assign full_o  = (int'(num) == NUM_ENTRIES);

endmodule
