/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : graduation_list.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 */

import drac_pkg::*;

module graduation_list #
    (
        // How many different instructions can the GL keep. Must be multiple of 2.
        parameter integer NUM_ENTRIES  = 32
    )
    (
    input wire                                 clk_i,                             // Clock Singal
    input wire                                 rstn_i,                            // Negated Reset Signal

    // Input Signals of instruction from Read R
    input gl_instruction_t                     instruction_i,

    // Read Entry Interface
    input logic [1:0]                          read_head_i,                       // Read oldest instruction

    // Write Back Interface
    input gl_index_t       [NUM_SCALAR_WB-1:0] instruction_writeback_i,           // Mark instruction as finished
    input logic            [NUM_SCALAR_WB-1:0] instruction_writeback_enable_i,    // Write enabled for finished
    input gl_instruction_t [NUM_SCALAR_WB-1:0] instruction_writeback_data_i,      // Data of the generated exception

    input gl_index_t       [NUM_SIMD_WB-1:0] instruction_simd_writeback_i,        // Mark instruction as finished
    input logic            [NUM_SIMD_WB-1:0] instruction_simd_writeback_enable_i, // Write enabled for finished
    input gl_instruction_t [NUM_SIMD_WB-1:0] instruction_simd_writeback_data_i,   // Data of the generated exception
    input gl_index_t [drac_pkg::NUM_FP_WB-1:0]           instruction_fp_writeback_i,        // Mark instruction as finished
    input logic [drac_pkg::NUM_FP_WB-1:0]                instruction_fp_writeback_enable_i, // Write enabled for finished
    input gl_instruction_t [drac_pkg::NUM_FP_WB-1:0]     instruction_fp_writeback_data_i,   // Data of the generated exception

    input wire                                 flush_i,                           // Flush instructions from the graduation list
    input gl_index_t                           flush_index_i,                     // Index that selects the first correct instruction

    input wire                                 flush_commit_i,                    // Flush all instructions

    // Output Signal of instruction to Read Register 
    output gl_index_t                          assigned_gl_entry_o,

    // Output Signal of first finished instruction
    output gl_instruction_t [1:0]              instruction_o,
    output gl_index_t                          commit_gl_entry_o,

    // Output Control Signals 
    output logic                               full_o,                            // GL has no free entries
    output logic                               empty_o                            // GL has no filled entries
);


parameter num_bits_index = $clog2(NUM_ENTRIES);

gl_index_t head;
gl_index_t tail;

//Num must be 1 bit bigger than head and tail
logic [num_bits_index:0] num;

logic write_enable;
logic [1:0] read_enable;

logic is_store_or_amo;

// Register for valid bit
reg valid_bit [0:NUM_ENTRIES-1];

// User can write to the head of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.valid & (int'(num) < NUM_ENTRIES-1) & ~(flush_i) & (~flush_commit_i); 

// User can read the head of the buffer if there is data stored in the queue
// or in this cycle a new entry is written
assign read_enable = {1'b0,read_head_i[1]} + {1'b0,read_head_i[0]}; // & (num > 0) & (valid_bit[head]) & ~(flush_i) & (~flush_commit_i);


assign is_store_or_amo = (instruction_i.mem_type == STORE) || (instruction_i.mem_type == AMO);


gl_instruction_t entries [0:NUM_ENTRIES-1];

always@(posedge clk_i, negedge rstn_i)
begin 
    if (~rstn_i) begin
        for(int i = 0; i < NUM_ENTRIES ; i = i + 1) begin
                valid_bit[i] <= 1'b0;
        end
    end else begin

        if (write_enable) begin
            valid_bit[tail] <= is_store_or_amo;
            entries[tail] <= instruction_i;
        end

        for (int i = 0; i<NUM_SCALAR_WB; ++i) begin
            if (rstn_i & instruction_writeback_enable_i[i]) begin
                valid_bit[instruction_writeback_i[i]] <= 1'b1;
                entries[instruction_writeback_i[i]].csr_addr  <= instruction_writeback_data_i[i].csr_addr;
                entries[instruction_writeback_i[i]].exception <= instruction_writeback_data_i[i].exception;
                entries[instruction_writeback_i[i]].result    <= instruction_writeback_data_i[i].result;
                entries[instruction_writeback_i[i]].fp_status <= instruction_writeback_data_i[i].fp_status;
            end
        end

        for (int i = 0; i<NUM_SIMD_WB; ++i) begin
            if (rstn_i & instruction_simd_writeback_enable_i[i]) begin
                valid_bit[instruction_simd_writeback_i[i]] <= 1'b1;
                entries[instruction_simd_writeback_i[i]].csr_addr  <= instruction_simd_writeback_data_i[i].csr_addr;
                entries[instruction_simd_writeback_i[i]].exception <= instruction_simd_writeback_data_i[i].exception;
                entries[instruction_simd_writeback_i[i]].result    <= instruction_simd_writeback_data_i[i].result;
            end
        end
        
        for (int i = 0; i<drac_pkg::NUM_FP_WB; ++i) begin
            if (rstn_i & instruction_fp_writeback_enable_i[i]) begin
                valid_bit[instruction_fp_writeback_i[i]] <= 1'b1;
                entries[instruction_fp_writeback_i[i]].csr_addr  <= instruction_fp_writeback_data_i[i].csr_addr;
                entries[instruction_fp_writeback_i[i]].exception <= instruction_fp_writeback_data_i[i].exception;
                entries[instruction_fp_writeback_i[i]].result    <= instruction_fp_writeback_data_i[i].result;
                entries[instruction_fp_writeback_i[i]].fp_status <= instruction_fp_writeback_data_i[i].fp_status;
            end
        end
    end
end

always@(posedge clk_i, negedge rstn_i)
begin
    if(~rstn_i) begin
        head <= {num_bits_index{1'b0}};
        tail <= {num_bits_index{1'b0}};
        num  <= {num_bits_index+1{1'b0}};
    end else if (flush_commit_i) begin
        head <= {num_bits_index{1'b0}};
        tail <= {num_bits_index{1'b0}};
        num  <= {num_bits_index+1{1'b0}};
    end else if (flush_i & (num > 0)) begin
        tail <= flush_index_i + {{num_bits_index-1{1'b0}}, 1'b1}; 
        head <= head + {{num_bits_index-2{1'b0}}, read_enable};
        if ((flush_index_i + {{num_bits_index-1{1'b0}}, 1'b1}) >= (head + {{num_bits_index-2{1'b0}}, read_enable}) && (int'(num) != NUM_ENTRIES)) begin   // Recompute number of entries
            num <= {1'b0, (flush_index_i + {{num_bits_index-1{1'b0}}, 1'b1})} - {1'b0 , (head + {{num_bits_index-2{1'b0}}, read_enable} )};
        end else begin
            num <= NUM_ENTRIES[num_bits_index:0] - {1'b0, (head + {{num_bits_index-2{1'b0}}, read_enable})} +  {1'b0, (flush_index_i + {{num_bits_index-1{1'b0}}, 1'b1})};
        end
    end else begin
        tail <= tail + {{num_bits_index-1{1'b0}}, write_enable};
        head <= head + {{num_bits_index-2{1'b0}}, read_enable};
        num  <= num + {{num_bits_index-1{1'b0}}, write_enable} - {{num_bits_index-2{1'b0}}, read_enable};
    end
end

always_comb begin
    instruction_o[0] = 'b0;
    instruction_o[1] = 'b0;
    commit_gl_entry_o = 'b0;
    if ((~flush_commit_i)) begin
        if (((num == 1) & valid_bit[head]) || ((num > 1) & valid_bit[head] & !valid_bit[head+1])) begin // Imposible case
            instruction_o[0] = entries[head];
            commit_gl_entry_o = head;
        end else if ((num > 1) & valid_bit[head] & valid_bit[head+1]) begin
            instruction_o[0] = entries[head];
            instruction_o[1] = entries[head+1];
            commit_gl_entry_o = head;
        end
    end
end

assign assigned_gl_entry_o = tail;
assign empty_o = (num == 0);
assign full_o  = (int'(num) == NUM_ENTRIES-1);

endmodule
