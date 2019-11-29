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

module dcache_interface (
    input  wire         clk_i,               // Clock
    input  wire         rstn_i,              // Negative Reset Signal

    input req_cpu_dcache_t req_cpu_dcache_i, // Interface with cpu

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
    output resp_dcache_cpu_t resp_dcache_cpu_o // Dcache to CPU
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
assign io_address_space = (dmem_req_addr_o >= req_cpu_dcache_i.io_base_addr) & (dmem_req_addr_o <= 40'h80020053);

//////////////////////////////////////////////////////////////////////
// For clarity we have two kill signals. There are two possible cases
//////////////////////////////////////////////////////////////////////

// Address is in INPUT/OUTPUT space
assign kill_io_resp =  io_address_space & (req_cpu_dcache_i.mem_op == MEM_STORE);

// There has been a exception
assign kill_mem_ope = mem_xcpt | req_cpu_dcache_i.kill;

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
            resp_dcache_cpu_o.lock = 1'b0;            // NOT busy
            next_state = Idle;        // Next state IDLE
        end
        // IN IDLE STATE
        Idle: begin
            dmem_req_valid_o = !req_cpu_dcache_i.kill & req_cpu_dcache_i.valid & dmem_req_ready_i;
            resp_dcache_cpu_o.lock = !req_cpu_dcache_i.kill & req_cpu_dcache_i.valid;
            next_state = dmem_req_valid_o ?  MakeRequest : Idle;
        end
        // IN MAKE REQUEST STATE
        MakeRequest: begin
            if(dmem_resp_valid_i & dmem_req_ready_i) begin // case: io response uart
                dmem_req_valid_o = 1'b0;
                resp_dcache_cpu_o.lock = 1'b0;
                next_state = Idle;
            end else begin
                dmem_req_valid_o = 1'b0;
                resp_dcache_cpu_o.lock = !kill_mem_ope;
                next_state = (!kill_mem_ope) ? WaitResponse : Idle;
            end
        end
        // IN WAIT RESPONSE STATE
        WaitResponse: begin
            if(dmem_resp_valid_i) begin
                dmem_req_valid_o = 1'b0;
                next_state = Idle;
                resp_dcache_cpu_o.lock = 1'b0;
            end else if(dmem_resp_nack_i) begin
                dmem_req_valid_o = 1'b0;
                next_state = Idle;
                resp_dcache_cpu_o.lock = 1'b1;
            end else begin
                dmem_req_valid_o = 1'b0;
                next_state = (kill_mem_ope | kill_io_resp) ? Idle : WaitResponse;
                resp_dcache_cpu_o.lock = !(kill_mem_ope | kill_io_resp);
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
    case(req_cpu_dcache_i.instr_type)
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
assign dmem_req_addr_o = (req_cpu_dcache_i.mem_op == MEM_AMO) ? req_cpu_dcache_i.data_rs1[39:0] : req_cpu_dcache_i.data_rs1[39:0] + req_cpu_dcache_i.imm[39:0];

// Granularity of mem. access. (BYTE, HALFWORD, WORD)
assign dmem_op_type_o = {1'b0,req_cpu_dcache_i.funct3};

// Data to store if needed
assign dmem_req_data_o = req_cpu_dcache_i.data_rs2;

// TAG for MSHR. Identifies a MEMORY access
assign dmem_req_tag_o = {2'b00,req_cpu_dcache_i.rd,1'b0};

// Reset load-reserved/store-conditional 
assign dmem_req_invalidate_lr_o = req_cpu_dcache_i.kill;

// Kill actual memory operation                       
assign dmem_req_kill_o = mem_xcpt | req_cpu_dcache_i.kill;

// Dcache interface is ready
assign resp_dcache_cpu_o.ready = dmem_resp_valid_i & (req_cpu_dcache_i.mem_op != MEM_STORE);

// Readed data from load
assign resp_dcache_cpu_o.data = dmem_resp_data_i;

endmodule
//`default_nettype wire

