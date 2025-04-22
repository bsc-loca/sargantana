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
    input logic         en_ld_st_translation_i, // Virtualization enable

    // DCACHE Answer
    input  logic        dmem_resp_replay_i,  // Miss ready
    input  bus_simd_t   dmem_resp_data_i,    // Readed data from Cache
    input  logic        dmem_req_ready_i,    // Dcache ready to accept request
    input  logic        dmem_resp_valid_i,   // Response is valid
    input  logic [7:0]  dmem_resp_tag_i,     // Tag 
    input  logic        dmem_resp_nack_i,    // Cache request not accepted
    input  logic        dmem_resp_has_data_i,// Dcache response contains data
    input  logic        dmem_xcpt_ma_st_i,   // Missaligned store
    input  logic        dmem_xcpt_ma_ld_i,   // Missaligned load
    input  logic        dmem_xcpt_pf_st_i,   // DTLB miss on store
    input  logic        dmem_xcpt_pf_ld_i,   // DTLB miss on load
    input  logic        dmem_ordered_i,

    // Request TO DCACHE

    output logic        dmem_req_valid_o,    // Sending valid request
    output logic [4:0]  dmem_req_cmd_o,      // Type of memory access
    output addr_t       dmem_req_addr_o,     // Address of memory access
    output logic [3:0]  dmem_op_type_o,      // Granularity of memory access
    output bus_simd_t   dmem_req_data_o,     // Data to store
    output logic [7:0]  dmem_req_tag_o,      // Tag for the MSHR
    output logic        dmem_req_invalidate_lr_o, // Reset load-reserved/store-conditional
    output logic        dmem_req_kill_o,     // Kill actual memory access

    // DCACHE Answer to WB
    output resp_dcache_cpu_t resp_dcache_cpu_o, // Dcache to CPU

    // PMU
    output logic dmem_is_store_o,
    output logic dmem_is_load_o
);

// Declarations of internal variables
logic mem_xcpt;
logic io_address_space;
logic kill_io_resp;   
logic kill_mem_ope;
/*logic [1:0] state;
logic [1:0] next_state;*/
bus64_t dmem_req_addr_64;

logic [1:0] type_of_op;

// registers of tlb exceptions to not propagate the stall signal
logic dmem_xcpt_ma_st_reg;
logic dmem_xcpt_ma_ld_reg; 
logic dmem_xcpt_pf_st_reg;
logic dmem_xcpt_pf_ld_reg;

// Possible states of the control automata
/*parameter ResetState  = 2'b00,
          Idle = 2'b01,
          MakeRequest = 2'b10,
          WaitResponse = 2'b11;*/

parameter MEM_NOP   = 3'b00,
          MEM_LOAD  = 3'b01,
          MEM_STORE = 3'b10,
          MEM_AMO   = 3'b11;

//-------------------------------------------------------------
// CONTROL SIGNALS
//-------------------------------------------------------------

// There has been a memory exception
assign mem_xcpt = dmem_xcpt_ma_st_i | dmem_xcpt_ma_ld_i | dmem_xcpt_pf_st_i | dmem_xcpt_pf_ld_i;

// The address is in the INPUT/OUTPUT space
assign io_address_space = (dmem_req_addr_o >= req_cpu_dcache_i.io_base_addr) && (dmem_req_addr_o < 40'h80000000) && !en_ld_st_translation_i;

// There has been a exception
assign kill_mem_ope = mem_xcpt | req_cpu_dcache_i.kill;

/////////////////////////////////////////////////////////////////////

//-------------------------------------------------------------
// STATE MACHINE LOGIC
//-------------------------------------------------------------

assign dmem_req_valid_o = req_cpu_dcache_i.valid; 


// Decide type of memory operation
always_comb begin
    type_of_op = MEM_NOP;
    case(req_cpu_dcache_i.instr_type)
        AMO_LRW,AMO_LRD:         begin
                                    dmem_req_cmd_o = 5'b00110; // lr
                                    type_of_op = MEM_AMO;
        end
        AMO_SCW,AMO_SCD:         begin
                                    dmem_req_cmd_o = 5'b00111; // sc
                                    type_of_op = MEM_AMO;
        end
        AMO_SWAPW,AMO_SWAPD:     begin
                                    dmem_req_cmd_o = 5'b00100; // amoswap
                                    type_of_op = MEM_AMO;
        end
        AMO_ADDW,AMO_ADDD:       begin
                                    dmem_req_cmd_o = 5'b01000; // amoadd
                                    type_of_op = MEM_AMO;
        end
        AMO_XORW,AMO_XORD:       begin
                                    dmem_req_cmd_o = 5'b01001; // amoxor
                                    type_of_op = MEM_AMO;
        end
        AMO_ANDW,AMO_ANDD:       begin
                                    dmem_req_cmd_o = 5'b01011; // amoand
                                    type_of_op = MEM_AMO;
        end
        AMO_ORW,AMO_ORD:         begin
                                    dmem_req_cmd_o = 5'b01010; // amoor
                                    type_of_op = MEM_AMO;
        end
        AMO_MINW,AMO_MIND:       begin
                                    dmem_req_cmd_o = 5'b01100; // amomin
                                    type_of_op = MEM_AMO;
        end
        AMO_MAXW,AMO_MAXD:       begin
                                    dmem_req_cmd_o = 5'b01101; // amomax
                                    type_of_op = MEM_AMO;
        end
        AMO_MINWU,AMO_MINDU:     begin
                                    dmem_req_cmd_o = 5'b01110; // amominu
                                    type_of_op = MEM_AMO;
        end
        AMO_MAXWU,AMO_MAXDU:     begin  
                                    dmem_req_cmd_o = 5'b01111; // amomaxu
                                    type_of_op = MEM_AMO;
        end
        LD,LW,LWU,LH,LHU,LB,LBU,VLE,FLD,FLW: begin
                                    dmem_req_cmd_o = 5'b00000; // Load
                                    type_of_op = MEM_LOAD;
        end
        SD,SW,SH,SB,VSE,FSW,FSD: begin
                                    dmem_req_cmd_o = 5'b00001; // Store
                                    type_of_op = MEM_STORE;
        end
        default: begin
                                    dmem_req_cmd_o = 5'b00000;
                                    `ifdef ASSERTIONS
                                        // DOES NOT NEED ASSERTION
                                    `endif
        end
    endcase
end

// Address calculation
assign dmem_req_addr_64 =  req_cpu_dcache_i.data_rs1;
assign dmem_req_addr_o = dmem_req_addr_64[39:0];

// Granularity of mem. access. (BYTE, HALFWORD, WORD, DOUBLEWORD, QUADWORD)
assign dmem_op_type_o = req_cpu_dcache_i.mem_size;

// Data to store if needed
assign dmem_req_data_o = req_cpu_dcache_i.data_rs2;

// TAG for MSHR. Identifies a MEMORY access
assign dmem_req_tag_o = {1'b0,req_cpu_dcache_i.rd};

// Reset load-reserved/store-conditional 
assign dmem_req_invalidate_lr_o = req_cpu_dcache_i.kill;

// Kill actual memory operation                       
assign dmem_req_kill_o = mem_xcpt | req_cpu_dcache_i.kill;

// Dcache interface to CPU 
assign resp_dcache_cpu_o.valid = dmem_resp_valid_i;
assign resp_dcache_cpu_o.replay = dmem_resp_replay_i;
assign resp_dcache_cpu_o.ready = dmem_req_ready_i;
assign resp_dcache_cpu_o.nack = dmem_resp_nack_i;
assign resp_dcache_cpu_o.has_data = dmem_resp_has_data_i;
assign resp_dcache_cpu_o.io_address_space = io_address_space;
assign resp_dcache_cpu_o.rd = dmem_resp_tag_i;

// Readed data from load
assign resp_dcache_cpu_o.data = dmem_resp_data_i;

// Fill exceptions for exe stage
assign resp_dcache_cpu_o.xcpt_ma_st = dmem_xcpt_ma_st_i;
assign resp_dcache_cpu_o.xcpt_ma_ld = dmem_xcpt_ma_ld_i;
assign resp_dcache_cpu_o.xcpt_pf_st = dmem_xcpt_pf_st_i;
assign resp_dcache_cpu_o.xcpt_pf_ld = dmem_xcpt_pf_ld_i;
assign resp_dcache_cpu_o.addr = dmem_req_addr_64;
assign resp_dcache_cpu_o.ordered = dmem_ordered_i;

//-PMU
assign dmem_is_store_o = (type_of_op == MEM_STORE) && dmem_req_valid_o;
assign dmem_is_load_o  = (type_of_op == MEM_LOAD) && dmem_req_valid_o;

endmodule
//`default_nettype wire

