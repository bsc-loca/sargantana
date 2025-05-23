/*
 * Copyright 2025 BSC*
 * *Barcelona Supercomputing Center (BSC)
 * 
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 * 
 * Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 * may not use this file except in compliance with the License, or, at your
 * option, the Apache License version 2.0. You may obtain a copy of the
 * License at
 * 
 * https://solderpad.org/licenses/SHL-2.1/
 * 
 * Unless required by applicable law or agreed to in writing, any work
 * distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */

module functional_unit
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input wire                  clk_i,           // Clock
    input wire                  rstn_i,          // Reset
    input fu_id_t               fu_id_i,         // Functional Unit's ID
    input rr_exe_simd_instr_t   instruction_i,   // Instruction input
    input rr_exe_simd_instr_t   sel_out_instr_i, // Instruction to select the output result
    input vxrm_t                vxrm_i,          // Vector Fixed-Point Rounding Mode
    input bus64_t               data_vs1_i,      // 64-bit source operand 1
    input bus64_t               data_vs2_i,      // 64-bit source operand 2
    input bus64_t               data_vm,         // 64-bit mask operands
    output bus64_t              data_vd_o,       // 64-bit result
    output logic                sat_ovf_o        // Saturation done on overflow
);

bus64_t result_vaddsub;
bus64_t result_vwaddsub;
bus64_t result_vsaaddsub;
bus64_t result_vcomp;
bus64_t result_vshift;
bus64_t result_vmul;
bus64_t result_vdiv_vrem;
bus64_t result_vsmul;

bus128_t full_result_vmul;

bus64_t data1_vaddsub_i;
bus64_t data2_vaddsub_i;

sew_t vaddsub_sew_i;

bus64_t data2_vmul_i;

bus64_t result_vmul_2;
logic sat_ovf_saaddsub;

bus128_t full_result_vmul_2;
logic sat_vsmul;

/* Register fo multiplication + addition/subtract
 * Due to timing problems when doing the addition on the same cycle than the
 * output of the multiplication we need to add a register on the exit of the
 * multiplication module only when multiplication + addition/subtract
*/
always_ff@ (posedge clk_i, negedge rstn_i) begin
    if (~rstn_i) begin
        result_vmul_2 <= 64'b0;
        full_result_vmul_2 <= 128'b0;
    end
    else begin
        result_vmul_2 <= result_vmul;
        full_result_vmul_2 <= full_result_vmul;
    end
end


/* Change of SEW on vaddsub module for Vector Widening Multiply-Add
*/
always_comb begin
    case (sel_out_instr_i.instr.instr_type)
        VWMACC, VWMACCU, VWMACCUS, VWMACCSU: begin
            case (sel_out_instr_i.instr.sew)
                SEW_8: begin
                    vaddsub_sew_i = SEW_16;
                end
                SEW_16: begin
                    vaddsub_sew_i = SEW_32;
                end
                SEW_32: begin
                    vaddsub_sew_i = SEW_64;
                end
                default: begin
                    vaddsub_sew_i = SEW_64;
                end
            endcase
        end
        default: begin
            vaddsub_sew_i = sel_out_instr_i.instr.sew;
        end
    endcase

end

/* Input selection for vaddsub module
 * For the instructions that use the module directly send the input
 * for multiplication + addition/subtract select the inputs from the
 * vmul module and the other operand
*/
always_comb begin
    case (sel_out_instr_i.instr.instr_type)
        VADD, VSUB, VRSUB, VADC, VSBC, VMADC, VMSBC: begin
            data1_vaddsub_i = data_vs1_i;
            data2_vaddsub_i = data_vs2_i;
        end
        VMADD, VNMSUB: begin
            data1_vaddsub_i = result_vmul_2;
            data2_vaddsub_i = sel_out_instr_i.data_vs2[64*fu_id_i +: 64];
        end
        VMACC, VNMSAC, VWMACC, VWMACCU, VWMACCUS, VWMACCSU: begin
            data1_vaddsub_i = result_vmul_2;
            data2_vaddsub_i = sel_out_instr_i.data_old_vd[64*fu_id_i +: 64];
        end
        default: begin
            data1_vaddsub_i = data_vs1_i;
            data2_vaddsub_i = data_vs2_i;
        end
    endcase
end
/* Input selection for the second operand of the vmul module
 * For only multiplication instructions send vs2
 * For multiplication + addition/subtract select the input from the operand
 * needed
*/
always_comb begin
    case (instruction_i.instr.instr_type)
        VMUL, VMULH, VMULHU, VMULHSU, VWMUL, VWMULU, VWMULSU, VSMUL: begin
            data2_vmul_i = data_vs2_i;
        end
        VMADD, VNMSUB: begin
            data2_vmul_i = instruction_i.data_old_vd[64*fu_id_i +: 64];
        end
        VMACC, VNMSAC, VWMACC, VWMACCU, VWMACCUS, VWMACCSU: begin
            data2_vmul_i = data_vs2_i;
        end
        default: begin
            data2_vmul_i = data_vs2_i;
        end
    endcase
end

vaddsub vaddsub_inst(
    .instr_type_i  (sel_out_instr_i.instr.instr_type),
    .sew_i         (vaddsub_sew_i),
    .data_vs1_i    (data1_vaddsub_i),
    .data_vs2_i    (data2_vaddsub_i),
    .data_vm       (data_vm[7:0]),
    .use_mask      (sel_out_instr_i.instr.use_mask),
    .data_vd_o     (result_vaddsub)
);

vwaddsub vwaddsub_inst(
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.instr.sew),
    .data_vs1_i    (data_vs1_i[31:0]),
    .data_vs2_i    (data_vs2_i),
    .data_vd_o     (result_vwaddsub)
);

vsaaddsub vsaaddsub_inst(
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.instr.sew),
    .vxrm_i        (vxrm_i),
    .data_vs1_i    (data_vs1_i),
    .data_vs2_i    (data_vs2_i),
    .data_vd_o     (result_vsaaddsub),
    .sat_ovf_o     (sat_ovf_saaddsub)
);
vcomp vcomp_inst(
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.instr.sew),
    .data_vs1_i    (data_vs1_i),
    .data_vs2_i    (data_vs2_i),
    .data_vd_o     (result_vcomp)
);

vshift vshift_inst(
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.instr.sew),
    .vxrm_i        (vxrm_i),
    .data_vs1_i    (data_vs1_i),
    .data_vs2_i    (data_vs2_i),
    .data_vd_o     (result_vshift)
);

vmul vmul_inst(
    .clk_i         (clk_i),
    .rstn_i        (rstn_i),
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.instr.sew),
    .data_vs1_i    (data_vs1_i),
    .data_vs2_i    (data2_vmul_i),
    .data_vd_o     (result_vmul),
    .full_data_o   (full_result_vmul)
);

vsmul vsmul_inst(
    .sew_i         (sel_out_instr_i.instr.sew),
    .vxrm_i        (vxrm_i),
    .data_i        (full_result_vmul_2),
    .data_vd_o     (result_vsmul),
    .sat_ovf_o     (sat_vsmul)
);

vdiv vdiv_inst(
    .clk_i          (clk_i),          
    .rstn_i         (rstn_i),         
    .instr_type_i   (instruction_i.instr.instr_type),
    .instr_valid_i  (instruction_i.instr.valid),  
    .sew_i          (instruction_i.instr.sew),          
    .data_vs1_i     (data_vs1_i),     
    .data_vs2_i     (data_vs2_i),
    .exe_stages     (instruction_i.exe_stages),     
    .data_vd_o      (result_vdiv_vrem)       
);

bus64_t result_vnclip;
logic sat_ovf_vnclip;

vnclip vnclip_int(
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.instr.sew),
    .vxrm_i        (vxrm_i),
    .data_vs1_i    (data_vs1_i),
    .data_vs2_i    (data_vs2_i),
    .sat_ovf_o     (sat_ovf_vnclip),
    .data_vd_o     (result_vnclip)
);

always_comb begin
    sat_ovf_o = '0;
    case (sel_out_instr_i.instr.instr_type)
        VNCLIP, VNCLIPU: begin
            data_vd_o = result_vnclip;
            sat_ovf_o = sat_ovf_vnclip;
        end
        VZEXT_VF2, VSEXT_VF2, VZEXT_VF4, VSEXT_VF4, VZEXT_VF8, VSEXT_VF8: begin
            data_vd_o = data_vs2_i;
        end
        VADD, VSUB, VRSUB, VADC, VSBC, VMADC, VMSBC: begin
            data_vd_o = result_vaddsub;
        end
        VSADDU, VSADD, VSSUBU, VSSUB: begin
            data_vd_o = result_vsaaddsub;
            sat_ovf_o = sat_ovf_saaddsub;
        end
        VAADDU, VAADD, VASUBU, VASUB: begin
            data_vd_o = result_vsaaddsub;
        end
        VWADD, VWADDU, VWSUB, VWSUBU, VWADDW, VWADDUW, VWSUBW, VWSUBUW: begin
            data_vd_o = result_vwaddsub;
        end
        VMUL, VMULH, VMULHU, VMULHSU, VWMUL, VWMULU, VWMULSU: begin
            data_vd_o = result_vmul;
        end
        VSMUL: begin
            data_vd_o = result_vsmul;
            sat_ovf_o = sat_vsmul;
        end
        VMADD, VNMSUB, VMACC, VNMSAC: begin
            data_vd_o = result_vaddsub;
        end
        VWMACC, VWMACCU, VWMACCUS, VWMACCSU: begin
            data_vd_o = result_vaddsub;
        end
        VMIN, VMINU, VMAX, VMAXU, VMSEQ, VMSNE, VMSLTU, VMSLT, VMSLEU, VMSLE, VMSGTU, VMSGT, VCNT: begin
            data_vd_o = result_vcomp;
        end
        VAND: begin
            data_vd_o = data_vs1_i & data_vs2_i;
        end
        VOR: begin
            data_vd_o = data_vs1_i | data_vs2_i;
        end
        VXOR: begin
            data_vd_o = data_vs1_i ^ data_vs2_i;
        end
        VMAND, VMNAND, VMANDN, VMOR, VMNOR, VMORN, VMXNOR,VMXOR: begin
            data_vd_o = '1;
            case (sel_out_instr_i.instr.sew)
                SEW_8: begin
                    for (int i = 0; i<(VLEN/8); ++i) begin
                        data_vd_o[i] = (sel_out_instr_i.instr.instr_type == VMAND)  ? (data_vs1_i[i] & data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMNAND) ? !(data_vs1_i[i] & data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMANDN) ? (!data_vs1_i[i] & data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMNOR)  ? !(data_vs1_i[i] | data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMORN)  ? (!data_vs1_i[i] | data_vs2_i[i]) :                                          
                                       (sel_out_instr_i.instr.instr_type == VMOR)   ? (data_vs1_i[i] | data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMXNOR) ? !(data_vs1_i[i] ^ data_vs2_i[i]) :                                       
                                                                                      (data_vs1_i[i] ^ data_vs2_i[i]);
                    end
                end
                SEW_16: begin
                    for (int i = 0; i<(VLEN/16); ++i) begin
                        data_vd_o[i] = (sel_out_instr_i.instr.instr_type == VMAND) ? (data_vs1_i[i] & data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMNAND) ? !(data_vs1_i[i] & data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMANDN) ? (!data_vs1_i[i] & data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMNOR)  ? !(data_vs1_i[i] | data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMORN)  ? (!data_vs1_i[i] | data_vs2_i[i]) :                                          
                                       (sel_out_instr_i.instr.instr_type == VMOR)  ? (data_vs1_i[i] | data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMXNOR)  ? !(data_vs1_i[i] ^ data_vs2_i[i]) :
                                                                                     (data_vs1_i[i] ^ data_vs2_i[i]);
                    end
                end
                SEW_32: begin
                    for (int i = 0; i<(VLEN/32); ++i) begin
                        data_vd_o[i] = (sel_out_instr_i.instr.instr_type == VMAND) ? (data_vs1_i[i] & data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMNAND) ? !(data_vs1_i[i] & data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMANDN) ? (!data_vs1_i[i] & data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMNOR)  ? !(data_vs1_i[i] | data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMORN)  ? (!data_vs1_i[i] | data_vs2_i[i]) :                                          
                                       (sel_out_instr_i.instr.instr_type == VMOR)  ? (data_vs1_i[i] | data_vs2_i[i]) :
                                       (sel_out_instr_i.instr.instr_type == VMXNOR)  ? !(data_vs1_i[i] ^ data_vs2_i[i]) :
                                                                                     (data_vs1_i[i] ^ data_vs2_i[i]);
                    end
                end
                SEW_64: begin
                    for (int i = 0; i<(VLEN/64); ++i) begin
                        data_vd_o[i] = (sel_out_instr_i.instr.instr_type == VMAND) ? (data_vs1_i[i] & data_vs2_i[i]) :
                                    (sel_out_instr_i.instr.instr_type == VMNAND) ? !(data_vs1_i[i] & data_vs2_i[i]) :
                                    (sel_out_instr_i.instr.instr_type == VMANDN) ? (!data_vs1_i[i] & data_vs2_i[i]) :
                                    (sel_out_instr_i.instr.instr_type == VMNOR)  ? !(data_vs1_i[i] | data_vs2_i[i]) :
                                    (sel_out_instr_i.instr.instr_type == VMORN)  ? (!data_vs1_i[i] | data_vs2_i[i]) :                                     
                                    (sel_out_instr_i.instr.instr_type == VMOR)  ? (data_vs1_i[i] | data_vs2_i[i]) :
                                    (sel_out_instr_i.instr.instr_type == VMXNOR)  ? !(data_vs1_i[i] ^ data_vs2_i[i]) :
                                                                                  (data_vs1_i[i] ^ data_vs2_i[i]);
                    end
                end
            endcase
        end
        VSLL, VSRA, VSRL, VNSRL, VNSRA, VSSRL, VSSRA: begin
            data_vd_o = result_vshift;
        end
        VID: begin
            case (sel_out_instr_i.instr.sew)
                SEW_8: begin
                    for (int i = 0; i<8; ++i) begin
                        data_vd_o[(i*8)+:8] = (fu_id_i*8)+i;
                    end
                end
                SEW_16: begin
                    for (int i = 0; i<4; ++i) begin
                        data_vd_o[(i*16)+:16] = (fu_id_i*4)+i;
                    end
                end
                SEW_32: begin
                    for (int i = 0; i<2; ++i) begin
                        data_vd_o[(i*32)+:32] = (fu_id_i*2)+i;
                    end
                end
                SEW_64: begin
                    data_vd_o = fu_id_i;
                end
            endcase
        end
        VMERGE, VMV: begin
            data_vd_o = data_vs1_i;
        end
        VMV1R: begin
            data_vd_o = data_vs2_i;
        end
        VDIV, VDIVU, VREM, VREMU: begin
            data_vd_o = result_vdiv_vrem;
        end
        default: begin
            data_vd_o = 64'b0;
        end
    endcase
end

endmodule
