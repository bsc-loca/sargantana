/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : functional_unit.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Gerard Candón Arenas
 * Email(s)       : gerard.candon@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Gerard C. | 
 *  0.2        | Xavier C. | Adding vmul and vred
 * -----------------------------------------------
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
    input bus64_t               data_vs1_i,      // 64-bit source operand 1
    input bus64_t               data_vs2_i,      // 64-bit source operand 2
    output bus64_t              data_vd_o        // 64-bit result
);

bus64_t result_vaddsub;
bus64_t result_vwaddsub;
bus64_t result_vcomp;
bus64_t result_vshift;
bus64_t result_vmul;

vaddsub vaddsub_inst(
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.sew),
    .data_vm       (instruction_i.data_vm),
    .data_vs1_i    (data_vs1_i),
    .data_vs2_i    (data_vs2_i),
    .data_vd_o     (result_vaddsub)
);

vwaddsub vwaddsub_inst(
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.sew),
    .data_vs1_i    (data_vs1_i[31:0]),
    .data_vs2_i    (data_vs2_i),
    .data_vd_o     (result_vwaddsub)
);

vcomp vcomp_inst(
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.sew),
    .data_vs1_i    (data_vs1_i),
    .data_vs2_i    (data_vs2_i),
    .data_vd_o     (result_vcomp)
);

vshift vshift_inst(
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.sew),
    .data_vs1_i    (data_vs1_i),
    .data_vs2_i    (data_vs2_i),
    .data_vd_o     (result_vshift)
);

vmul vmul_inst(
    .clk_i         (clk_i),
    .rstn_i        (rstn_i),
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.sew),
    .data_vs1_i    (data_vs1_i),
    .data_vs2_i    (data_vs2_i),
    .data_vd_o     (result_vmul)
);

always_comb begin
    case (sel_out_instr_i.instr.instr_type)
        VADD, VSUB, VRSUB, VADC: begin
            data_vd_o = result_vaddsub;
        end
        VWADD, VWADDU, VWSUB, VWSUBU, VWADDW, VWADDUW, VWSUBW, VWSUBUW: begin
            data_vd_o = result_vwaddsub;
        end
        VMUL, VMULH, VMULHU, VMULHSU: begin
            data_vd_o = result_vmul;
        end
        VMIN, VMINU, VMAX, VMAXU, VMSEQ, VMSLTU, VMSLT, VMSLEU, VMSLE, VCNT: begin
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
        VMAND, VMOR, VMXOR: begin
            data_vd_o = '1;
            case (sel_out_instr_i.sew)
                SEW_8: begin
                    for (int i = 0; i<(VLEN/8); ++i) begin
                        data_vd_o[i] = (sel_out_instr_i.instr.instr_type == VMAND) ? data_vs1_i[i] & data_vs2_i[i] :
                                       (sel_out_instr_i.instr.instr_type == VMOR)  ? data_vs1_i[i] | data_vs2_i[i] :
                                                                                     data_vs1_i[i] ^ data_vs2_i[i];
                    end
                end
                SEW_16: begin
                    for (int i = 0; i<(VLEN/16); ++i) begin
                        data_vd_o[i] = (sel_out_instr_i.instr.instr_type == VMAND) ? data_vs1_i[i] & data_vs2_i[i] :
                                       (sel_out_instr_i.instr.instr_type == VMOR)  ? data_vs1_i[i] | data_vs2_i[i] :
                                                                                     data_vs1_i[i] ^ data_vs2_i[i];
                    end
                end
                SEW_32: begin
                    for (int i = 0; i<(VLEN/32); ++i) begin
                        data_vd_o[i] = (sel_out_instr_i.instr.instr_type == VMAND) ? data_vs1_i[i] & data_vs2_i[i] :
                                       (sel_out_instr_i.instr.instr_type == VMOR)  ? data_vs1_i[i] | data_vs2_i[i] :
                                                                                     data_vs1_i[i] ^ data_vs2_i[i];
                    end
                end
                SEW_64: begin
                    for (int i = 0; i<(VLEN/64); ++i) begin
                        data_vd_o = (sel_out_instr_i.instr.instr_type == VMAND) ? data_vs1_i[i] & data_vs2_i[i] :
                                    (sel_out_instr_i.instr.instr_type == VMOR)  ? data_vs1_i[i] | data_vs2_i[i] :
                                                                                  data_vs1_i[i] ^ data_vs2_i[i];
                    end
                end
            endcase
        end

        VSLL, VSRA, VSRL, VNSRL, VNSRA: begin
            data_vd_o = result_vshift;
        end

        VID: begin
            case (sel_out_instr_i.sew)
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
        VMERGE, VMV, VREDSUM, VREDAND, VREDOR, VREDXOR: begin
            data_vd_o = data_vs1_i;
        end
        default: begin
            data_vd_o = 64'b0;
        end
    endcase
end
endmodule
