/* -----------------------------------------------
* Project Name   : DRAC
* File           : tb_icache_interface.v
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Guillem Lopez Paradis
* Email(s)       : guillem.lopez@bsc.es
* References     : 
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Guillem.LP | 
* -----------------------------------------------
*/

import drac_pkg::*;
import riscv_pkg::*;

module icache_interface(
  	input logic              clk_i,
  	input logic              rstn_i,

    // Fetch stage interface - Request packet from fetch_stage
  	input req_cpu_icache_t   req_fetch_icache_i,

    // Request input signals from ICache
    input icache_line_t      icache_resp_datablock_i, // ICACHE_RESP_BITS_DATABLOCK
    input logic	             icache_resp_valid_i, // ICACHE_RESP_VALID,
    input logic              ptw_invalidate_i, // PTWINVALIDATE,
    input logic              tlb_resp_miss_i, // TLB_RESP_MISS,
    input logic              tlb_resp_xcp_if_i, // TLB_RESP_XCPT_IF,
    
    output logic             icache_invalidate_o, // ICACHE_INVALIDATE
    output icache_idx_t	     icache_req_bits_idx_o, // ICACHE_REQ_BITS_IDX,
    output logic             icache_req_kill_o, // ICACHE_REQ_BITS_KILL,
    output reg               icache_req_valid_o, // ICACHE_REQ_VALID,
    output reg               icache_resp_ready_o, // ICACHE_RESP_READY,
    output icache_vpn_t      tlb_req_bits_vpn_o, // TLB_REQ_BITS_VPN,
    output logic             tlb_req_valid_o, // TLB_REQ_VALID
    
    // Fetch stage interface - Request packet icache to fetch
	output req_icache_cpu_t  req_icache_fetch_o
);

icache_line_reg_t icache_line_reg_q, icache_line_reg_d;
icache_line_t icache_line_int;
reg_addr_t pc_buffer_d, pc_buffer_q;
reg valid_buffer_q,valid_buffer_d;
logic buffer_diff_int;
// wire that says if we need to access icache
logic icache_access_needed_int;
// internal wire to select the correct bits 
//inst_t inst_out_int;
//Internal wire to say if there is a misaligned fetch
logic misaligned_fetch_ex_int;
//Internal wire to say if there is a buffer miss
logic buffer_miss_int;
// Exception in the fetch: misaligned or fault fetch
exception_t fetch_ex_int;
// FSM icache
icache_state_t state_int, next_state_int;

// Sequential procedure to update state
always_ff @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        state_int <= ResetState;
    end else begin
        state_int <= next_state_int;
    end
end

// Combinational logic to update next_state_int
always_comb begin
    case (state_int)
        ResetState: begin
            next_state_int = NoReq;
            icache_req_valid_o = 1'b0;
            icache_resp_ready_o = 1'b0;
            req_icache_fetch_o.valid = 1'b0;
        end
        NoReq: begin
            // If req from fetch valid change state_int to REQ VALID
            next_state_int = (icache_access_needed_int) ? ReqValid : NoReq;
            icache_req_valid_o = icache_access_needed_int;
            icache_resp_ready_o = 1'b0;
            req_icache_fetch_o.valid = !buffer_miss_int & !tlb_resp_xcp_if_i;
            
        end
        ReqValid: begin
            next_state_int = (icache_resp_valid_i) ? RespReady : ReqValid;
            icache_req_valid_o = 1'b0;
            icache_resp_ready_o = 1'b1;
            req_icache_fetch_o.valid = icache_resp_valid_i & !tlb_resp_xcp_if_i;
            
        end
        RespReady:begin
            next_state_int = (icache_access_needed_int) ? ReqValid : NoReq;
            icache_req_valid_o = icache_access_needed_int;
            icache_resp_ready_o = 1'b0;
            req_icache_fetch_o.valid = !buffer_miss_int & !tlb_resp_xcp_if_i;
            
        end 
        default: begin
            next_state_int =  ResetState;
            icache_req_valid_o = 1'b0;
            icache_resp_ready_o = 1'b0;
            req_icache_fetch_o.valid = 1'b0;
        end
    endcase;
end
// We need and access when:
//    - there is a new request that is not
//    misaligned and ther is a miss buffer
assign icache_access_needed_int =   req_fetch_icache_i.valid & 
                                    buffer_miss_int & 
                                    !misaligned_fetch_ex_int;
// Icache output connections
// TODO:(guillemlp) what is invalidate?
assign icache_invalidate_o = 1'b0;
// Connect vaddr to the corresponding tlb and idx
assign tlb_req_bits_vpn_o = req_fetch_icache_i.vaddr[39:12];
assign icache_req_bits_idx_o = req_fetch_icache_i.vaddr[11:0];

// TODO I am not sure when to activate this 
assign icache_req_kill_o = 1'b0;
// TODO (guillemlp) I actually don't know what is this tlb valid
assign tlb_req_valid_o = icache_req_valid_o;

// assign req_icache_fetch_o.data =;
// TODO make a register
//assign req_icache_fetch_o.req_addr = 40'b0;

// TODO fix and add fetch misaligned
// Assign if there is any exception
//assign req_icache_fetch_o.ex.cause = (tlb_resp_xcp_if_i) ? FAULT_FETCH : NONE;
//assign req_icache_fetch_o.ex.origin = req_fetch_icache_i.vaddr;
//assign req_icache_fetch_o.ex.valid = fetch_ex_int.valid;
// Exceptions handling
assign req_icache_fetch_o.ex = fetch_ex_int;

assign fetch_ex_int.valid = misaligned_fetch_ex_int | tlb_resp_xcp_if_i;
assign fetch_ex_int.origin = {24'b0,req_fetch_icache_i.vaddr};
// Assign whether it is a misaligned, fault fetch or none
assign fetch_ex_int.cause = (misaligned_fetch_ex_int) ? INSTR_ADDR_MISALIGNED : 
                            (tlb_resp_xcp_if_i) ? INSTR_ACCESS_FAULT : NONE;

// whether there is a misaligned fetch
assign misaligned_fetch_ex_int =   (req_fetch_icache_i.vaddr[1] | 
                                    req_fetch_icache_i.vaddr[0]) &
                                    req_fetch_icache_i.valid;

//assign fetch_ex_int.valid = misaligned_fetch_ex_int | tlb_resp_xcp_if_i;
//assign fetch_ex_int.origin = req_fetch_icache_i.vaddr;
// Assign whether it is a misaligned, fault fetch or none
//assign fetch_ex_int.cause = (misaligned_fetch_ex_int) ? INSTR_ADDR_MISALIGNED : 
//                            (tlb_resp_xcp_if_i) ? INSTR_ACCESS_FAULT : NONE; 

// sequential logic cacheline register buffer
// TODO manage invalidations etc...
always_ff @(posedge clk_i, negedge rstn_i, posedge icache_resp_valid_i) begin
    if(!rstn_i) begin
        icache_line_reg_q <= 128'b0;
        valid_buffer_q <= 1'b0;
    end else begin // if (icache_resp_valid_i) begin
        icache_line_reg_q <= icache_line_int;
        valid_buffer_q <= valid_buffer_d;
    end
end

always_comb begin
    //icache_line_req_d = (icache_line_int) icache_line_reg_q | icache_resp_valid_i;
    //valid_buffer_d = valid_buffer_q | (icache_resp_valid_i && state_int==RespReady);
    valid_buffer_d = valid_buffer_q | icache_resp_valid_i;
end

// Manage the pc_int_register
always_ff @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        pc_buffer_q <= {ADDR_SIZE{1'b0}};
    end else begin
        pc_buffer_q <= pc_buffer_d;
    end
end

// Multiplexor to select the correct cacheline
assign icache_line_int = (icache_resp_valid_i) ? icache_resp_datablock_i : icache_line_reg_q;

// It is a miss on the datablock buffered
// We check for all the address if there is the need to access the TLB
// don't speculate

assign pc_buffer_d = (icache_resp_valid_i) ? req_fetch_icache_i.vaddr : pc_buffer_q; 

assign buffer_diff_int = (pc_buffer_q[ADDR_SIZE-1:4] != req_fetch_icache_i.vaddr[ADDR_SIZE-1:4]);

assign buffer_miss_int = !valid_buffer_q | 
                         (valid_buffer_q & buffer_diff_int);

// return the datablock asked
always_comb begin
    case(req_fetch_icache_i.vaddr[3:2])
        2'b00: begin
            req_icache_fetch_o.data = icache_line_int[31:0];
        end
        2'b01: begin
            req_icache_fetch_o.data = icache_line_int[63:32]; 
        end
        2'b10: begin
            req_icache_fetch_o.data = icache_line_int[95:64]; 
        end
        2'b11: begin
            req_icache_fetch_o.data = icache_line_int[127:96]; 
        end
        default: begin
            req_icache_fetch_o.data = 32'h0;
        end
    endcase
end

endmodule
