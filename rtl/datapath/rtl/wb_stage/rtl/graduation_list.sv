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

    // Input Signals of instruction from Read Register
    input gl_instruction_t                instruction_i,

    // Read Entry Interface
    input wire                            read_head_i,      // Read oldest instruction
    input wire                            read_tail_i,      // Read newest instruction

    // Write Back Interface
    input gl_index_t                      instruction_writeback_i, // Mark instruction as finished
    input wire                            instruction_writeback_enable_i, // Write enabled for finished
    input gl_instruction_t                instruction_writeback_data_i, // Data of the generated exception

    input wire                            flush_i,          // Flush instructions from the graduation list
    input gl_index_t                      flush_index_i,    // Index that selects the first correct instruction

    // Output Signal of instruction to Read Register 
    output gl_index_t                     assigned_gl_entry_o,

    // Output Signal of first finished instruction
    output gl_instruction_t               instruction_o,
    output gl_index_t                     commit_gl_entry_o,

    // Output Control Signals 
    output logic                          full_o,           // GL has no free entries
    output logic                          empty_o           // GL has no filled entries
);


parameter num_bits_index = $clog2(NUM_ENTRIES);

gl_index_t head;
gl_index_t tail;

//Num must be 1 bit bigger than head an tail
logic [num_bits_index:0] num;

logic write_enable;
logic read_enable;
logic read_inverse_enable;

// Register for valid bit
reg valid_bit [0:NUM_ENTRIES-1];

// User can write to the head of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.valid & (int'(num) < NUM_ENTRIES) & ~(flush_i);

// User can read the head of the buffer if there is data stored in the queue
// or in this cycle a new entry is written
assign read_enable = read_head_i & (num > 0) & ~(read_tail_i) & (valid_bit[head]);
assign read_inverse_enable = read_tail_i & (num > 0);


`ifndef SRAM_MEMORIES


    gl_instruction_t entries [0:NUM_ENTRIES-1];

    always@(posedge clk_i, negedge rstn_i)
    begin
        if (~rstn_i) begin
            for(int i = 0; i < NUM_ENTRIES ; i = i + 1) begin
                  valid_bit[i] = 1'b0;
            end
        end else begin
            if (read_enable) begin
                if ((num == 0) & (instruction_i.valid)) begin // Imposible case
                    instruction_o <= instruction_i;
                end else begin
                    instruction_o <= {entries[head]};
                    commit_gl_entry_o <= head;
                end
            end else if (read_inverse_enable) begin
                instruction_o <= entries[tail - 'b1];
            end else begin
                instruction_o.valid <= 1'b0;
                instruction_o.instr_type <= ADD;
                instruction_o.exception.valid <= 1'b0;
                instruction_o.stall_csr_fence <= 1'b0;
                instruction_o.old_prd <= 'b0;
                commit_gl_entry_o <= 'b0;
            end
        end

        if (write_enable) begin
            valid_bit[tail] <= 1'b0;
            entries[tail] <= instruction_i;
        end

        if (rstn_i & instruction_writeback_enable_i) begin
            // Assume this is a correct index
            valid_bit[instruction_writeback_i] <= 1'b1;
            entries[instruction_writeback_i].csr_addr <= instruction_writeback_data_i.csr_addr;
            entries[instruction_writeback_i].exception <= instruction_writeback_data_i.exception;
            entries[instruction_writeback_i].result <= instruction_writeback_data_i.result;
        end
    end
`else

`endif

always@(posedge clk_i, negedge rstn_i)
begin
    if(~rstn_i) begin
        head <= {num_bits_index{1'b0}};
        tail <= {num_bits_index{1'b0}};
        num  <= {num_bits_index+1{1'b0}};
    end else if (flush_i) begin
        tail <= flush_index_i + {{num_bits_index-1{1'b0}}, 1'b1}; 
        head <= head + {{num_bits_index-1{1'b0}}, read_enable};
        if ( (flush_index_i + {{num_bits_index-1{1'b0}}, 1'b1}) >= (head + {{num_bits_index-1{1'b0}}, read_enable}) )    // Recompute number of entries
            num <= ({1'b0, flush_index_i} + {{num_bits_index-1{1'b0}}, 1'b1}) - ({1'b0, head} + {{num_bits_index-1{1'b0}}, read_enable});
        else 
            num <= NUM_ENTRIES[num_bits_index:0] - ({1'b0, head} + {{num_bits_index-1{1'b0}}, read_enable}) +  ({1'b0, flush_index_i} + {{num_bits_index-1{1'b0}}, 1'b1});
    end else begin
        tail <= tail + {{num_bits_index-1{1'b0}}, write_enable} - {{num_bits_index-1{1'b0}}, read_inverse_enable};
        head <= head + {{num_bits_index-1{1'b0}}, read_enable};
        num  <= num + {{num_bits_index-1{1'b0}}, write_enable} - {{num_bits_index-1{1'b0}}, read_enable} - {{num_bits_index-1{1'b0}}, read_inverse_enable};
    end
end

assign assigned_gl_entry_o = tail;
assign empty_o = (num == 0);
assign full_o  = (int'(num) == NUM_ENTRIES);

endmodule
