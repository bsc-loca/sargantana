/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : lagarto_ka_vagu.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Narcis Rodas Quiroga
 * Email(s)       : nrodaquiroga@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author     | Description
 *  0.1        | Narcis R   | 
 * -----------------------------------------------
 */

module vagu
    import riscv_pkg::*, drac_pkg::*;
#(
    parameter DCACHE_RESP_DATA_WIDTH = 128,
    parameter logic [6:0] DCACHE_RESP_MAXELEM = DCACHE_RESP_DATA_WIDTH >> 3,
    parameter MAX_VELEM = 2048,
    localparam DCACHE_RESP_DATA_LOG = $clog2(DCACHE_RESP_DATA_WIDTH),
    localparam MAX_VELEM_LOG = $clog2(MAX_VELEM)
)(
    input logic clk_i,                                      // System clock
    input logic rstn_i,                                     // System reset
    input rr_exe_mem_instr_t memp_instr_i,                  // Instruction struct from LSB
    input logic flush_i,                                    // End current operation and flush ovi mask buffer
    input logic stall_i,                                    // Stall current operation
    input logic ovi_mask_idx_valid_i,                       // VPU sends a valid mask
    input logic [(MAX_VELEM*9)-1:0] ovi_mask_idx_item_i,    // Mask sent by VPU
    input sew_t vsew_i,                                     // Vector element width (8, 16, 32, 64)
    input logic [2:0] mop_i,                                // Type of vector memory operation (unit-stride, strided, indexed)
    input logic [MAX_VELEM_LOG:0] vl_i,                     // Vector lenght (in elements)
    input logic [63:0] stride_i,                            // Address stride for strided operations
    input logic masked_op_i,                                // Instruction from LSB uses a mask (unit-stride or strided)
    input logic vstore_data_valid_i,                        // Store data from vector memory controller is valid
    input logic [DCACHE_RESP_DATA_WIDTH-1:0] vstore_data_i, // Data for vector store operations
    output logic stall_o,                                   // AGU busy with a vector memory operation
    output logic end_o,                                     // AGU finished generating requests for a vector memory operation
    output logic misalign_xcpt_o,                           // Current instruction has a misaligned access 
    output logic [DCACHE_RESP_DATA_LOG-3:0] velem_incr_o,   // Number of valid elements in a request
    output logic [10:0] velem_id_o,                         // ID of the lowest valid element in a request
    output logic [63:0] load_mask_o,                        // Mask of valid and non-masked elements in a request
    output rr_exe_mem_instr_t memp_instr_o                  // Instruction struct to memory pipeline (+ tag of the microoperation)
);

typedef enum logic [2:0] {
    SCALAR = 0,
    VL_UNIT = 1,
    VS_UNIT = 2,
    VL_STRIDED = 3,
    VS_STRIDED = 4,
    VL_INDEXED = 5,
    VS_INDEXED = 6
} req_vmem_ops_t;

function [6:0] trunc_8_7(input [7:0] val_in);
  trunc_8_7 = val_in[6:0];
endfunction

function [63:0] trunc_64_sum(input [64:0] val_in);
  trunc_64_sum = val_in[63:0];
endfunction

function [63:0] trunc_68_64(input [67:0] val_in);
  trunc_68_64 = val_in[63:0];
endfunction

function [DCACHE_RESP_DATA_LOG-3:0] trunc_velem_incr(input [DCACHE_RESP_DATA_LOG-2:0] val_in);
  trunc_velem_incr = val_in[DCACHE_RESP_DATA_LOG-3:0];
endfunction

function [DCACHE_RESP_DATA_LOG:0] trunc_dcachedatalog_shift3(input [DCACHE_RESP_DATA_LOG+3:0] val_in);
  trunc_dcachedatalog_shift3 = val_in[DCACHE_RESP_DATA_LOG:0];
endfunction

function [DCACHE_RESP_DATA_LOG:0] trunc_dcachedatalog_shift4(input [DCACHE_RESP_DATA_LOG+4:0] val_in);
  trunc_dcachedatalog_shift4 = val_in[DCACHE_RESP_DATA_LOG:0];
endfunction

function [DCACHE_RESP_DATA_LOG:0] trunc_dcachedatalog_shift5(input [DCACHE_RESP_DATA_LOG+5:0] val_in);
  trunc_dcachedatalog_shift5 = val_in[DCACHE_RESP_DATA_LOG:0];
endfunction

function [3:0] trunc_5_4(input [4:0] val_in);
  trunc_5_4 = val_in[3:0];
endfunction

function [63:0] trunc_70_64(input [69:0] val_in);
  trunc_70_64 = val_in[63:0];
endfunction

function [MAX_VELEM_LOG:0] trunc_max_velem_log_sum(input [MAX_VELEM_LOG+1:0] val_in);
  trunc_max_velem_log_sum = val_in[MAX_VELEM_LOG:0];
endfunction

function [DCACHE_RESP_DATA_LOG:0] padd_dcachedatalog_plus1(input [DCACHE_RESP_DATA_LOG-1:0] val_in);
  padd_dcachedatalog_plus1 = {1'b0, val_in};
endfunction

req_vmem_ops_t vmem_ops_state_d, vmem_ops_state_q;

bus64_t vaddr_d, vaddr_q, vaddr_incr;
logic [6:0] velem_incr, velem_off, velem_off_neg; // [DCACHE_RESP_DATA_LOG-3:0]
logic [6:0] velem_cnt_d, velem_cnt_q; // [MAX_VELEM_LOG:0], truncated at output
logic [(MAX_VELEM*9)-1:0] mask_buffer;
logic [DCACHE_RESP_DATA_WIDTH-1:0] vstore_buffer_d, vstore_buffer_q;
logic masked_op_d, masked_op_q;
logic [63:0] stride_d, stride_q, stride_neg;
logic [3:0] log_stride_d, log_stride_q;
logic [MAX_VELEM-1:0] load_mask;
logic [MAX_VELEM_LOG-1:0] req_tag_d, req_tag_q;
logic end_int;
rr_exe_mem_instr_t memp_instr_d, memp_instr_q; 
logic [6:0] vl_d, vl_q; // [MAX_VELEM_LOG:0]
sew_t vsew_d, vsew_q;
logic [6:0] acum_velem_incr_d, acum_velem_incr_q;
logic group_d, group_q, group_neg_d, group_neg_q;
logic neg_stride_d, neg_stride_q;

logic make_req;
logic misalign_xcpt_int;
logic is_vector;

assign is_vector = ((memp_instr_i.instr.instr_type == VLE) || (memp_instr_i.instr.instr_type == VLM) || (memp_instr_i.instr.instr_type == VL1R) ||
                    (memp_instr_i.instr.instr_type == VSE) || (memp_instr_i.instr.instr_type == VSM) || (memp_instr_i.instr.instr_type == VS1R) ||
                    (memp_instr_i.instr.instr_type == VLSE)||(memp_instr_i.instr.instr_type == VLEFF)|| (memp_instr_i.instr.instr_type == VSSE) ||
                    (memp_instr_i.instr.instr_type == VLXE)|| (memp_instr_i.instr.instr_type == VSXE)) ? 1'b1 : 1'b0;

always_comb begin
    vaddr_incr = 'h0;
    velem_incr = 'h0;
    velem_off  = 'h0;
    velem_off_neg = 'h0;
    req_tag_d = req_tag_q;
    vstore_buffer_d = vstore_buffer_q;
    memp_instr_o = memp_instr_q;
    masked_op_d = masked_op_q;
    stride_d = stride_q;
    load_mask = {MAX_VELEM{1'b1}};
    memp_instr_o.agu_req_tag = req_tag_q;
    memp_instr_o.neg_stride = 1'b0;
    memp_instr_d = memp_instr_q;
    vl_d = vl_q;
    vsew_d = vsew_q;
    make_req = 1'b0;
    misalign_xcpt_int = 1'b0;
    log_stride_d = log_stride_q;
    acum_velem_incr_d = acum_velem_incr_q;
    vmem_ops_state_d = vmem_ops_state_q;
    stride_neg = trunc_64_sum(~stride_i + 1'b1);
    group_d = group_q;
    group_neg_d = group_neg_q;
    neg_stride_d = neg_stride_q;
    case (vmem_ops_state_q)
        VL_UNIT: begin
            // Requests always aligned to 128 bits
            case (memp_instr_q.instr.mem_size) //vsew_q
                4'b0000: begin
                    velem_off  = vaddr_q[DCACHE_RESP_DATA_LOG-3-1:0];
                    velem_incr = ((DCACHE_RESP_MAXELEM - velem_off + velem_cnt_q) <= vl_q) ? 
                                   trunc_8_7(DCACHE_RESP_MAXELEM - velem_off) : trunc_8_7(vl_q - velem_cnt_q);
                    vaddr_incr = velem_incr;
                    memp_instr_o.sew = SEW_8;
                end
                4'b0101: begin
                    velem_off  = vaddr_q[DCACHE_RESP_DATA_LOG-3-1:1];
                    velem_incr = (((DCACHE_RESP_MAXELEM >> 1) - velem_off + velem_cnt_q) <= vl_q) ? 
                                   trunc_8_7((DCACHE_RESP_MAXELEM >> 1) - velem_off) : trunc_8_7(vl_q - velem_cnt_q);
                    vaddr_incr = velem_incr << 1;
                    memp_instr_o.sew = SEW_16;
                    misalign_xcpt_int = vaddr_q[0];
                end
                4'b0110: begin
                    velem_off  = vaddr_q[DCACHE_RESP_DATA_LOG-3-1:2];
                    velem_incr = (((DCACHE_RESP_MAXELEM >> 2) - velem_off + velem_cnt_q) <= vl_q) ? 
                                   trunc_8_7((DCACHE_RESP_MAXELEM >> 2) - velem_off) : trunc_8_7(vl_q - velem_cnt_q);
                    vaddr_incr = velem_incr << 2; 
                    memp_instr_o.sew = SEW_32;
                    misalign_xcpt_int = |vaddr_q[1:0];
                end
                4'b0111: begin // SEW_64
                    velem_off  = vaddr_q[DCACHE_RESP_DATA_LOG-3-1:3];
                    velem_incr = (((DCACHE_RESP_MAXELEM >> 3) - velem_off + velem_cnt_q) <= vl_q) ? 
                                   trunc_8_7((DCACHE_RESP_MAXELEM >> 3) - velem_off) : trunc_8_7(vl_q - velem_cnt_q);
                    vaddr_incr = velem_incr << 3;
                    memp_instr_o.sew = SEW_64;
                    misalign_xcpt_int = |vaddr_q[2:0];
                end
            endcase
            memp_instr_o.instr.valid = memp_instr_q.instr.valid & ~flush_i & ~stall_i;
            memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 8);
            memp_instr_o.data_rs1 = (misalign_xcpt_int) ? vaddr_q : trunc_68_64(vaddr_q & ({64{1'b1}} << (DCACHE_RESP_DATA_LOG - 3)));
            vaddr_d     = trunc_64_sum(vaddr_q     + vaddr_incr);
            velem_cnt_d = trunc_8_7(velem_cnt_q + velem_incr);
            vmem_ops_state_d = ((velem_cnt_d == vl_q) || flush_i || misalign_xcpt_int) ? SCALAR : VL_UNIT;
            end_int = (vmem_ops_state_d == SCALAR) ? 1'b1 : 1'b0;
            req_tag_d = (memp_instr_q.instr.valid & ~flush_i) ? trunc_5_4(req_tag_q + 1'b1) : req_tag_q;
            load_mask = ({MAX_VELEM{1'b1}} >> (MAX_VELEM - velem_incr));
        end
        VS_UNIT: begin
            case (memp_instr_q.instr.mem_size) //vsew_q
                4'b0000: begin
                    if (((velem_cnt_q + DCACHE_RESP_MAXELEM) <= vl_q) && (vaddr_q[DCACHE_RESP_DATA_LOG-3-1:0] == 'h0)) begin
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 8);
                        vaddr_incr = (DCACHE_RESP_DATA_WIDTH >> 3);
                        velem_incr = (DCACHE_RESP_DATA_WIDTH >> 3);
                    end else if (((velem_cnt_q + (DCACHE_RESP_MAXELEM >> 1)) <= vl_q) && (vaddr_q[DCACHE_RESP_DATA_LOG-3-2:0] == 'h0) && (DCACHE_RESP_DATA_WIDTH > 'd128)) begin
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 9);
                        vaddr_incr = (DCACHE_RESP_DATA_WIDTH >> 4);
                        velem_incr = (DCACHE_RESP_DATA_WIDTH >> 4);
                    end else if (((velem_cnt_q + (DCACHE_RESP_MAXELEM >> 2)) <= vl_q) && (vaddr_q[DCACHE_RESP_DATA_LOG-3-3:0] == 'h0) && (DCACHE_RESP_DATA_WIDTH > 'd256)) begin
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 10);
                        vaddr_incr = (DCACHE_RESP_DATA_WIDTH >> 5);
                        velem_incr = (DCACHE_RESP_DATA_WIDTH >> 5);
                    end else if (((velem_cnt_q + 8) <= vl_q) && (vaddr_q[2:0] == 'h0)) begin
                        memp_instr_o.instr.mem_size = 4'b0011;
                        vaddr_incr = 64'd8;
                        velem_incr = 'd8;
                    end else if (((velem_cnt_q + 4) <= vl_q) && (vaddr_q[1:0] == 'h0)) begin
                        memp_instr_o.instr.mem_size = 4'b0010;
                        vaddr_incr = 64'd4;
                        velem_incr = 'd4;
                    end else if (((velem_cnt_q + 2) <= vl_q) && (vaddr_q[0] == 'h0)) begin
                        memp_instr_o.instr.mem_size = 4'b0001;
                        vaddr_incr = 64'd2;
                        velem_incr = 'd2;
                    end else begin
                        memp_instr_o.instr.mem_size = 4'b0000;
                        vaddr_incr = 64'd1;
                        velem_incr = 'd1;
                    end
                    memp_instr_o.data_rs2 = vstore_buffer_q >> padd_dcachedatalog_plus1(velem_cnt_q[DCACHE_RESP_DATA_LOG-3-1:0] << 3);
                    memp_instr_o.sew = SEW_8;
                end
                4'b0101: begin
                    if (((velem_cnt_q + (DCACHE_RESP_MAXELEM >> 1)) <= vl_q) && (vaddr_q[DCACHE_RESP_DATA_LOG-3-1:0] == 'h0)) begin
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 8);
                        vaddr_incr = (DCACHE_RESP_DATA_WIDTH >> 3);
                        velem_incr = (DCACHE_RESP_DATA_WIDTH >> 4);
                    end else if (((velem_cnt_q + (DCACHE_RESP_MAXELEM >> 2)) <= vl_q) && (vaddr_q[DCACHE_RESP_DATA_LOG-3-2:0] == 'h0) && (DCACHE_RESP_DATA_WIDTH > 'd128)) begin
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 9);
                        vaddr_incr = (DCACHE_RESP_DATA_WIDTH >> 4);
                        velem_incr = (DCACHE_RESP_DATA_WIDTH >> 5);
                    end else if (((velem_cnt_q + (DCACHE_RESP_MAXELEM >> 3)) <= vl_q) && (vaddr_q[DCACHE_RESP_DATA_LOG-3-3:0] == 'h0) && (DCACHE_RESP_DATA_WIDTH > 'd256)) begin
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 10);
                        vaddr_incr = (DCACHE_RESP_DATA_WIDTH >> 5);
                        velem_incr = (DCACHE_RESP_DATA_WIDTH >> 6);
                    end else if (((velem_cnt_q + 4) <= vl_q) && (vaddr_q[2:0] == 'h0)) begin
                        memp_instr_o.instr.mem_size = 4'b0011;
                        vaddr_incr = 64'd8;
                        velem_incr = 'd4;
                    end else if (((velem_cnt_q + 2) <= vl_q) && (vaddr_q[1:0] == 'h0)) begin
                        memp_instr_o.instr.mem_size = 4'b0010;
                        vaddr_incr = 64'd4;
                        velem_incr = 'd2;
                    end else begin
                        memp_instr_o.instr.mem_size = 4'b0001;
                        vaddr_incr = 64'd2;
                        velem_incr = 'd1;
                    end
                    memp_instr_o.data_rs2 = vstore_buffer_q >> padd_dcachedatalog_plus1(velem_cnt_q[DCACHE_RESP_DATA_LOG-3-2:0] << 4);
                    memp_instr_o.sew = SEW_16;
                    misalign_xcpt_int = vaddr_q[0];
                end
                4'b0110: begin
                    if (((velem_cnt_q + (DCACHE_RESP_MAXELEM >> 2)) <= vl_q) && (vaddr_q[DCACHE_RESP_DATA_LOG-3-1:0] == 'h0)) begin
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 8);
                        vaddr_incr = (DCACHE_RESP_DATA_WIDTH >> 3);
                        velem_incr = (DCACHE_RESP_DATA_WIDTH >> 5);
                    end else if (((velem_cnt_q + (DCACHE_RESP_MAXELEM >> 3)) <= vl_q) && (vaddr_q[DCACHE_RESP_DATA_LOG-3-2:0] == 'h0) && (DCACHE_RESP_DATA_WIDTH > 'd128)) begin
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 9);
                        vaddr_incr = (DCACHE_RESP_DATA_WIDTH >> 4);
                        velem_incr = (DCACHE_RESP_DATA_WIDTH >> 6);
                    end else if (((velem_cnt_q + (DCACHE_RESP_MAXELEM >> 4)) <= vl_q) && (vaddr_q[DCACHE_RESP_DATA_LOG-3-3:0] == 'h0) && (DCACHE_RESP_DATA_WIDTH > 'd256)) begin
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 10);
                        vaddr_incr = (DCACHE_RESP_DATA_WIDTH >> 5);
                        velem_incr = (DCACHE_RESP_DATA_WIDTH >> 7);
                    end else if (((velem_cnt_q + 2) <= vl_q) && (vaddr_q[2:0] == 'h0)) begin
                        memp_instr_o.instr.mem_size = 4'b0011;
                        vaddr_incr = 64'd8;
                        velem_incr = 'd2;
                    end else begin
                        memp_instr_o.instr.mem_size = 4'b0010;
                        vaddr_incr = 64'd4;
                        velem_incr = 'd1;
                    end
                    memp_instr_o.data_rs2 = vstore_buffer_q >> padd_dcachedatalog_plus1(velem_cnt_q[DCACHE_RESP_DATA_LOG-3-3:0] << 5);
                    memp_instr_o.sew = SEW_32;
                    misalign_xcpt_int = |vaddr_q[1:0];
                end
                4'b0111: begin
                    if (((velem_cnt_q + (DCACHE_RESP_MAXELEM >> 3)) <= vl_q) && (vaddr_q[DCACHE_RESP_DATA_LOG-3-1:0] == 'h0)) begin
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 8);
                        vaddr_incr = (DCACHE_RESP_DATA_WIDTH >> 3);
                        velem_incr = (DCACHE_RESP_DATA_WIDTH >> 6);
                    end else if (((velem_cnt_q + (DCACHE_RESP_MAXELEM >> 4)) <= vl_q) && (vaddr_q[DCACHE_RESP_DATA_LOG-3-2:0] == 'h0) && (DCACHE_RESP_DATA_WIDTH > 'd128)) begin
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 9);
                        vaddr_incr = (DCACHE_RESP_DATA_WIDTH >> 4);
                        velem_incr = (DCACHE_RESP_DATA_WIDTH >> 7);
                    end else if (((velem_cnt_q + (DCACHE_RESP_MAXELEM >> 5)) <= vl_q) && (vaddr_q[DCACHE_RESP_DATA_LOG-3-3:0] == 'h0) && (DCACHE_RESP_DATA_WIDTH > 'd256)) begin
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 10);
                        vaddr_incr = (DCACHE_RESP_DATA_WIDTH >> 5);
                        velem_incr = (DCACHE_RESP_DATA_WIDTH >> 8);
                    end else begin
                        memp_instr_o.instr.mem_size = 4'b0011;
                        vaddr_incr = 64'd8;
                        velem_incr = 'd1;
                    end
                    memp_instr_o.data_rs2 = vstore_buffer_q >> padd_dcachedatalog_plus1(velem_cnt_q[DCACHE_RESP_DATA_LOG-3-4:0] << 6);
                    memp_instr_o.sew = SEW_64;
                    misalign_xcpt_int = |vaddr_q[2:0];
                end
            endcase
            memp_instr_o.instr.valid = memp_instr_q.instr.valid & ~flush_i & ~stall_i;
            memp_instr_o.data_rs1 = vaddr_q;
            vaddr_d     = trunc_64_sum(vaddr_q     + vaddr_incr);
            velem_cnt_d = trunc_8_7(velem_cnt_q + velem_incr);
            vmem_ops_state_d = ((velem_cnt_d == vl_q) || flush_i || misalign_xcpt_int) ? SCALAR : VS_UNIT;
            end_int = (vmem_ops_state_d == SCALAR) ? 1'b1 : 1'b0;
            req_tag_d = (memp_instr_q.instr.valid & ~flush_i) ? trunc_5_4(req_tag_q + 1'b1) : req_tag_q;
        end
        VL_STRIDED: begin
            make_req = memp_instr_q.instr.valid && ~flush_i && 
                       (!masked_op_q || ((velem_cnt_q + velem_incr) >= vl_q) || (mask_buffer[velem_cnt_q]));
            case (memp_instr_q.instr.mem_size) //vsew_q
                4'b0000: begin
                    //check if the stride is power of 2 and it is lower than the dcache data width for grouping requests
                    if (group_q) begin
                        velem_off  = vaddr_q[DCACHE_RESP_DATA_LOG-3-1:0];
                        velem_incr = ((((DCACHE_RESP_MAXELEM - velem_off + stride_q[6:0] - 1'b1) >> log_stride_q) + velem_cnt_q) <= vl_q) ? 
                                    ((DCACHE_RESP_MAXELEM - velem_off + stride_q[6:0] - 1'b1) >> log_stride_q) : trunc_8_7(vl_q - velem_cnt_q);
                        vaddr_incr = velem_incr << log_stride_q;
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 8);
                        memp_instr_o.data_rs1 = trunc_68_64(vaddr_q & ({64{1'b1}} << (DCACHE_RESP_DATA_LOG - 3)));
                        load_mask = 'h0;
                        for (int i = 0; i < velem_incr; ++i) begin
                            load_mask[(i << log_stride_q)] = 1'b1;
                        end
                    end else if (group_neg_q) begin
                        velem_off = 'h0;
                        velem_off_neg = (DCACHE_RESP_DATA_WIDTH >> 3) - vaddr_q[DCACHE_RESP_DATA_LOG-3-1:0] - 1'b1;
                        velem_incr = ((((DCACHE_RESP_MAXELEM - velem_off_neg + stride_q[6:0] - 1'b1) >> log_stride_q) + velem_cnt_q) <= vl_q) ? 
                                    ((DCACHE_RESP_MAXELEM - velem_off_neg + stride_q[6:0] - 1'b1) >> log_stride_q) : trunc_8_7(vl_q - velem_cnt_q);
                        vaddr_incr = ~(velem_incr << log_stride_q) + 1'b1;
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 8);
                        memp_instr_o.data_rs1 = trunc_68_64(vaddr_q & ({64{1'b1}} << (DCACHE_RESP_DATA_LOG - 3)));
                        load_mask = 'h0;
                        for (int i = 0; i < velem_incr; ++i) begin
                            load_mask[MAX_VELEM-1-(i << log_stride_q)-velem_off_neg] = 1'b1;
                        end
                        memp_instr_o.neg_stride = 1'b1;
                    end else begin
                        vaddr_incr = (neg_stride_q) ? trunc_64_sum(~stride_q + 1'b1) : stride_q;
                        velem_incr = 1'b1;
                        memp_instr_o.instr.instr_type = LB;
                        memp_instr_o.instr.mem_size = 4'b0000;
                        memp_instr_o.data_rs1 = vaddr_q;
                        load_mask = {63'd0, make_req};
                        acum_velem_incr_d = (make_req) ? 'h0 : trunc_8_7(acum_velem_incr_q + velem_incr);
                    end 
                    memp_instr_o.sew = SEW_8;
                end
                4'b0101: begin
                    if (group_q && (log_stride_q >= 'h1)) begin
                        velem_off  = vaddr_q[DCACHE_RESP_DATA_LOG-3-1:1];
                        velem_incr = (((((DCACHE_RESP_MAXELEM >> 1) - velem_off + (stride_q[6:0] >> 1) - 1'b1) >> (log_stride_q - 1'b1)) + velem_cnt_q) <= vl_q) ? 
                                    trunc_8_7((((DCACHE_RESP_MAXELEM >> 1) - velem_off + (stride_q[6:0] >> 1) - 1'b1) >> (log_stride_q - 1'b1))) : trunc_8_7(vl_q - velem_cnt_q);
                        vaddr_incr = velem_incr << log_stride_q;
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 8);
                        memp_instr_o.data_rs1 = trunc_68_64(vaddr_q & ({64{1'b1}} << (DCACHE_RESP_DATA_LOG - 3)));
                        load_mask = 'h0;
                        for (int i = 0; i < velem_incr; ++i) begin
                            load_mask[(i << (log_stride_q-1'b1))]= 1'b1;
                        end
                    end else if (group_neg_q && (log_stride_q >= 'h1)) begin
                        velem_off = 'h0;
                        velem_off_neg = (DCACHE_RESP_DATA_WIDTH >> 4) - vaddr_q[DCACHE_RESP_DATA_LOG-3-1:1] - 1'b1;
                        velem_incr = (((((DCACHE_RESP_MAXELEM >> 1) - velem_off_neg + (stride_q[6:0] >> 1) - 1'b1) >> (log_stride_q - 1'b1)) + velem_cnt_q) <= vl_q) ? 
                                    trunc_8_7((((DCACHE_RESP_MAXELEM >> 1) - velem_off_neg + (stride_q[6:0] >> 1) - 1'b1) >> (log_stride_q - 1'b1))) : trunc_8_7(vl_q - velem_cnt_q);
                        vaddr_incr = ~(velem_incr << log_stride_q) + 1'b1;
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 8);
                        memp_instr_o.data_rs1 = trunc_68_64(vaddr_q & ({64{1'b1}} << (DCACHE_RESP_DATA_LOG - 3)));
                        load_mask = 'h0;
                        for (int i = 0; i < velem_incr; ++i) begin
                            load_mask[(MAX_VELEM >> 1)-1-(i << (log_stride_q-1))-velem_off_neg] = 1'b1;
                        end
                        memp_instr_o.neg_stride = 1'b1;
                    end else begin
                        vaddr_incr = (neg_stride_q) ? trunc_64_sum(~stride_q + 1'b1) : stride_q;
                        velem_incr = 1'b1;
                        memp_instr_o.instr.instr_type = LH;
                        memp_instr_o.instr.mem_size = 4'b0001;
                        memp_instr_o.data_rs1 = vaddr_q;
                        load_mask = {63'd0, make_req};
                        acum_velem_incr_d = (make_req) ? 'h0 : trunc_8_7(acum_velem_incr_q + velem_incr);
                    end 
                    memp_instr_o.sew = SEW_16;
                    misalign_xcpt_int = vaddr_q[0];
                end
                4'b0110: begin
                    if (group_q && (log_stride_q >= 'h2)) begin
                        velem_off  = vaddr_q[DCACHE_RESP_DATA_LOG-3-1:2];
                        velem_incr = (((((DCACHE_RESP_MAXELEM >> 2) - velem_off + (stride_q[6:0] >> 2) - 1'b1) >> (log_stride_q - 2'h2)) + velem_cnt_q) <= vl_q) ? 
                                     trunc_8_7((((DCACHE_RESP_MAXELEM >> 2) - velem_off + (stride_q[6:0] >> 2) - 1'b1) >> (log_stride_q - 2'h2))) : trunc_8_7(vl_q - velem_cnt_q);
                        vaddr_incr = velem_incr << log_stride_q;
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 8);
                        memp_instr_o.data_rs1 = trunc_68_64(vaddr_q & ({64{1'b1}} << (DCACHE_RESP_DATA_LOG - 3)));
                        load_mask = 'h0;
                        for (int i = 0; i < velem_incr; ++i) begin
                            load_mask[(i << (log_stride_q-2'd2))] = 1'b1;
                        end
                    end else if (group_neg_q && (log_stride_q >= 'h2)) begin
                        velem_off = 'h0;
                        velem_off_neg = (DCACHE_RESP_DATA_WIDTH >> 5) - vaddr_q[DCACHE_RESP_DATA_LOG-3-1:2] - 1'b1;
                        velem_incr = (((((DCACHE_RESP_MAXELEM >> 2) - velem_off_neg + (stride_q[6:0] >> 2) - 1'b1) >> (log_stride_q - 2'h2)) + velem_cnt_q) <= vl_q) ? 
                                     trunc_8_7((((DCACHE_RESP_MAXELEM >> 2) - velem_off_neg + (stride_q[6:0] >> 2) - 1'b1) >> (log_stride_q - 2'h2))) : trunc_8_7(vl_q - velem_cnt_q);
                        vaddr_incr = ~(velem_incr << log_stride_q) + 1'b1;
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 8);
                        memp_instr_o.data_rs1 = trunc_68_64(vaddr_q & ({64{1'b1}} << (DCACHE_RESP_DATA_LOG - 3)));
                        load_mask = 'h0;
                        for (int i = 0; i < velem_incr; ++i) begin
                            load_mask[(MAX_VELEM >> 2)-1-(i << (log_stride_q-2))-velem_off_neg] = 1'b1;
                        end
                        memp_instr_o.neg_stride = 1'b1;
                    end else begin
                        vaddr_incr = (neg_stride_q) ? trunc_64_sum(~stride_q + 1'b1) : stride_q;
                        velem_incr = 1'b1;
                        memp_instr_o.instr.instr_type = LW;
                        memp_instr_o.instr.mem_size = 4'b0010;
                        memp_instr_o.data_rs1 = vaddr_q;
                        load_mask = {63'd0, make_req};
                        acum_velem_incr_d = (make_req) ? 'h0 : trunc_8_7(acum_velem_incr_q + velem_incr);
                    end
                    memp_instr_o.sew = SEW_32;
                    misalign_xcpt_int = |vaddr_q[1:0];
                end
                4'b0111: begin
                     if (group_q && (log_stride_q >= 'h3)) begin
                        velem_off  = vaddr_q[DCACHE_RESP_DATA_LOG-3-1:3];
                        velem_incr = (((((DCACHE_RESP_MAXELEM >> 3) - velem_off + (stride_q[6:0] >> 3) - 1'b1) >> (log_stride_q - 2'h3)) + velem_cnt_q) <= vl_q) ? 
                                    trunc_8_7((((DCACHE_RESP_MAXELEM >> 3) - velem_off + (stride_q[6:0] >> 3) - 1'b1) >> (log_stride_q - 2'h3))) : trunc_8_7(vl_q - velem_cnt_q);
                        vaddr_incr = velem_incr << log_stride_q;
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 8);
                        memp_instr_o.data_rs1 = trunc_68_64(vaddr_q & ({64{1'b1}} << (DCACHE_RESP_DATA_LOG - 3)));
                        load_mask = 'h0;
                        for (int i = 0; i < velem_incr; ++i) begin
                            load_mask[(i << (log_stride_q-2'd3))] = 1'b1;
                        end
                    end else if (group_neg_q && (log_stride_q >= 'h3)) begin
                        velem_off = 'h0;
                        velem_off_neg = (DCACHE_RESP_DATA_WIDTH >> 6) - vaddr_q[DCACHE_RESP_DATA_LOG-3-1:3] - 1'b1;
                        velem_incr = (((((DCACHE_RESP_MAXELEM >> 3) - velem_off_neg + (stride_q[6:0] >> 3) - 1'b1) >> (log_stride_q - 2'h3)) + velem_cnt_q) <= vl_q) ? 
                                     trunc_8_7((((DCACHE_RESP_MAXELEM >> 3) - velem_off_neg + (stride_q[6:0] >> 3) - 1'b1) >> (log_stride_q - 2'h3))) : trunc_8_7(vl_q - velem_cnt_q);
                        vaddr_incr = ~(velem_incr << log_stride_q) + 1'b1;
                        memp_instr_o.instr.mem_size = 4'b1000 | 4'(DCACHE_RESP_DATA_WIDTH >> 8);
                        memp_instr_o.data_rs1 = trunc_68_64(vaddr_q & ({64{1'b1}} << (DCACHE_RESP_DATA_LOG - 3)));
                        load_mask = 'h0;
                        for (int i = 0; i < velem_incr; ++i) begin
                            load_mask[(MAX_VELEM >> 3)-1-(i << (log_stride_q-3))-velem_off_neg] = 1'b1;
                        end
                        memp_instr_o.neg_stride = 1'b1;
                    end else begin
                        vaddr_incr = (neg_stride_q) ? trunc_64_sum(~stride_q + 1'b1) : stride_q;
                        velem_incr = 1'b1;
                        memp_instr_o.instr.instr_type = LD;
                        memp_instr_o.instr.mem_size = 4'b0011;
                        memp_instr_o.data_rs1 = vaddr_q;
                        load_mask = {63'd0, make_req};
                        acum_velem_incr_d = (make_req) ? 'h0 : trunc_8_7(acum_velem_incr_q + velem_incr);
                    end
                    memp_instr_o.sew = SEW_64;
                    misalign_xcpt_int = |vaddr_q[2:0];
                end
            endcase
            // Do not generate requests for masked elements, if it is a masked operation check that we have an available mask
            memp_instr_o.instr.valid = memp_instr_q.instr.valid && ~flush_i && ~stall_i &&
                                       (!masked_op_q || ((velem_cnt_q + velem_incr) >= vl_q) || (make_req || (memp_instr_o.instr.instr_type == VLSE)));
            vaddr_d = trunc_64_sum(vaddr_q + vaddr_incr);
            velem_cnt_d = trunc_8_7(velem_cnt_q + velem_incr);
            vmem_ops_state_d = ((velem_cnt_d >= vl_q) || flush_i || misalign_xcpt_int) ? SCALAR : VL_STRIDED;
            req_tag_d = (memp_instr_o.instr.valid) ? trunc_5_4(req_tag_q + 1'b1) : req_tag_q;
            end_int = (vmem_ops_state_d == SCALAR) ? 1'b1 : 1'b0;
            if (misalign_xcpt_int) begin
                memp_instr_o.data_rs1 = vaddr_q;
            end
        end
        VS_STRIDED: begin
            case (memp_instr_q.instr.mem_size) //vsew_q
                4'b0000: begin
                    memp_instr_o.instr.instr_type = SB;
                    memp_instr_o.instr.mem_size = 4'b0000;
                    memp_instr_o.data_rs2 = vstore_buffer_q >> padd_dcachedatalog_plus1(velem_cnt_q[DCACHE_RESP_DATA_LOG-3-1:0] << 3);
                    memp_instr_o.sew = SEW_8;
                end
                4'b0101: begin
                    memp_instr_o.instr.instr_type = SH;
                    memp_instr_o.instr.mem_size = 4'b0001;
                    memp_instr_o.data_rs2 = vstore_buffer_q >> padd_dcachedatalog_plus1(velem_cnt_q[DCACHE_RESP_DATA_LOG-3-2:0] << 4);
                    misalign_xcpt_int = vaddr_q[0];
                    memp_instr_o.sew = SEW_16;
                end
                4'b0110: begin
                    memp_instr_o.instr.instr_type = SW;
                    memp_instr_o.instr.mem_size = 4'b0010;
                    memp_instr_o.data_rs2 = vstore_buffer_q >> padd_dcachedatalog_plus1(velem_cnt_q[DCACHE_RESP_DATA_LOG-3-3:0] << 5);
                    misalign_xcpt_int = |vaddr_q[1:0];
                    memp_instr_o.sew = SEW_32;
                end
                4'b0111: begin
                    memp_instr_o.instr.instr_type = SD;
                    memp_instr_o.instr.mem_size = 4'b0011;
                    memp_instr_o.data_rs2 = vstore_buffer_q >> padd_dcachedatalog_plus1(velem_cnt_q[DCACHE_RESP_DATA_LOG-3-4:0] << 6);
                    misalign_xcpt_int = |vaddr_q[2:0];
                    memp_instr_o.sew = SEW_64;
                end
            endcase
            memp_instr_o.instr.valid = memp_instr_q.instr.valid && ~flush_i && ~stall_i;
            memp_instr_o.data_rs1 = vaddr_q;
            velem_incr = 1'b1;
            vaddr_d     = (neg_stride_q) ? trunc_64_sum(vaddr_q - stride_q) : trunc_64_sum(vaddr_q + stride_q);
            velem_cnt_d = trunc_8_7(velem_cnt_q + velem_incr);
            vmem_ops_state_d = ((velem_cnt_d == vl_q) || flush_i || misalign_xcpt_int) ? SCALAR : VS_STRIDED;
            req_tag_d = (memp_instr_o.instr.valid) ? trunc_5_4(req_tag_q + 1'b1) : req_tag_q;
            end_int = (vmem_ops_state_d == SCALAR) ? 1'b1 : 1'b0;
            acum_velem_incr_d = (memp_instr_o.instr.valid) ? 'h0 : trunc_8_7(acum_velem_incr_q + velem_incr);
            load_mask[0] = memp_instr_q.instr.valid && ~flush_i && ~stall_i && (!masked_op_q || (mask_buffer[velem_cnt_q]));
        end
        VL_INDEXED: begin
            case (vsew_q)
            //We asume the granularity always depends on the SEW
            //(vlxe instructions only)
                SEW_8: begin
                    memp_instr_o.instr.instr_type = LB;
                    memp_instr_o.instr.mem_size = 4'b0000;
                    memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{56{mask_buffer[trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM+7)]}}, mask_buffer[(trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM))+:8]});
                end
                SEW_16: begin
                    memp_instr_o.instr.instr_type = LH;
                    memp_instr_o.instr.mem_size = 4'b0001;
                    if (memp_instr_q.instr.mem_size == 4'b0000) begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{56{mask_buffer[trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM+7)]}}, mask_buffer[(trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM))+:8]});
                    end else begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{48{mask_buffer[trunc_dcachedatalog_shift4((velem_cnt_q*16)+MAX_VELEM+15)]}}, mask_buffer[(trunc_dcachedatalog_shift4((velem_cnt_q*16)+MAX_VELEM))+:16]});
                    end
                end
                SEW_32: begin
                    memp_instr_o.instr.instr_type = LW;
                    memp_instr_o.instr.mem_size = 4'b0010;
                    if (memp_instr_q.instr.mem_size == 4'b0000) begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{56{mask_buffer[trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM+7)]}}, mask_buffer[(trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM))+:8]});
                    end else if (memp_instr_q.instr.mem_size == 4'b0101) begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{48{mask_buffer[trunc_dcachedatalog_shift4((velem_cnt_q*16)+MAX_VELEM+15)]}}, mask_buffer[(trunc_dcachedatalog_shift4((velem_cnt_q*16)+MAX_VELEM))+:16]});
                    end else begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{32{mask_buffer[trunc_dcachedatalog_shift5((velem_cnt_q*32)+MAX_VELEM+31)]}}, mask_buffer[(trunc_dcachedatalog_shift4((velem_cnt_q*32)+MAX_VELEM))+:32]});
                    end
                end
                default: begin
                    memp_instr_o.instr.instr_type = LD;
                    memp_instr_o.instr.mem_size = 4'b0011;
                    if (memp_instr_q.instr.mem_size == 4'b0000) begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{56{mask_buffer[trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM+7)]}}, mask_buffer[(trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM))+:8]});
                    end else if (memp_instr_q.instr.mem_size == 4'b0101) begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{48{mask_buffer[trunc_dcachedatalog_shift4((velem_cnt_q*16)+MAX_VELEM+15)]}}, mask_buffer[(trunc_dcachedatalog_shift4((velem_cnt_q*16)+MAX_VELEM))+:16]});
                    end else if (memp_instr_q.instr.mem_size == 4'b0110) begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{32{mask_buffer[trunc_dcachedatalog_shift5((velem_cnt_q*32)+MAX_VELEM+31)]}}, mask_buffer[(trunc_dcachedatalog_shift4((velem_cnt_q*32)+MAX_VELEM))+:32]});
                    end else begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + mask_buffer[(trunc_dcachedatalog_shift5((velem_cnt_q*64)+MAX_VELEM))+:64]);
                    end
                end
            endcase
            memp_instr_o.instr.valid = memp_instr_q.instr.valid && ~flush_i && ~stall_i && (((velem_cnt_q + 1'b1) >= vl_q) || (mask_buffer[velem_cnt_q]));
            vaddr_d = vaddr_q;
            velem_incr = 1'b1;
            velem_cnt_d = trunc_8_7(velem_cnt_q + velem_incr);
            vmem_ops_state_d = ((velem_cnt_d == vl_q) || flush_i || misalign_xcpt_int) ? SCALAR : VL_INDEXED;
            load_mask = {63'd0, memp_instr_o.instr.valid};
            req_tag_d = (memp_instr_o.instr.valid) ? trunc_5_4(req_tag_q + 1'b1) : req_tag_q;
            end_int = (vmem_ops_state_d == SCALAR) ? 1'b1 : 1'b0;
            acum_velem_incr_d = (memp_instr_o.instr.valid) ? 'h0 : trunc_8_7(acum_velem_incr_q + velem_incr);
        end
        VS_INDEXED: begin
            case (vsew_q)
            //We asume the granularity always depends on the SEW
            //(vsxe instructions only)
                SEW_8: begin
                    memp_instr_o.instr.instr_type = SB;
                    memp_instr_o.instr.mem_size = 4'b0000;
                    memp_instr_o.data_rs2 = vstore_buffer_q >> padd_dcachedatalog_plus1(velem_cnt_q[DCACHE_RESP_DATA_LOG-3-1:0] << 3);
                    memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{56{mask_buffer[trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM+7)]}}, mask_buffer[(trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM))+:8]});
                end
                SEW_16: begin
                    memp_instr_o.instr.instr_type = SH;
                    memp_instr_o.instr.mem_size = 4'b0001;
                    memp_instr_o.data_rs2 = vstore_buffer_q >> padd_dcachedatalog_plus1(velem_cnt_q[DCACHE_RESP_DATA_LOG-3-2:0] << 4);
                    if (memp_instr_q.instr.mem_size == 4'b0000) begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{56{mask_buffer[trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM+7)]}}, mask_buffer[(trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM))+:8]});
                    end else begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{48{mask_buffer[trunc_dcachedatalog_shift4((velem_cnt_q*16)+MAX_VELEM+15)]}}, mask_buffer[(trunc_dcachedatalog_shift4((velem_cnt_q*16)+MAX_VELEM))+:16]});
                    end
                end
                SEW_32: begin
                    memp_instr_o.instr.instr_type = SW;
                    memp_instr_o.instr.mem_size = 4'b0010;
                    memp_instr_o.data_rs2 = vstore_buffer_q >> padd_dcachedatalog_plus1(velem_cnt_q[DCACHE_RESP_DATA_LOG-3-3:0] << 5);
                    if (memp_instr_q.instr.mem_size == 4'b0000) begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{56{mask_buffer[trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM+7)]}}, mask_buffer[(trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM))+:8]});
                    end else if (memp_instr_q.instr.mem_size == 4'b0101) begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{48{mask_buffer[trunc_dcachedatalog_shift4((velem_cnt_q*16)+MAX_VELEM+15)]}}, mask_buffer[(trunc_dcachedatalog_shift4((velem_cnt_q*16)+MAX_VELEM))+:16]});
                    end else begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{32{mask_buffer[trunc_dcachedatalog_shift5((velem_cnt_q*32)+MAX_VELEM+31)]}}, mask_buffer[(trunc_dcachedatalog_shift4((velem_cnt_q*32)+MAX_VELEM))+:32]});
                    end
                end
                default: begin
                    memp_instr_o.instr.instr_type = SD;
                    memp_instr_o.instr.mem_size = 4'b0011;
                    memp_instr_o.data_rs2 = vstore_buffer_q >> padd_dcachedatalog_plus1(velem_cnt_q[DCACHE_RESP_DATA_LOG-3-4:0] << 6);
                    if (memp_instr_q.instr.mem_size == 4'b0000) begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{56{mask_buffer[trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM+7)]}}, mask_buffer[(trunc_dcachedatalog_shift3((velem_cnt_q*8)+MAX_VELEM))+:8]});
                    end else if (memp_instr_q.instr.mem_size == 4'b0101) begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{48{mask_buffer[trunc_dcachedatalog_shift4((velem_cnt_q*16)+MAX_VELEM+15)]}}, mask_buffer[(trunc_dcachedatalog_shift4((velem_cnt_q*16)+MAX_VELEM))+:16]});
                    end else if (memp_instr_q.instr.mem_size == 4'b0110) begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + {{32{mask_buffer[trunc_dcachedatalog_shift5((velem_cnt_q*32)+MAX_VELEM+31)]}}, mask_buffer[(trunc_dcachedatalog_shift4((velem_cnt_q*32)+MAX_VELEM))+:32]});
                    end else begin
                        memp_instr_o.data_rs1 = trunc_64_sum(vaddr_q + mask_buffer[(trunc_dcachedatalog_shift5((velem_cnt_q*64)+MAX_VELEM))+:64]);
                    end
                end
            endcase
            memp_instr_o.instr.valid = memp_instr_q.instr.valid && ~flush_i && ~stall_i;
            vaddr_d = vaddr_q;
            velem_incr = 1'b1;
            velem_cnt_d = trunc_8_7(velem_cnt_q + velem_incr);
            vmem_ops_state_d = ((velem_cnt_d == vl_q) || flush_i || misalign_xcpt_int) ? SCALAR : VS_INDEXED;
            req_tag_d = (memp_instr_o.instr.valid) ? trunc_5_4(req_tag_q + 1'b1) : req_tag_q;
            end_int = (vmem_ops_state_d == SCALAR) ? 1'b1 : 1'b0;
            acum_velem_incr_d = (memp_instr_o.instr.valid) ? 'h0 : trunc_8_7(acum_velem_incr_q + velem_incr);
            load_mask[0] = memp_instr_q.instr.valid && ~flush_i && ~stall_i && (!masked_op_q || (mask_buffer[velem_cnt_q]));
        end
        default: begin //SCALAR
            // For scalar instructions, calculate the address and let them pass through
            memp_instr_o = memp_instr_i;
            velem_cnt_d = 0;
            vaddr_d = memp_instr_i.data_rs1;
            if ((memp_instr_i.instr.valid) && (vl_i != 'h0)) begin
                vmem_ops_state_d = (((memp_instr_i.instr.instr_type == VLE) || (memp_instr_i.instr.instr_type == VLM) || (memp_instr_i.instr.instr_type == VL1R))) ? VL_UNIT :
                                   (((memp_instr_i.instr.instr_type == VSE) || (memp_instr_i.instr.instr_type == VSM) || (memp_instr_i.instr.instr_type == VS1R)) && !masked_op_i) ? VS_UNIT :
                                   (((memp_instr_i.instr.instr_type == VLSE)|| (memp_instr_i.instr.instr_type == VLEFF)) && ((mop_i[0] == 1'b0) && (mop_i[2] == 1'b0)))   ? VL_STRIDED :
                                   (((memp_instr_i.instr.instr_type == VSE) || (memp_instr_i.instr.instr_type == VSSE)) && ((mop_i[0] == 1'b0) && (mop_i[2] == 1'b0))) ? VS_STRIDED :
                                   ((memp_instr_i.instr.instr_type == VLXE) && (mop_i      == 3'b011)                )   ? VL_INDEXED :
                                   ((memp_instr_i.instr.instr_type == VSXE) && (mop_i[1:0] == 2'b11 )                )   ? VS_INDEXED :
                                    SCALAR;
            end else if (memp_instr_i.instr.valid && is_vector) begin 
                load_mask = 'h0;
                memp_instr_o.data_vm = 'h0;
                vmem_ops_state_d = SCALAR;
            end else begin
                vmem_ops_state_d = SCALAR;
            end
            vstore_buffer_d = vstore_data_i;
            masked_op_d = masked_op_i;
            stride_d = (stride_i[63]) ? stride_neg : stride_i;
            neg_stride_d = stride_i[63];
            memp_instr_o.data_rs1 = memp_instr_i.data_rs1;
            end_int = 1'b0;
            memp_instr_o.instr.valid = memp_instr_i.instr.valid && (vmem_ops_state_d == SCALAR);
            memp_instr_d = memp_instr_i;
            vl_d = vl_i;
            vsew_d = vsew_i;
            acum_velem_incr_d = 'h0;
            velem_incr = '1;
            if ((stride_i <= (DCACHE_RESP_DATA_WIDTH >> 4)) && (stride_i[5:0] != 'h0) && (~|(stride_i[5:0] & (stride_i[5:0] - 1'b1))) && (memp_instr_i.instr.instr_type != VLEFF)) begin
                group_d = 1'b1;
                group_neg_d = 1'b0;
            end else if ((stride_neg <= (DCACHE_RESP_DATA_WIDTH >> 4)) && (stride_neg[5:0] != 'h0) && (~|(stride_neg[5:0] & (stride_neg[5:0] - 1'b1))) && (memp_instr_i.instr.instr_type != VLEFF)) begin
                group_d = 1'b0;
                group_neg_d = 1'b1;
            end else begin
                group_d = 1'b0;
                group_neg_d = 1'b0;
            end
            for (int i = 0; i < 6; ++i) begin
                if (stride_d[i] == 1'b1) begin
                    log_stride_d = i;
                end
            end
        end
    endcase
    memp_instr_o.vmisalign_xcpt = misalign_xcpt_int;
    memp_instr_o.velem_id = velem_cnt_q[MAX_VELEM_LOG-1:0];
    memp_instr_o.load_mask = load_mask;
    memp_instr_o.velem_off = velem_off[DCACHE_RESP_DATA_LOG-3:0];
    memp_instr_o.velem_incr = trunc_max_velem_log_sum(acum_velem_incr_q[MAX_VELEM_LOG:0] + velem_incr[DCACHE_RESP_DATA_LOG-3:0]);
end

always_ff @(posedge clk_i, negedge rstn_i) begin
    if(~rstn_i) begin
        vmem_ops_state_q <= SCALAR;
        vaddr_q <= 'h0;
        velem_cnt_q <= 'h0;
        vstore_buffer_q <= 'h0;
        masked_op_q <= 1'b0;
        stride_q <= 'h0;
        req_tag_q <= 4'd0;
        memp_instr_q <= 'h0;
        vl_q <= 'd0;
        vsew_q <= SEW_8;
        acum_velem_incr_q <= 'h0;
        group_q <= 1'b0;
        group_neg_q <= 1'b0;
        log_stride_q <= 'h0;
        neg_stride_q <= 1'b0;
        mask_buffer <= 'h0;
    end else begin
        if (stall_i && !flush_i) begin
            vmem_ops_state_q <= vmem_ops_state_q;
            vaddr_q <= vaddr_q;
            velem_cnt_q <= velem_cnt_q;
            masked_op_q <= masked_op_q;
            stride_q <= stride_q;
            req_tag_q <= req_tag_q;
            memp_instr_q <= memp_instr_q;
            vl_q <= vl_q;
            vsew_q <= vsew_q;
            acum_velem_incr_q <= acum_velem_incr_q;
            group_q <= group_q;
            group_neg_q <= group_neg_q;
            log_stride_q <= log_stride_q;
            neg_stride_q <= neg_stride_q;
        end else begin
            vmem_ops_state_q <= vmem_ops_state_d;
            vaddr_q <= vaddr_d;
            velem_cnt_q <= velem_cnt_d;
            masked_op_q <= masked_op_d;
            stride_q <= stride_d;
            req_tag_q <= req_tag_d;
            memp_instr_q <= memp_instr_d;
            vl_q <= vl_d;
            vsew_q <= vsew_d;
            acum_velem_incr_q <= acum_velem_incr_d;
            group_q <= group_d;
            group_neg_q <= group_neg_d;
            log_stride_q <= log_stride_d;
            neg_stride_q <= neg_stride_d;
        end
        // Read Mask
        if (ovi_mask_idx_valid_i) begin
            mask_buffer <= ovi_mask_idx_item_i;
        end
        // Read vstore data
        if (vstore_data_valid_i) begin
            vstore_buffer_q <= vstore_data_i;
        end else begin
            vstore_buffer_q <= vstore_buffer_d;
        end
    end
end

assign velem_id_o = velem_cnt_q;
assign velem_incr_o = velem_incr[DCACHE_RESP_DATA_LOG-3:0];
assign stall_o = (vmem_ops_state_q == SCALAR) ? 1'b0 : 1'b1;
assign end_o = end_int;
assign load_mask_o = load_mask;
assign misalign_xcpt_o = misalign_xcpt_int;

endmodule

