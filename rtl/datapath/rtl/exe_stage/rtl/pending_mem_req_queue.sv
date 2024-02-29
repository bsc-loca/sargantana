/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : pending_mem_req_queue.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author      | Description
 *  0.1        | Victor.SP  |  
 * -----------------------------------------------
 */

module pending_mem_req_queue
    import drac_pkg::*;
(
    input logic                 clk_i,                  // Clock Singal
    input logic                 rstn_i,                 // Negated Reset Signal

    input rr_exe_mem_instr_t    instruction_i,          // All instruction input signals
    input logic [6:0]           tag_i,                  // Tag of the incoming instruction

    input logic                 replay_valid_i,         // A replay is being executed
    input logic                 response_valid_i,       // A response is being executed
    input logic [6:0]           tag_next_i,             // Instruction that finishes
    input bus_dcache_data_t     replay_data_i,          // Replay asociated data
    
    input logic                 flush_i,                // Flush all entries
    input logic                 advance_head_i,         // Advance head pointer one position
    input logic                 mv_back_tail_i,         // Move Back tail pointer one position

    output pmrq_instr_t   finish_instr_o,         // Next Instruction to Write Back
       
    output logic                full_o                  // pmrq is full
);

// TODO: Demanar-li la versió out of order a en Max

typedef logic [$clog2(PMRQ_NUM_ENTRIES)-1:0] pmrq_entry_pointer;

// Points to the next available entry
pmrq_entry_pointer tail;

// Points to the oldest executed entry
pmrq_entry_pointer head;

//Num must be 1 bit bigger than head an tail
logic [$clog2(PMRQ_NUM_ENTRIES):0] num;

// Internal Control Signals
logic write_enable;
logic read_enable;
logic advance_head_enable;
logic mv_back_head_enable;

// User can write to the tail of the buffer if the new data is valid and
// there are any free entry
assign write_enable = instruction_i.instr.valid & (num < PMRQ_NUM_ENTRIES) & (!mv_back_tail_i);

// User can read the next executable instruction of the buffer if there is data
// stored in the queue
assign read_enable = (num > 0);

// User can advance the head of the buffer if there is data stored in the queue
assign advance_head_enable = advance_head_i & (num > 0);

assign mv_back_head_enable = mv_back_tail_i & (!instruction_i.instr.valid) & (num > 0);


// FIFO Memory structure, stores instructions
pmrq_instr_t instruction_table    [PMRQ_NUM_ENTRIES-1:0];
// Tag Storage
logic [6:0]    tag_table                [PMRQ_NUM_ENTRIES-1:0];
// Instruction already finished
logic          finish_bit_table         [PMRQ_NUM_ENTRIES-1:0];

always_ff @(posedge clk_i, negedge rstn_i)
begin
    if (~rstn_i) begin
        for (integer j = 0; j < PMRQ_NUM_ENTRIES; j++) begin
            finish_bit_table[j] <= 1'b0;
            instruction_table[j] <= '0;
            tag_table[j] <= '0;
        end
    end else begin
        // Table initial state
        for (integer j = 0; j < PMRQ_NUM_ENTRIES; j++) begin
            if (replay_valid_i && (tag_table[j] == tag_next_i)) begin
                finish_bit_table[j] <= 1'b1;
                instruction_table[j].data_rs2 <= replay_data_i;
            end
        end
        
        if (write_enable) begin     // Write tail
            instruction_table[tail].instr           <= instruction_i.instr;            
            instruction_table[tail].data_rs1        <= instruction_i.data_rs1;                                 
            instruction_table[tail].data_old_vd     <= instruction_i.data_old_vd;            
            instruction_table[tail].data_vm         <= instruction_i.data_vm;                
            instruction_table[tail].sew             <= instruction_i.sew;                    
            instruction_table[tail].prs1            <= instruction_i.prs1;                      
            instruction_table[tail].rdy1            <= instruction_i.rdy1;                      
            instruction_table[tail].prs2            <= instruction_i.prs2;                      
            instruction_table[tail].rdy2            <= instruction_i.rdy2;                      
            instruction_table[tail].prd             <= instruction_i.prd;                       
            instruction_table[tail].pvd             <= instruction_i.pvd;                      
            instruction_table[tail].old_prd         <= instruction_i.old_prd;                   
            instruction_table[tail].old_pvd         <= instruction_i.old_pvd;                  
            instruction_table[tail].fprd            <= instruction_i.fprd;                      
            instruction_table[tail].old_fprd        <= instruction_i.old_fprd;                  
            instruction_table[tail].is_amo_or_store <= instruction_i.is_amo_or_store;             
            instruction_table[tail].is_amo          <= instruction_i.is_amo;                      
            instruction_table[tail].is_store        <= instruction_i.is_store;                    
            instruction_table[tail].checkpoint_done <= instruction_i.checkpoint_done;             
            instruction_table[tail].chkp            <= instruction_i.chkp;               
            instruction_table[tail].translated      <= instruction_i.translated;                  
            instruction_table[tail].ex              <= instruction_i.ex;
            instruction_table[tail].gl_index        <= instruction_i.gl_index;               
            instruction_table[tail].agu_req_tag     <= instruction_i.agu_req_tag;
            instruction_table[tail].vmisalign_xcpt  <= instruction_i.vmisalign_xcpt;              
            instruction_table[tail].velem_id        <= instruction_i.velem_id;  
            instruction_table[tail].load_mask       <= instruction_i.load_mask;     
            instruction_table[tail].velem_off       <= instruction_i.velem_off; 
            instruction_table[tail].velem_incr      <= instruction_i.velem_incr;  
            instruction_table[tail].neg_stride      <= instruction_i.neg_stride;                  
            tag_table[tail]              <= tag_i;

            instruction_table[tail].data_rs2 <= 'h0;
            finish_bit_table[tail]           <= 1'b0;
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
        head <= head + {2'b00, advance_head_enable};
        tail <= tail + {2'b00, write_enable} - {2'b0, mv_back_head_enable};
        num  <= num  + {3'b0, write_enable} - {3'b0, advance_head_enable} 
                - {3'b0, mv_back_head_enable};
    end
end

assign finish_instr_o = ((num > 0) & finish_bit_table[head]) ? instruction_table[head] : 'h0;

assign full_o  = ((num >= (PMRQ_NUM_ENTRIES - 3'h3)) | flush_i | ~rstn_i);

endmodule
