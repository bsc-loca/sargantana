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
    input addr_t             icache_resp_vaddr_i, // ICACHE_RESP_BITS_VADDR
    input logic              icache_resp_valid_i, // ICACHE_RESP_VALID,
    input logic              icache_req_ready_i, // ICACHE_REQ_READY,
    input logic              iptw_resp_valid_i,
    input logic              ptw_invalidate_i, // PTWINVALIDATE,
    input logic              tlb_resp_miss_i, // TLB_RESP_MISS,
    input logic              tlb_resp_xcp_if_i, // TLB_RESP_XCPT_IF,
    // Request output signals to Icache
    output logic             icache_invalidate_o, // ICACHE_INVALIDATE
    output icache_idx_t      icache_req_bits_idx_o, // ICACHE_REQ_BITS_IDX,
    output logic             icache_req_kill_o, // ICACHE_REQ_BITS_KILL,
    output reg               icache_req_valid_o, // ICACHE_REQ_VALID,
    output reg               icache_resp_ready_o, // ICACHE_RESP_READY,
    output icache_vpn_t      icache_req_bits_vpn_o, // ICACHE_REQ_BITS_VPN,
    output icache_vpn_t      tlb_req_bits_vpn_o, // TLB_REQ_BITS_VPN,
    output logic             tlb_req_valid_o, // TLB_REQ_VALID
    
    // Fetch stage interface - Request packet icache to fetch
    output resp_icache_cpu_t  resp_icache_fetch_o
);

icache_line_reg_t icache_line_reg_q, icache_line_reg_d;
icache_line_t icache_line_int;
reg_addr_t pc_buffer_d, pc_buffer_q;
// pc requested on the last cycle
reg_addr_t old_pc_req_d, old_pc_req_q;
reg valid_buffer_q,valid_buffer_d;

logic buffer_diff_int;
// wire that says if we need to access icache
logic icache_access_needed_int;


//Internal wire to say if there is a buffer miss
logic buffer_miss_int;

// FSM icache
icache_state_t state_int, next_state_int;

// Sequential procedure to update state
always_ff @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        state_int <= NoReq;
    end else begin
        state_int <= next_state_int;
    end
end

// Combinational logic to update next_state_int
assign icache_resp_ready_o = 1'b1;

always_comb begin
    case (state_int)
        TLBMiss: begin
            next_state_int = (req_fetch_icache_i.invalidate_buffer) ? (NoReq) : 
                             (iptw_resp_valid_i) ? (NoReq) :
                             (tlb_resp_miss_i) ? TLBMiss : 
                             NoReq;;
            icache_req_valid_o = 1'b0;
            resp_icache_fetch_o.valid = 1'b0;
        end
        NoReq: begin
            // If req from fetch valid change state_int to REQ VALID
            next_state_int = (icache_access_needed_int & (~req_fetch_icache_i.invalidate_buffer) & icache_req_ready_i & !iptw_resp_valid_i) ? ReqValid : NoReq;
            icache_req_valid_o = icache_access_needed_int & icache_req_ready_i;
            resp_icache_fetch_o.valid = !buffer_miss_int  | tlb_resp_xcp_if_i /*& !tlb_resp_xcp_if_i*/;
            
        end
        ReqValid: begin
            if (old_pc_req_q[ADDR_SIZE-1:4] != req_fetch_icache_i.vaddr[ADDR_SIZE-1:4]) begin
                next_state_int = (req_fetch_icache_i.invalidate_buffer) ? (NoReq) : 
                                 (iptw_resp_valid_i) ? (NoReq) :
                                 (tlb_resp_miss_i & icache_access_needed_int) ? TLBMiss :
                                 (icache_access_needed_int) ? ReqValid :
                                 NoReq;
                icache_req_valid_o = icache_access_needed_int;
                resp_icache_fetch_o.valid = (!buffer_miss_int &/*!tlb_resp_xcp_if_i &*/ !tlb_resp_miss_i) | tlb_resp_xcp_if_i;
            end else begin
                next_state_int = (req_fetch_icache_i.invalidate_buffer) ? (NoReq) :
                                 (iptw_resp_valid_i) ? (NoReq) :
                                 (tlb_resp_miss_i) ? TLBMiss :
                                 (icache_resp_valid_i & (icache_resp_vaddr_i[ADDR_SIZE-1:4] ==  req_fetch_icache_i.vaddr[ADDR_SIZE-1:4])) ? NoReq :
                                 (~icache_req_ready_i) ? Replay :
                                 ReqValid;
                icache_req_valid_o = 1'b0;
                // is valid if the data from the core is cvalid and no exceptions plus the address
                // of the data form the cache is the same as the address form the fetch
                resp_icache_fetch_o.valid = (icache_resp_valid_i & /*!tlb_resp_xcp_if_i &*/ !tlb_resp_miss_i &
                        (icache_resp_vaddr_i[ADDR_SIZE-1:4] ==  req_fetch_icache_i.vaddr[ADDR_SIZE-1:4])) | tlb_resp_xcp_if_i;
            end
        end
        Replay:begin
            if (old_pc_req_q[ADDR_SIZE-1:4] != req_fetch_icache_i.vaddr[ADDR_SIZE-1:4]) begin
                next_state_int = (req_fetch_icache_i.invalidate_buffer) ? (NoReq) : 
                                 (tlb_resp_miss_i & icache_access_needed_int) ? TLBMiss : 
                                 (icache_access_needed_int) ? ReqValid : 
                                 NoReq;
                icache_req_valid_o = icache_access_needed_int;
                resp_icache_fetch_o.valid = (!buffer_miss_int /*& !tlb_resp_xcp_if_i*/ & !tlb_resp_miss_i) | tlb_resp_xcp_if_i;
            end else begin
                next_state_int = (req_fetch_icache_i.invalidate_buffer) ? (NoReq) : 
                                 (tlb_resp_miss_i) ? TLBMiss :
                                 (icache_req_ready_i) ? ReqValid : 
                                 Replay;
                icache_req_valid_o = icache_req_ready_i;
                resp_icache_fetch_o.valid = (!buffer_miss_int /*& !tlb_resp_xcp_if_i*/ & !tlb_resp_miss_i) | tlb_resp_xcp_if_i;
            end
        end
        default: begin
            next_state_int =  NoReq;
            icache_req_valid_o = 1'b0;
            icache_resp_ready_o = 1'b1;
            resp_icache_fetch_o.valid = 1'b0;
        end
    endcase;
end
// We need and access when:
//    - there is a new request that is valid and
//      there is a miss buffer
assign icache_access_needed_int =   req_fetch_icache_i.valid & 
                                    buffer_miss_int;
// Icache output connections
// TODO:(guillemlp) what is invalidate?
// when we want to send invalidation of request?
assign icache_invalidate_o = req_fetch_icache_i.invalidate_icache;

// Connect vaddr to the corresponding tlb and idx
assign tlb_req_bits_vpn_o = req_fetch_icache_i.vaddr[39:12];
assign icache_req_bits_vpn_o = req_fetch_icache_i.vaddr[39:12];
assign icache_req_bits_idx_o = req_fetch_icache_i.vaddr[11:0];

// TODO (guillemlp) I am not sure when to activate this 
// when there is a tlb miss?
assign icache_req_kill_o = tlb_resp_miss_i | ptw_invalidate_i | tlb_resp_xcp_if_i;

// TODO (guillemlp) I actually don't know what is this tlb valid
assign tlb_req_valid_o = icache_req_valid_o;// & !req_fetch_icache_i.invalidate_icache;

//assign resp_icache_fetch_o.instr_addr_misaligned = misaligned_fetch_ex_int;
assign resp_icache_fetch_o.instr_access_fault = tlb_resp_xcp_if_i;
assign resp_icache_fetch_o.instr_page_fault = 1'b0;

// sequential logic cacheline register buffer
// TODO (guillemlp) manage invalidations etc...
always_ff @(posedge clk_i, negedge rstn_i) begin //, posedge icache_resp_valid_i
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
    valid_buffer_d = (valid_buffer_q | icache_resp_valid_i) & 
                    !(req_fetch_icache_i.invalidate_buffer) &
                    !(ptw_invalidate_i) &
                    !tlb_resp_miss_i;
end

// Manage the pc_int_register
always_ff @(posedge clk_i, negedge rstn_i) begin
    if (!rstn_i) begin
        pc_buffer_q <= {ADDR_SIZE{1'b0}};
        old_pc_req_q <= {ADDR_SIZE{1'b0}};
    end else begin
        pc_buffer_q <= pc_buffer_d;
        old_pc_req_q <= old_pc_req_d;
    end
end

// old pc is the pc of the last cycle
assign old_pc_req_d = req_fetch_icache_i.vaddr;

// Multiplexor to select the correct cacheline
assign icache_line_int = (icache_resp_valid_i & !tlb_resp_xcp_if_i & 
                    (icache_resp_vaddr_i[ADDR_SIZE-1:4] ==  req_fetch_icache_i.vaddr[ADDR_SIZE-1:4]))  
                    ? icache_resp_datablock_i : icache_line_reg_q;

// It is a miss on the datablock buffered
// We check for all the address if there is the need to access the TLB
// don't speculate
assign pc_buffer_d = (icache_resp_valid_i & !tlb_resp_xcp_if_i & !tlb_resp_miss_i & 
                    (icache_resp_vaddr_i[ADDR_SIZE-1:4] == req_fetch_icache_i.vaddr[ADDR_SIZE-1:4])) 
                    ? req_fetch_icache_i.vaddr : pc_buffer_q; 

// whether the buffer addr is different than the pc req
assign buffer_diff_int = valid_buffer_q & (pc_buffer_q[ADDR_SIZE-1:4] != req_fetch_icache_i.vaddr[ADDR_SIZE-1:4]);

// whether we don't have a valid buffer
//         or we have a different addr 
//         or we have an invalidate cache
assign buffer_miss_int = !valid_buffer_q | 
                         buffer_diff_int;

// return the datablock asked
always_comb begin
    if(tlb_resp_xcp_if_i) begin
        resp_icache_fetch_o.data = 32'h0;
    end else begin
        case(req_fetch_icache_i.vaddr[3:2])
            2'b00: begin
                resp_icache_fetch_o.data = icache_line_int[31:0];
            end
            2'b01: begin
                resp_icache_fetch_o.data = icache_line_int[63:32]; 
            end
            2'b10: begin
                resp_icache_fetch_o.data = icache_line_int[95:64]; 
            end
            2'b11: begin
                resp_icache_fetch_o.data = icache_line_int[127:96]; 
            end
            default: begin
                resp_icache_fetch_o.data = 32'h0;
            end
        endcase
    end
end

endmodule
