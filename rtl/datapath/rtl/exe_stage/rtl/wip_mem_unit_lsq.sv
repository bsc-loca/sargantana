/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : mem_unit.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Víctor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author   | Description
 *  0.1        | Victor.SP  |  
 * -----------------------------------------------
 */

import drac_pkg::*;

module mem_unit (
    input  wire            clk_i,           // Clock signal
    input  wire            rstn_i,          // Reset signal

    input lsq_interface_t  interface_i,     // Interface to add new instuction
    input logic            kill_i,          // Exception detected at Commit
    input logic            flush_i,         // Delete all load_store_queue entries

    // DCACHE INTERFACE TO mem_unit
    
    input logic            ready_i,         // Dcache finished load and AMO
    input bus64_t          data_i,          // Dcache readed data
    input logic            lock_i,          // Dcache can accept new mem. op.
    

    // TO DCACHE INTERFACE  
    output logic           valid_o,             // New memory request
    output bus64_t         data_rs1_o,          // Data operand 1
    output bus64_t         data_rs2_o,          // Data operand 2
    output instr_type_t    instr_type_o,        // Type of instruction
    output mem_op_t        mem_op_o,            // Type of memory access
    output logic [2:0]     funct3_o,            // Granularity of mem. access
    output reg_t           rd_o,                // Destination register. Used for identify a pending Miss
    output bus64_t         imm_o,               // Inmmediate

    // LOAD OUTPUT to PIPELINE
    output bus64_t         data_o,          // Loaded data from cache

    // OUTPUT TO Graduation List
    output logic [2:0]    ls_queue_entry_o, // Index to load store queue entry
    
    // OUTPUT TO CONTROL
    output logic           ready_o,         // Mem unit finished load or AMO
    output logic           lock_o           // Mem unit is able to accept more petitions
);


logic full_lsq;
logic empty_lsq;
logic flush_to_lsq;
logic read_head_sq;
lsq_interface_t instruction_to_dcache;
lsq_interface_t stored_instr_to_dcache;


// State machine variables

logic [1:0] state;
logic [1:0] next_state;

// Possible states of the control automata
parameter ResetState  = 2'b00,
          ReadHead = 2'b01,
          WaitResponse = 2'b10;


///////////////////////////////////////////////////////////////////////////////
///// LOAD STORE QUEUE
///////////////////////////////////////////////////////////////////////////////

assign flush_to_lsq = kill_i | flush_i;

load_store_queue load_store_queue_inst (
    .clk_i (clk_i),               
    .rstn_i (rstn_i),
    .instruction_i(interface_i),                  
    .flush_i (flush_to_lsq),
    .read_head_i (read_head_sq),
    .instruction_o(instruction_to_dcache),                  
    .ls_queue_entry_o(ls_queue_entry_o),        
    .full_o(full_lsq),
    .empty_o(empty_lsq)
);

///////////////////////////////////////////////////////////////////////////////
///// MSHR invert index
///////////////////////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////////////////////////
///// State machine
///////////////////////////////////////////////////////////////////////////////


// Update State
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i)
        state <= ResetState;
    else
        state <= next_state;
end

// Update State
always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        stored_instr_to_dcache.valid <= 1'b0;
        stored_instr_to_dcache.addr <= 40'h0;
        stored_instr_to_dcache.data <= 64'h0;
        stored_instr_to_dcache.instr_type <= ADD;
        stored_instr_to_dcache.mem_op <= MEM_LOAD;
        stored_instr_to_dcache.funct3 <= 3'h0;
        stored_instr_to_dcache.rd <= 5'h0;
    end else
        if (instruction_to_dcache.valid)
            stored_instr_to_dcache <= instruction_to_dcache;
end

// Mealy Output and Nexy State
always_comb begin
    case(state)
        // Reset state
        ResetState: begin
            valid_o = 1'b0;              // Invalid instruction
            data_rs1_o = 40'h0;
            data_rs2_o = 64'h0;
            instr_type_o = ADD;
            mem_op_o = MEM_LOAD;
            funct3_o = 3'h0;
            rd_o = 5'h0;
            next_state = ReadHead;        // Next state Read Head
            read_head_sq = 1'b1;          // Read head of LSQ
        end
        // Read head of LSQ
        ReadHead: begin
            if (kill_i) begin
                valid_o = 1'b0;              // Invalid instruction
                data_rs1_o = 40'h0;
                data_rs2_o = 64'h0;
                instr_type_o = ADD;
                mem_op_o = MEM_LOAD;
                funct3_o = 3'h0;
                rd_o = 5'h0;
                next_state = ReadHead;        // Next state Read Head
                read_head_sq = 1'b1;          // Read head of LSQ           
            end else begin
                valid_o = instruction_to_dcache.valid;
                data_rs1_o = instruction_to_dcache.addr;
                data_rs2_o = instruction_to_dcache.data;
                instr_type_o = instruction_to_dcache.instr_type;
                mem_op_o = instruction_to_dcache.mem_op;
                funct3_o = instruction_to_dcache.funct3;
                rd_o = instruction_to_dcache.rd;
                next_state = (instruction_to_dcache.valid) ?  WaitResponse : ReadHead;
                read_head_sq = ~instruction_to_dcache.valid;     // If valid do not read new head
            end
        end
        // Waiting response of Dcache interface
        WaitResponse: begin
            if (kill_i) begin
                valid_o = 1'b0;              // Invalid instruction
                data_rs1_o = 40'h0;
                data_rs2_o = 64'h0;
                instr_type_o = ADD;
                mem_op_o = MEM_LOAD;
                funct3_o = 3'h0;
                rd_o = 5'h0;
                next_state = ReadHead;        // Next state Read Head
                read_head_sq = 1'b1;          // Read head of LSQ  
            end else begin
                valid_o = stored_instr_to_dcache.valid;
                data_rs1_o = stored_instr_to_dcache.addr;
                data_rs2_o = stored_instr_to_dcache.data;
                instr_type_o = stored_instr_to_dcache.instr_type;
                mem_op_o = stored_instr_to_dcache.mem_op;
                funct3_o = stored_instr_to_dcache.funct3;
                rd_o = stored_instr_to_dcache.rd;
                if (lock_i) begin
                    next_state = WaitResponse;
                    read_head_sq = 1'b0; 
                end else begin
                    next_state = ReadHead;
                    read_head_sq = 1'b1; 
                end
            end
        end
        default: begin
            `ifdef ASSERTIONS
                assert(1 == 0);
            `endif
            next_state = ResetState;
        end
    endcase
end

///////////////////////////////////////////////////////////////////////////////
///// Outputs
///////////////////////////////////////////////////////////////////////////////

// TODO: FIX this interface with dcache

assign imm_o = 64'h0;


assign lock_o   = full_lsq;
assign ready_o  = ready_i;
assign data_o   = data_i;

endmodule
