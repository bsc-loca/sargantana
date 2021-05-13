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
 * -----------------------------------------------
 */

import drac_pkg::*;
import riscv_pkg::*;

module functional_unit (
    input fu_id_t               fu_id_i,        // Functional Unit's ID
    input rr_exe_simd_instr_t   instruction_i,  // Instruction input
    input bus64_t               data_vs1_i,     // 64-bit source operand 1
    input bus64_t               data_vs2_i,     // 64-bit source operand 2
    output bus64_t              data_vd_o       // 64-bit result
);

bus64_t result_vaddsub;
bus64_t result_vcomp;
bus64_t result_vshift;

vaddsub vaddsub_inst(
    .instr_type_i  (instruction_i.instr.instr_type),
    .sew_i         (instruction_i.sew),
    .data_vs1_i    (data_vs1_i),
    .data_vs2_i    (data_vs2_i),
    .data_vd_o     (result_vaddsub)
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

always_comb begin
    case (instruction_i.instr.instr_type)
        VADD, VSUB: begin
            data_vd_o = result_vaddsub;
        end
        VMIN, VMINU, VMAX, VMAXU, VMSEQ, VCNT: begin
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

        VSLL, VSRA, VSRL: begin
            data_vd_o = result_vshift;
        end

        VID: begin
            case (instruction_i.sew)
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
        VMV: begin
            data_vd_o = data_vs1_i;
        end
        default: begin
            data_vd_o = 64'b0;
        end
    endcase
end
endmodule
