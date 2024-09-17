/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : execution.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Victor Soria Pardos
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 * -----------------------------------------------
 */
//`default_nettype none

 module exe_stage 
    import drac_pkg::*;
    import riscv_pkg::*;
#(
    parameter drac_pkg::drac_cfg_t DracCfg     = drac_pkg::DracDefaultConfig
)(
    input logic                         clk_i,
    input logic                         rstn_i,
    input logic                         kill_i,
    input logic                         flush_i,
    input logic                         en_ld_st_translation_i, // virtualization mechanism enabled

    // INPUTS
    input rr_exe_instr_t                from_rr_i,
    input resp_dcache_cpu_t             resp_dcache_cpu_i,      // Response from dcache interface
    input logic [VMAXELEM_LOG:0]        vl_i,
    input vxrm_t                        vxrm_i,

    input logic [1:0]                   commit_store_or_amo_i, // Signal to execute stores and atomics in commit
    input gl_index_t                    commit_store_or_amo_gl_idx_i,  // Signal from commit enables writes.
    input tlb_cache_comm_t              dtlb_comm_i,
    input logic [VMAXELEM_LOG:0]        vl_id_exe_i,
    // OUTPUTS
    output exe_wb_scalar_instr_t        arith_to_scalar_wb_o,
    output exe_wb_scalar_instr_t        mem_to_scalar_wb_o,
    output exe_wb_scalar_instr_t        simd_to_scalar_wb_o,
    output exe_wb_scalar_instr_t        fp_to_scalar_wb_o,
    output exe_wb_scalar_instr_t        mul_div_to_scalar_wb_o,
    output exe_wb_simd_instr_t          simd_to_simd_wb_o,
    output exe_wb_simd_instr_t          mem_to_simd_wb_o,
    output exe_wb_fp_instr_t            mem_to_fp_wb_o,
    output exe_wb_fp_instr_t            fp_to_wb_o,
    output exe_cu_t                     exe_cu_o,
    output logic                        mem_commit_stall_o,     // Stall commit stage
    output exception_t                  exception_mem_commit_o, // Exception to commit
    output logic                        mem_store_or_amo_o,     // Inst at mem to do request is a Store or AMO
    output gl_index_t                   mem_gl_index_o,         // Index of the mem inst to do request

    output exception_t                  ex_gl_o,                // Exception generated on the execution stage
    output gl_index_t                   ex_gl_index_o,          // GL tag of the exception generated

    output req_cpu_dcache_t             req_cpu_dcache_o,       // Request to dcache interface 
    output logic                        correct_branch_pred_o,  // Decides if the branch prediction was correct  
    output exe_if_branch_pred_t         exe_if_branch_pred_o,   // Branch prediction (taken, target) and result (take, target)
    output cache_tlb_comm_t             dtlb_comm_o,
    output logic [VMAXELEM_LOG:0]       vleff_vl_o,

    input logic [1:0] priv_lvl_i,

    `ifdef SIM_COMMIT_LOG
    output addr_t                store_addr_o,
    output bus_simd_t            store_data_o,
    `endif

    //--PMU
    output logic                        pmu_is_branch_o,
    output logic                        pmu_branch_taken_o,                    
    output logic                        pmu_stall_mem_o,
    output logic                        pmu_exe_ready_o,
    output logic                        pmu_struct_depend_stall_o,
    output logic                        pmu_load_after_store_o
);

function [VMAXELEM_LOG:0] trunc_7_vmaxelem_log(input [6:0] val_in);
  trunc_7_vmaxelem_log = val_in[VMAXELEM_LOG:0];
endfunction

// Declarations
bus64_t rs1_data_def;
bus_simd_t rs2_data_def;

rr_exe_arith_instr_t arith_instr;
rr_exe_mem_instr_t   mem_instr;
rr_exe_mem_instr_t   vagu_mem_instr;
rr_exe_simd_instr_t  simd_instr;

exe_wb_scalar_instr_t alu_to_scalar_wb;
exe_wb_scalar_instr_t mul_to_scalar_wb;
exe_wb_scalar_instr_t div_to_scalar_wb;
exe_wb_scalar_instr_t branch_to_scalar_wb;
exe_wb_scalar_instr_t mem_to_scalar_wb;
exe_wb_scalar_instr_t simd_to_scalar_wb;
exe_wb_simd_instr_t mem_to_simd_wb;
exe_wb_simd_instr_t simd_to_simd_wb;
rr_exe_fpu_instr_t   fp_instr;
exe_wb_scalar_instr_t fp_to_scalar_wb;
exe_wb_fp_instr_t     mem_to_fp_wb;
exe_wb_fp_instr_t     fp_to_wb;

logic stall_mem;
logic stall_vagu;
logic stall_int;
logic stall_simd;
logic stall_simd_int;
logic stall_fpu_int;
logic stall_fpu;
logic empty_mem;

logic ready;
logic set_mul_32_inst;
logic set_mul_64_inst;
logic set_div_32_inst;
logic set_div_64_inst;
logic ready_1cycle_inst;
logic ready_mul_32_inst; 
logic ready_mul_64_inst;
logic ready_div_32_inst;

logic div_unit_sel;
logic ready_div_unit;

logic [3:0] simd_exe_stages;

exception_t mem_ex_int;
gl_index_t mem_ex_index_int;

logic vagu_mask_valid;
logic [2:0] vagu_mop;
logic [VLEN+VMAXELEM-1:0] vagu_mask;
logic vagu_store_data_valid;
logic [VMAXELEM_LOG:0] vagu_vl;
logic vmem_unit_stride;
bus64_t vagu_stride;

// Bypasses
`ifdef ASSERTIONS
    always @(posedge clk_i) begin
        if(from_rr_i.prs1 == 0)
            assert rs1_data_def==0;
        if(from_rr_i.prs2 == 0)
            assert rs2_data_def==0;
    end
`endif

assign vmem_unit_stride = ((from_rr_i.instr.instr_type == VSE) || (from_rr_i.instr.instr_type == VSM) || (from_rr_i.instr.instr_type == VS1R) ||
                           (from_rr_i.instr.instr_type == VLEFF)) ? 1'b1 : 1'b0;

// Select rs2 from imm to avoid bypasses
assign rs1_data_def = from_rr_i.instr.use_pc ? from_rr_i.instr.pc : from_rr_i.data_rs1;
assign rs2_data_def = from_rr_i.instr.use_imm ? from_rr_i.instr.imm : from_rr_i.data_rs2;

score_board_scalar score_board_scalar_inst(
    .clk_i            (clk_i),
    .rstn_i           (rstn_i),
    .flush_i          (flush_i),
    .set_mul_32_i     (set_mul_32_inst),               
    .set_mul_64_i     (set_mul_64_inst),               
    .set_div_32_i     (set_div_32_inst),               
    .set_div_64_i     (set_div_64_inst),
    .ready_1cycle_o   (ready_1cycle_inst),
    .ready_mul_32_o   (ready_mul_32_inst),
    .ready_mul_64_o   (ready_mul_64_inst),
    .ready_div_32_o   (ready_div_32_inst),
    .div_unit_sel_o   (div_unit_sel),
    .ready_div_unit_o (ready_div_unit)
);

`ifndef DISABLE_SIMD
score_board_simd score_board_simd_inst(
    .clk_i               (clk_i),
    .rstn_i              (rstn_i),
    .flush_i             (flush_i),
    .ready_i             (ready),
    .instr_entry_i       (simd_instr.instr),
    .sew_i               (simd_instr.instr.sew),
    .simd_exe_stages_o   (simd_exe_stages),
    .stall_simd_o        (stall_simd)
);
`endif

assign ready = from_rr_i.instr.valid & ( (from_rr_i.rdy1 | from_rr_i.instr.use_pc) 
                                     & (from_rr_i.rdy2 | from_rr_i.instr.use_imm) 
                                     & (from_rr_i.frdy1) & (from_rr_i.frdy2) & (from_rr_i.frdy3) 
                                     & (from_rr_i.vrdy1) & (from_rr_i.vrdy2)
                                     & (from_rr_i.vrdy_old_vd) & (from_rr_i.vrdym));

always_comb begin
    arith_instr.data_rs1            = rs1_data_def;
    arith_instr.data_rs2            = rs2_data_def[63:0];
    arith_instr.prs1                = from_rr_i.prs1;
    arith_instr.rdy1                = from_rr_i.rdy1;
    arith_instr.prs2                = from_rr_i.prs2;
    arith_instr.rdy2                = from_rr_i.rdy2;
    arith_instr.prd                 = from_rr_i.prd;
    arith_instr.old_prd             = from_rr_i.old_prd;
    arith_instr.old_pvd             = from_rr_i.old_pvd;
    arith_instr.checkpoint_done     = from_rr_i.checkpoint_done;
    arith_instr.chkp                = from_rr_i.chkp;
    arith_instr.gl_index            = from_rr_i.gl_index;
    arith_instr.instr               = from_rr_i.instr;
    arith_instr.vl                  = (from_rr_i.instr.valid && 
                                        ((from_rr_i.instr.instr_type == VSETVL)  ||
                                         (from_rr_i.instr.instr_type == VSETVLI)) && 
                                            !((from_rr_i.instr.rs1 == 'h0) &&
                                              (from_rr_i.instr.rd == 'h0))
                                      ) ? vl_id_exe_i : from_rr_i.instr.vl;

    mem_instr.data_rs1            = from_rr_i.data_rs1;
    mem_instr.data_rs2            = from_rr_i.data_rs2;
    mem_instr.data_old_vd         = from_rr_i.data_old_vd;
    mem_instr.data_vm             = from_rr_i.data_vm;
    mem_instr.sew                 = from_rr_i.instr.sew;
    mem_instr.prs1                = from_rr_i.prs1;
    mem_instr.rdy1                = from_rr_i.rdy1;
    mem_instr.prs2                = from_rr_i.prs2;
    mem_instr.rdy2                = from_rr_i.rdy2;
    mem_instr.prd                 = from_rr_i.prd;
    mem_instr.pvd                 = from_rr_i.pvd;
    mem_instr.fprd                = from_rr_i.fprd;
    mem_instr.checkpoint_done     = from_rr_i.checkpoint_done;
    mem_instr.chkp                = from_rr_i.chkp;
    mem_instr.gl_index            = from_rr_i.gl_index;
    mem_instr.old_prd             = from_rr_i.old_prd;
    mem_instr.old_pvd             = from_rr_i.old_pvd;
    mem_instr.old_fprd            = from_rr_i.old_fprd;
    mem_instr.translated          = 1'b0;
    mem_instr.ex                  = 0;
    mem_instr.instr               = from_rr_i.instr;
    mem_instr.instr.instr_type    = from_rr_i.instr.instr_type;
    mem_instr.is_amo_or_store     = (from_rr_i.instr.mem_type == STORE) || (from_rr_i.instr.mem_type == AMO);
    mem_instr.is_store            = from_rr_i.instr.mem_type == STORE;               
    mem_instr.is_amo              = from_rr_i.instr.mem_type == AMO;
    mem_instr.vl                  = from_rr_i.instr.vl;
    mem_instr.agu_req_tag = '0;
    mem_instr.vmisalign_xcpt = 0;              
    mem_instr.velem_id = '0;  
    mem_instr.load_mask = '0;     
    mem_instr.velem_off = '0;
    mem_instr.velem_incr = '0;
    mem_instr.neg_stride = 0;

    fp_instr.data_rs1             = rs1_data_def;
    fp_instr.data_rs2             = rs2_data_def[63:0];
    fp_instr.data_rs3             = from_rr_i.data_rs3;
    fp_instr.fprs1                = from_rr_i.fprs1;
    fp_instr.frdy1                = from_rr_i.frdy1;
    fp_instr.fprs2                = from_rr_i.fprs2;
    fp_instr.frdy2                = from_rr_i.frdy2;
    fp_instr.fprs3                = from_rr_i.fprs3;
    fp_instr.frdy3                = from_rr_i.frdy3;
    fp_instr.fprd                 = from_rr_i.instr.regfile_we ? from_rr_i.prd : from_rr_i.fprd;
    fp_instr.old_fprd             = from_rr_i.old_fprd;
    fp_instr.checkpoint_done      = from_rr_i.checkpoint_done;
    fp_instr.chkp                 = from_rr_i.chkp;
    fp_instr.gl_index             = from_rr_i.gl_index;
    fp_instr.instr                = from_rr_i.instr;

    simd_instr.data_rs1            = from_rr_i.data_rs1;
    simd_instr.data_vs1            = from_rr_i.data_vs1;
    simd_instr.data_vs2            = from_rr_i.data_vs2;
    simd_instr.data_old_vd         = from_rr_i.data_old_vd;
    simd_instr.data_vm             = from_rr_i.data_vm;

    simd_instr.pvs1                = from_rr_i.pvs1;
    simd_instr.vrdy1               = from_rr_i.vrdy1;
    simd_instr.pvs2                = from_rr_i.pvs2;
    simd_instr.vrdy2               = from_rr_i.vrdy2;
    simd_instr.vrdy_old_vd         = from_rr_i.vrdy_old_vd;
    simd_instr.prd                 = from_rr_i.prd;
    simd_instr.pvd                 = from_rr_i.pvd;
    simd_instr.old_prd             = from_rr_i.old_prd;
    simd_instr.old_pvd             = from_rr_i.old_pvd;
    simd_instr.checkpoint_done     = from_rr_i.checkpoint_done;
    simd_instr.chkp                = from_rr_i.chkp;
    simd_instr.gl_index            = from_rr_i.gl_index;
    simd_instr.instr               = from_rr_i.instr;
    simd_instr.exe_stages          = simd_exe_stages;

    if (stall_int || kill_i) begin
        arith_instr.instr.valid   = 1'b0;
        mem_instr.instr.valid     = 1'b0;
        fp_instr.instr.valid      = 1'b0;
        simd_instr.instr.valid    = 1'b0;
    end else begin
        simd_instr.instr.valid = (stall_simd_int || (simd_instr.instr.unit != UNIT_SIMD)) ? 1'b0 : from_rr_i.instr.valid;
    end

    if (~ready || kill_i) begin
        fp_instr.instr      = '0;
    end else begin
        fp_instr.instr      = from_rr_i.instr;
    end
end

alu alu_inst (
    .instruction_i  (arith_instr),
    .instruction_o  (alu_to_scalar_wb)
);

  mul_unit mul_unit_inst (
    .clk_i         (clk_i           ),
    .rstn_i        (rstn_i          ),
    .flush_mul_i   (flush_i         ),
    .instruction_i (arith_instr     ),
    .instruction_o (mul_to_scalar_wb)
  );

div_unit div_unit_inst (
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    .flush_div_i    (flush_i),
    .div_unit_sel_i (div_unit_sel),
    .instruction_i  (arith_instr),
    .instruction_o  (div_to_scalar_wb)
);

branch_unit branch_unit_inst (
    .instruction_i      (arith_instr),
    .instruction_o      (branch_to_scalar_wb)
);

`ifndef DISABLE_SIMD
simd_unit simd_unit_inst (
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    .flush_i        (flush_i),
    .vxrm_i         (vxrm_i),
    .instruction_i  (simd_instr),
    .instruction_scalar_o (simd_to_scalar_wb),
    .instruction_simd_o  (simd_to_simd_wb)
);
`else
assign simd_to_scalar_wb.valid = 1'b0;
assign simd_to_simd_wb.valid = 1'b0;
`endif

`ifndef DISABLE_SIMD
assign vagu_vl = ((from_rr_i.instr.instr_type == VLM)  || (from_rr_i.instr.instr_type == VSM))  ? (vl_i[VMAXELEM_LOG:0] + 'd7) >> 3 : 
                 ((from_rr_i.instr.instr_type == VL1R) || (from_rr_i.instr.instr_type == VS1R)) ? trunc_7_vmaxelem_log(VMAXELEM >> from_rr_i.instr.mem_size[1:0]) :
                 from_rr_i.instr.vl[VMAXELEM_LOG:0];
assign vagu_mask_valid = (mem_instr.instr.use_mask | ((mem_instr.instr.instr_type == VLXE) || (mem_instr.instr.instr_type == VSXE))) & !stall_vagu;
assign vagu_mop = ((mem_instr.instr.instr_type == VLSE) || (mem_instr.instr.instr_type == VSSE)) ? 3'b010 : 
                  ((mem_instr.instr.instr_type == VLXE) || (mem_instr.instr.instr_type == VSXE)) ? 3'b011 : 3'b000;
assign vagu_store_data_valid = mem_instr.instr.valid && 
                            ((mem_instr.instr.instr_type == VSE)
                            || (mem_instr.instr.instr_type == VSM)
                            || (mem_instr.instr.instr_type == VS1R)
                            || (mem_instr.instr.instr_type == VSSE) 
                            || (mem_instr.instr.instr_type == VSXE)) 
                            && !stall_vagu;

always_comb begin
    vagu_mask = 'h0;
    vagu_stride = from_rr_i.data_rs2;
    if (mem_instr.instr.instr_type == VLXE) begin
        vagu_mask[VLEN+VMAXELEM-1:VMAXELEM] = from_rr_i.data_vs2;
    end else begin
        vagu_mask[VLEN+VMAXELEM-1:VMAXELEM] = from_rr_i.data_vs1;
    end
    case (mem_instr.sew)
        SEW_8: begin
            vagu_mask[VMAXELEM-1:0] = mem_instr.data_vm;
        end
        SEW_16: begin
            for (int i = 0; i<(VLEN/16); ++i) begin
                vagu_mask[i] = mem_instr.data_vm[i];  
            end
        end
        SEW_32: begin
            for (int i = 0; i<(VLEN/32); ++i) begin
                vagu_mask[i] = mem_instr.data_vm[i];  
            end
        end
        default: begin
            for (int i = 0; i<(VLEN/64); ++i) begin
                vagu_mask[i] = mem_instr.data_vm[i];  
            end
        end
    endcase
    if (vmem_unit_stride) begin
        case (mem_instr.instr.mem_size)
            4'b0000: vagu_stride = 'h1;
            4'b0101: vagu_stride = 'h2;
            4'b0110: vagu_stride = 'h4;
            4'b0111: vagu_stride = 'h8;
        endcase
    end
end

vagu #(
    .DCACHE_RESP_DATA_WIDTH(VLEN),
    .DCACHE_RESP_MAXELEM(VMAXELEM),
    .MAX_VELEM(VMAXELEM)
) vagu_inst (
    .clk_i      (clk_i),
    .rstn_i     (rstn_i),
    .memp_instr_i(mem_instr),
    .flush_i(flush_i),
    .stall_i(stall_mem),
    .ovi_mask_idx_valid_i(vagu_mask_valid),
    .ovi_mask_idx_item_i(vagu_mask),
    .vsew_i(mem_instr.sew),
    .mop_i(vagu_mop),
    .vl_i(vagu_vl),
    .stride_i(vagu_stride),
    .masked_op_i(mem_instr.instr.use_mask),
    .vstore_data_valid_i(vagu_store_data_valid),
    .vstore_data_i(from_rr_i.data_vs2),
    .stall_o(stall_vagu),
    .end_o(),
    .misalign_xcpt_o(),
    .velem_incr_o(),
    .velem_id_o(),
    .load_mask_o(),
    .memp_instr_o(vagu_mem_instr)
);
`else // `ifndef DISABLE_SIMD
    assign stall_vagu = 1'b0;
    always_comb begin
        vagu_mem_instr = mem_instr;
        vagu_mem_instr.vmisalign_xcpt = 1'b0;
        vagu_mem_instr.velem_id = 'h0;
        vagu_mem_instr.load_mask = '1;
        vagu_mem_instr.velem_off = 'h0;
        vagu_mem_instr.velem_incr = '1; 
    end
`endif

mem_unit #(
    .DracCfg(DracCfg)
) mem_unit_inst (
    .clk_i                  (clk_i),
    .rstn_i                 (rstn_i),
    .en_ld_st_translation_i (en_ld_st_translation_i),
    .instruction_i          (vagu_mem_instr),
    .flush_i                (flush_i),
    .kill_i                 (1'b0),
    .resp_dcache_cpu_i      (resp_dcache_cpu_i),
    .commit_store_or_amo_i  (commit_store_or_amo_i),
    .commit_store_or_amo_gl_idx_i  (commit_store_or_amo_gl_idx_i),
    .dtlb_comm_i(dtlb_comm_i),
    .dtlb_comm_o(dtlb_comm_o),
    .priv_lvl_i(priv_lvl_i),
//    .vl_i(vl_i),
    .req_cpu_dcache_o       (req_cpu_dcache_o),
    .instruction_scalar_o   (mem_to_scalar_wb),
    .instruction_simd_o     (mem_to_simd_wb),
    .instruction_fp_o       (mem_to_fp_wb),
    .exception_mem_commit_o (exception_mem_commit_o),
    .mem_commit_stall_o     (mem_commit_stall_o),
    .mem_store_or_amo_o     (mem_store_or_amo_o),
    .mem_gl_index_o         (mem_gl_index_o),
    .lock_o                 (stall_mem),
    .empty_o                (empty_mem),
    .vleff_vl_o             (vleff_vl_o),

    `ifdef SIM_COMMIT_LOG
    .store_addr_o(store_addr_o),
    .store_data_o(store_data_o),
    `endif
    
    .pmu_load_after_store_o (pmu_load_after_store_o)
);

fpu_drac_wrapper fpu_drac_wrapper_inst (
   .clk_i                   (clk_i),
   .rstn_i                  (rstn_i),
   .flush_i                 (flush_i),
   .stall_wb_i              (simd_instr.instr.valid & (simd_instr.instr.unit == UNIT_SIMD) & simd_instr.instr.regfile_we), // TODO: (gerard) check it
   .instruction_i           (fp_instr),
   .instruction_o           (fp_to_wb),
   .instruction_scalar_o    (fp_to_scalar_wb),
   .stall_o                 (stall_fpu)
);

always_comb begin
    if (mem_to_scalar_wb.valid | mem_to_fp_wb.valid | mem_to_simd_wb.valid) begin
        mem_to_scalar_wb_o  = mem_to_scalar_wb;
        mem_to_simd_wb_o    = mem_to_simd_wb;
        mem_to_fp_wb_o      = mem_to_fp_wb;
    end else begin
        mem_to_scalar_wb_o  = 'h0;
        mem_to_simd_wb_o    = 'h0;
        mem_to_fp_wb_o      = 'h0;
    end

    if (mul_to_scalar_wb.valid) begin
        mul_div_to_scalar_wb_o = mul_to_scalar_wb;
    end else if (div_to_scalar_wb.valid) begin
        mul_div_to_scalar_wb_o = div_to_scalar_wb;
    end else begin
        mul_div_to_scalar_wb_o = 'h0;
    end
    
    if (alu_to_scalar_wb.valid) begin
        arith_to_scalar_wb_o = alu_to_scalar_wb;
    end else if (branch_to_scalar_wb.valid) begin
        arith_to_scalar_wb_o = branch_to_scalar_wb;
    end else begin
        arith_to_scalar_wb_o = 'h0;
    end

    simd_to_scalar_wb_o = (simd_to_scalar_wb.valid) ? simd_to_scalar_wb : 'h0;
    simd_to_simd_wb_o = (simd_to_simd_wb.valid) ? simd_to_simd_wb : 'h0;

    // FP write-back struct
    if (fp_to_wb.valid | fp_to_scalar_wb.valid) begin
        fp_to_wb_o  = fp_to_wb;
        fp_to_scalar_wb_o = fp_to_scalar_wb;
    end else begin
        fp_to_wb_o = 'h0;
        fp_to_scalar_wb_o = 'h0;
    end
end

always_comb begin
    stall_int = 1'b0;
    stall_simd_int = 1'b0;
    set_div_32_inst = 1'b0;
    set_div_64_inst = 1'b0;
    set_mul_32_inst = 1'b0;
    set_mul_64_inst = 1'b0;
    pmu_stall_mem_o = 1'b0; 
    stall_fpu_int   = 1'b0;
    if (from_rr_i.instr.valid && !kill_i) begin
        if ((from_rr_i.instr.unit == UNIT_DIV) & from_rr_i.instr.op_32) begin
            stall_int = ~ready | ~ready_div_32_inst | ~ready_div_unit;
            set_div_32_inst = ready & ready_div_32_inst & ready_div_unit;
        end
        else if ((from_rr_i.instr.unit == UNIT_DIV) & ~from_rr_i.instr.op_32) begin
            stall_int = ~ready | ~ready_div_unit;
            set_div_64_inst = ready & ready_div_unit;
        end
        else if ((from_rr_i.instr.unit == UNIT_MUL) & from_rr_i.instr.op_32) begin
            stall_int = ~ready | ~ready_mul_32_inst;
            set_mul_32_inst = ready & ready_mul_32_inst;
        end
        else if ((from_rr_i.instr.unit == UNIT_MUL )& ~from_rr_i.instr.op_32) begin
            stall_int = ~ready | ~ready_mul_64_inst;
            set_mul_64_inst = ready & ready_mul_64_inst;
        end
        else if ((from_rr_i.instr.unit == UNIT_ALU) | (from_rr_i.instr.unit == UNIT_BRANCH) | (from_rr_i.instr.unit == UNIT_SYSTEM)) begin
            stall_int = ~ready;
        end
        else if (from_rr_i.instr.unit == UNIT_MEM) begin
            stall_int = stall_mem | stall_vagu | (~ready);
            pmu_stall_mem_o = stall_mem | stall_vagu | (~ready);
        end
        else if (from_rr_i.instr.unit == UNIT_FPU) begin
            stall_fpu_int = stall_fpu;
            stall_int = (~ready);
        end
        else if (from_rr_i.instr.unit == UNIT_SIMD) begin
            stall_simd_int = stall_simd;
            stall_int = (~ready);
        end
    end
end

//exception check
always_comb begin
    // Generating the mem exception
    if (mem_to_scalar_wb.valid && mem_to_scalar_wb.ex.valid ) begin
        mem_ex_int = mem_to_scalar_wb.ex;
        mem_ex_index_int = mem_to_scalar_wb.gl_index;
    end else if (mem_to_fp_wb.valid && mem_to_fp_wb.ex.valid ) begin
        mem_ex_int = mem_to_fp_wb.ex;
        mem_ex_index_int = mem_to_fp_wb.gl_index;
    end else if (mem_to_simd_wb.valid && mem_to_simd_wb.ex.valid ) begin
        mem_ex_int = mem_to_simd_wb.ex;
        mem_ex_index_int = mem_to_simd_wb.gl_index;
    end else begin
        mem_ex_int  = 'h0;
        mem_ex_index_int    = 'h0;
    end


    // Generating the exception of the execution stage. Only the Mem unit and the branch unit can produce exceptions. We need to check which is older
    // It can be simplified since in this core a mem instruction at the exception stage is older than a branch instruction.
    if (mem_ex_int.valid) begin
        ex_gl_o = mem_ex_int;
        ex_gl_index_o = mem_ex_index_int;
    end else if (branch_to_scalar_wb.ex.valid) begin 
        ex_gl_o = branch_to_scalar_wb.ex;
        ex_gl_index_o = branch_to_scalar_wb.gl_index; 
    end else begin
        ex_gl_o = '0;
        ex_gl_index_o = '0; 
    end
end

// Correct prediction
always_comb begin
    if(branch_to_scalar_wb.valid)begin
        if (from_rr_i.instr.instr_type == JAL)begin
            correct_branch_pred_o = 1'b1;
        end else   
        if (((from_rr_i.instr.instr_type != BLT) && (from_rr_i.instr.instr_type != BLTU)) &&
            ((from_rr_i.instr.instr_type != BGE) && (from_rr_i.instr.instr_type != BGEU)) &&
            ((from_rr_i.instr.instr_type != BEQ) && (from_rr_i.instr.instr_type != BNE))  &&
            ((from_rr_i.instr.instr_type != JALR))) begin            
            correct_branch_pred_o = 1'b1; // Correct because Decode and Control Unit Already fixed the missprediciton
        end else begin
            if (from_rr_i.instr.bpred.is_branch) begin
                correct_branch_pred_o = (from_rr_i.instr.bpred.decision == branch_to_scalar_wb.branch_taken) &&
                                        ((from_rr_i.instr.bpred.decision == PRED_NOT_TAKEN) ||
                                         (from_rr_i.instr.bpred.pred_addr == branch_to_scalar_wb.result_pc));
            end else begin
                correct_branch_pred_o = ~branch_to_scalar_wb.branch_taken;
            end
        end
    end else begin
        correct_branch_pred_o = 1'b1;
    end
    
end

// Branch predictor required signals
// Program counter at Execution Stage
assign exe_if_branch_pred_o.pc_execution = from_rr_i.instr.pc; 
// Final address generated by branch in Execution Stage
assign exe_if_branch_pred_o.branch_addr_result_exe = (branch_to_scalar_wb.branch_taken == PRED_TAKEN) ? branch_to_scalar_wb.result_pc : branch_to_scalar_wb.result;
// Target Address generated by branch in Execution Stage 
assign exe_if_branch_pred_o.branch_addr_target_exe = branch_to_scalar_wb.result_pc;
// Taken or not taken branch result in Execution Stage
assign exe_if_branch_pred_o.branch_taken_result_exe = branch_to_scalar_wb.branch_taken == PRED_TAKEN;   
// The instruction in the Execution Stage is a branch
assign exe_if_branch_pred_o.is_branch_exe = ((from_rr_i.instr.instr_type == BLT)  |
                                             (from_rr_i.instr.instr_type == BLTU) |
                                             (from_rr_i.instr.instr_type == BGE)  |
                                             (from_rr_i.instr.instr_type == BGEU) |
                                             (from_rr_i.instr.instr_type == BEQ)  |
                                             (from_rr_i.instr.instr_type == BNE)  |
                                             (from_rr_i.instr.instr_type == JAL)  |
                                             (from_rr_i.instr.instr_type == JALR)) &
                                             arith_instr.instr.valid;
assign exe_if_branch_pred_o.vset_index = from_rr_i.instr.vset_index;   

                                             

// Data for the Control Unit
assign exe_cu_o.valid_1 = arith_to_scalar_wb_o.valid;
assign exe_cu_o.valid_2 = mem_to_scalar_wb_o.valid;
assign exe_cu_o.valid_3 = simd_to_simd_wb_o.valid;
//assign exe_cu_o.valid_4 = mul_div_to_scalar_wb_o.valid;
assign exe_cu_o.valid_fp = fp_to_wb_o.valid;
assign exe_cu_o.valid_fp_mem = mem_to_fp_wb_o.valid;
assign exe_cu_o.is_branch = exe_if_branch_pred_o.is_branch_exe;
assign exe_cu_o.branch_taken = arith_to_scalar_wb_o.branch_taken;
assign exe_cu_o.stall = stall_int || stall_fpu_int || stall_simd_int;
assign exe_cu_o.clear_vset_fence = (from_rr_i.instr.valid && from_rr_i.instr.stall_vset_fence && ~stall_int) ? 1'b1 : 1'b0;


//-PMU 
assign pmu_is_branch_o       = from_rr_i.instr.bpred.is_branch && from_rr_i.instr.valid;
assign pmu_branch_taken_o    = from_rr_i.instr.bpred.is_branch && from_rr_i.instr.bpred.decision && 
                               from_rr_i.instr.valid;
                               
//assign pmu_miss_prediction_o = !correct_branch_pred_o;

assign pmu_exe_ready_o = ready;
assign pmu_struct_depend_stall_o = ready && stall_int;

endmodule
