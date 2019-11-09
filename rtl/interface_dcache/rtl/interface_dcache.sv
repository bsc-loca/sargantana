//`default_nettype none
//`include "drac_pkg.sv"
import drac_pkg::*;

/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : mem_unit.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Rubén Langarita
 * Email(s)       : ruben.langarita@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author     | Description
 *  0.1        | Ruben. L   |
 *  0.2        | Victor. SP | Improve Doc. and pass tb
 * -----------------------------------------------
 */
 
// Interface with Data Cache. Stores a Memory request until it finishes

module interface_dcache (
    input  wire         clk_i,               // Clock
    input  wire         rstn_i,              // Negative Reset Signal

    input logic         valid_i,             // New memory request
    input logic         kill_i,              // Exception detected at Commit
    input logic         csr_eret_i,          // Exception from CSR Register File
    input bus64_t       data_rs1_i,          // Data operand 1
    input bus64_t       data_rs2_i,          // Data operand 2
    input instr_type_t  instr_type_i,        // Type of instruction
    input mem_op_t      mem_op_i,            // Type of memory access
    input logic [2:0]   funct3_i,            // Granularity of mem. access
    input reg_t         rd_i,                // Destination register. Used for identify a pending Miss
    input bus64_t       imm_i,               // Inmmediate 

    input  addr_t       io_base_addr_i,      // Address Base Pointer of INPUT/OUPUT

    // DCACHE Answer
    input  logic        dmem_resp_replay_i,  // Miss ready
    input  bus64_t      dmem_resp_data_i,    // Readed data from Cache
    input  logic        dmem_req_ready_i,    // Dcache ready to accept request
    input  logic        dmem_resp_valid_i,   // Response is valid
    input  logic        dmem_resp_nack_i,    // Cache request not accepted
    input  logic        dmem_xcpt_ma_st_i,   // Missaligned store
    input  logic        dmem_xcpt_ma_ld_i,   // Missaligned load
    input  logic        dmem_xcpt_pf_st_i,   // DTLB miss on store
    input  logic        dmem_xcpt_pf_ld_i,   // DTLB miss on load

    // Request TO DCACHE

    output logic        dmem_req_valid_o,    // Sending valid request
    output logic [4:0]  dmem_req_cmd_o,      // Type of memory access
    output addr_t       dmem_req_addr_o,     // Address of memory access
    output logic [3:0]  dmem_op_type_o,      // Granularity of memory access
    output bus64_t      dmem_req_data_o,     // Data to store
    output logic [7:0]  dmem_req_tag_o,      // Tag for the MSHR
    output logic        dmem_req_invalidate_lr_o, // Reset load-reserved/store-conditional
    output logic        dmem_req_kill_o,     // Kill actual memory access

    // DCACHE Answer to WB
    output logic        ready_o,             // Dcache_interface ready to accept mem. access
    output bus64_t      data_o,              // Data from load
    output logic        lock_o               // Dcache cannot accept more mem. accesses
);

// Declarations of internal variables
logic mem_xcpt;
logic io_address_space;
logic kill_io_resp;   
logic kill_mem_ope;
logic [1:0] state;
logic [1:0] next_state;

// Possible states of the control automata
parameter ResetState  = 2'b00,
          Idle = 2'b01,
          MakeRequest = 2'b10,
          WaitResponse = 2'b11;


//-------------------------------------------------------------
// CONTROL SIGNALS
//-------------------------------------------------------------

// There has been a memory exception
assign mem_xcpt = dmem_xcpt_ma_st_i | dmem_xcpt_ma_ld_i | dmem_xcpt_pf_st_i | dmem_xcpt_pf_ld_i;

// The address is in the INPUT/OUTPUT space
//TODO: Make next line parametric
assign io_address_space = (dmem_req_addr_o >= io_base_addr_i) & (dmem_req_addr_o <= 40'h80020053);

//////////////////////////////////////////////////////////////////////
// For clarity we have two kill signals. There are two possible cases
//////////////////////////////////////////////////////////////////////

// Address is in INPUT/OUTPUT space
assign kill_io_resp =  io_address_space & (mem_op_i == MEM_STORE);

// There has been a exception
assign kill_mem_ope = mem_xcpt | kill_i;

/////////////////////////////////////////////////////////////////////

//-------------------------------------------------------------
// STATE MACHINE LOGIC
//-------------------------------------------------------------

// UPDATE STATE
always@(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i)
        state = ResetState;
    else
        state = next_state;
end

// MEALY OUTPUT and NEXT STATE
always_comb begin
    case(state)
        // IN RESET STATE
        ResetState: begin
            dmem_req_valid_o = 1'b0;  // NO request
            lock_o = 1'b0;            // NOT busy
            next_state = Idle;        // Next state IDLE
        end
        // IN IDLE STATE
        Idle: begin
            dmem_req_valid_o = !kill_i & valid_i & dmem_req_ready_i;
            lock_o = !kill_i & valid_i;
            next_state = dmem_req_valid_o ?  MakeRequest : Idle;
        end
        // IN MAKE REQUEST STATE
        MakeRequest: begin
            if(dmem_resp_valid_i & dmem_req_ready_i) begin // case: io response uart
                dmem_req_valid_o = 1'b0;
                lock_o = 1'b0;
                next_state = Idle;
            end else begin
                dmem_req_valid_o = 1'b0;
                lock_o = !kill_mem_ope;
                next_state = (!kill_mem_ope & dmem_req_ready_i) ? WaitResponse : Idle;
            end
        end
        // IN WAIT RESPONSE STATE
        WaitResponse: begin
            if(dmem_resp_valid_i) begin
                dmem_req_valid_o = 1'b0;
                next_state = Idle;
                lock_o = 1'b0;
            end else if(dmem_resp_nack_i) begin
                dmem_req_valid_o = 1'b0;
                next_state = Idle;
                lock_o = 1'b1;
            end else begin
                dmem_req_valid_o = 1'b0;
                next_state = (kill_mem_ope | kill_io_resp) ? Idle : WaitResponse;
                lock_o = !(kill_mem_ope | kill_io_resp);
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

// Decide type of memory operation
always_comb begin
    case(instr_type_i)
        AMO_LRW,AMO_LRD:            dmem_req_cmd_o = 5'b00110; // lr
        AMO_SCW,AMO_SCD:            dmem_req_cmd_o = 5'b00111; // sc
        AMO_SWAPW,AMO_SWAPD:        dmem_req_cmd_o = 5'b00100; // amoswap
        AMO_ADDW,AMO_ADDD:          dmem_req_cmd_o = 5'b01000; // amoadd
        AMO_XORW,AMO_XORD:          dmem_req_cmd_o = 5'b01001; // amoxor
        AMO_ANDW,AMO_ANDD:          dmem_req_cmd_o = 5'b01011; // amoand
        AMO_ORW,AMO_ORD:            dmem_req_cmd_o = 5'b01010; // amoor
        AMO_MINW,AMO_MIND:          dmem_req_cmd_o = 5'b01100; // amomin
        AMO_MAXW,AMO_MAXD:          dmem_req_cmd_o = 5'b01101; // amomax
        AMO_MINWU,AMO_MINDU:        dmem_req_cmd_o = 5'b01110; // amominu
        AMO_MAXWU,AMO_MAXDU:        dmem_req_cmd_o = 5'b01111; // amomaxu
        LD,LW,LWU,LH,LHU,LB,LBU:    dmem_req_cmd_o = 5'b00000; // Load
        SD,SW,SH,SB:                dmem_req_cmd_o = 5'b00001; // Store
        default: begin
                                    dmem_req_cmd_o = 5'b00000;
                                    `ifdef ASSERTIONS
                                        // DOES NOT NEED ASSERTION
                                    `endif
        end
    endcase
end

// Address calculation
// TODO: IS NOT REALIST TO DO ADDRESS CALCULATION HERE. IT SHOULD TAKE ONE CYCLE. FOR 50MHZ IS OK.
assign dmem_req_addr_o = (mem_op_i == MEM_AMO) ? data_rs1_i[39:0] : data_rs1_i[39:0] + imm_i[39:0];

// Granularity of mem. access. (BYTE, HALFWORD, WORD)
assign dmem_op_type_o = {1'b0,funct3_i};

// Data to store if needed
assign dmem_req_data_o = data_rs2_i;

// TAG for MSHR. Identifies a MEMORY access
assign dmem_req_tag_o = {2'b00,rd_i,1'b0};

// Reset load-reserved/store-conditional 
assign dmem_req_invalidate_lr_o = kill_i;

// Kill actual memory operation                        //TODO: Check if the third condition is necessary
assign dmem_req_kill_o = mem_xcpt | kill_i  | (dmem_resp_replay_i & valid_i);

// Dcache interface is ready
assign ready_o = dmem_resp_valid_i & (mem_op_i != MEM_STORE);

// Readed data from load
assign data_o = dmem_resp_data_i;

endmodule
//`default_nettype wire

