/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : pending_mem_req_queue.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Guillem Lopez paradis
 * Email(s)       : guillem.lopez@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author      | Description
 *  0.1        | Guillem.LP  |  
 * -----------------------------------------------
 */

module pending_fp_ops_queue
    import drac_pkg::*;
(
    input logic                     clk_i,                  // Clock Singal
    input logic                     rstn_i,                 // Negated Reset Signal

    input logic                     flush_i,                // Flush all entries

    input logic                     valid_i,                // Valid instruction 
    input rr_exe_fpu_instr_t        instruction_i,          // All instruction input signals

    input logic                     result_valid_i,         // Result valid
    input reg_t                     result_tag_i,           // Instruction that finishes
    input bus64_t                   result_data_i,          // Result asociated data
    input fpnew_pkg::status_t        result_fp_status_i,
    input logic                     advance_head_i,         // Advance head pointer one position

    output rr_exe_fpu_instr_t       finish_instr_fp_o,      // Next Instruction to Write Back
    output fpnew_pkg::status_t       finish_fp_status_o,    // Next fp_status to Write Back
    
    output reg_t                    tag_o,                  // Tag given to the incoming instruction
    output logic                    full_o                  // fifo full
);

typedef logic [$clog2(PFPQ_NUM_ENTRIES)-1:0] pfpq_entry_pointer;

// current tag counter
reg_t tag_int;

// Points to the next available entry
pfpq_entry_pointer tail;

// Points to the oldest executed entry
pfpq_entry_pointer head;

//Num must be 1 bit bigger than head an tail
logic [$clog2(PFPQ_NUM_ENTRIES):0] num;

// Internal Control Signals
logic write_enable;
logic read_enable;
logic advance_head_enable;

// Tag given to the fp op is generated here
assign tag_o = tag_int;

// User can write to the tail of the buffer if the new data is valid and
// there are any free entry
assign write_enable = valid_i & instruction_i.instr.valid & (num < PFPQ_NUM_ENTRIES);

// User can read the next executable instruction of the buffer if there is data
// stored in the queue
assign read_enable = (num > 0);

// User can advance the head of the buffer if there is data stored in the queue
assign advance_head_enable = advance_head_i & (num > 0);


// FIFO Memory structure
rr_exe_fpu_instr_t  instruction_table           [0:PFPQ_NUM_ENTRIES-1];
fpnew_pkg::status_t instruction_table_status    [0:PFPQ_NUM_ENTRIES-1];
reg_t               tag_table                   [0:PFPQ_NUM_ENTRIES-1];
logic               control_bits_table          [0:PFPQ_NUM_ENTRIES-1];
logic               valid_table                 [0:PFPQ_NUM_ENTRIES-1];

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if (~rstn_i) begin
        for (integer j = 0; j < PFPQ_NUM_ENTRIES; j++) begin
            valid_table[j] <= 1'b0;
            instruction_table[j] <= '0;
            instruction_table_status[j] <= '0;
            tag_table[j] <= '0;
            control_bits_table[j] <= '0;
        end
    end
    else if (flush_i) begin
        for (integer j = 0; j < PFPQ_NUM_ENTRIES; j++) begin
            valid_table[j] <= 1'b0;
        end
    end else begin
        if (write_enable) begin
            instruction_table[tail]  <= instruction_i;
            tag_table[tail]          <= tag_int;
            control_bits_table[tail] <= 1'b0;
            valid_table[tail]        <= 1'b1;
        end
        
        // Table initial state
        if(result_valid_i) begin
            for (integer j = 0; j < PFPQ_NUM_ENTRIES; j++) begin
                if (tag_table[j] == result_tag_i && valid_table[j]) begin
                    control_bits_table[j] <= 1'b1;
                    instruction_table[j].data_rs3 <= result_data_i;
                    instruction_table_status[j]   <= result_fp_status_i;
                end
            end
        end

        if (advance_head_enable) begin
            valid_table[head] <= 1'b0;
        end


    end
end

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if(~rstn_i) begin
        head    <= 3'h0;
        tail    <= 3'b0;
        num     <= 4'b0;
        tag_int <= 5'b0;
    end
    else if (flush_i) begin
        head    <= 3'h0;
        tail    <= 3'b0;
        num     <= 4'b0;
        tag_int <= 5'b0;
    end
    else begin
        head    <= head + {2'b00, advance_head_enable};
        tail    <= tail + {2'b00, write_enable};
        num     <= num  + {3'b0, write_enable} - {3'b0, advance_head_enable};
        tag_int <= tag_int + {4'b0,write_enable};
    end
end

assign finish_instr_fp_o = ((num > 0) & control_bits_table[head]) ? instruction_table[head] : 'h0;

assign finish_fp_status_o = ((num > 0) & control_bits_table[head]) ? instruction_table_status[head] : 'h0;

assign full_o  = ((num >= PFPQ_NUM_ENTRIES) | flush_i | ~rstn_i);

endmodule

