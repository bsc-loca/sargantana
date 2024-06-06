/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vmsbf.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Marc Clascà Ramírez
 * Email(s)       : marc.clasca@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Marc C.   | Initial write
 * -----------------------------------------------
 */



module vmsb_i_o_f 
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input instr_type_t          instr_type_i,   // Instruction type
    input sew_t                 sew_i,          // Element width
    input bus_simd_t            data_vs2_i,     // 64-bit source operand 2
    input bus_mask_t            data_vm,        // 16-bit mask
    input logic                 use_mask,        //
    output bus64_t              data_vd_o       // 64-bit result
);

// This module outputs a mask register that has all elements set until before the first active element set in source vs2

bus64_t result;
always_comb begin
    result = '0;
    if ((instr_type_i == VMSBF) || (instr_type_i == VMSIF) || (instr_type_i == VMSOF)) begin //to control power
        for (int i=0; (i<(VLEN/8)); ++i) begin
            if((instr_type_i == VMSOF)) begin
                if ((data_vm[i] & use_mask & data_vs2_i[i]) | (~use_mask & data_vs2_i[i])) begin
                    result[i] = 1;
                    break;    
                end
            end else begin    
                if ((data_vm[i] & use_mask & data_vs2_i[i]) | (data_vs2_i[i] & ~use_mask)) begin
                    if(instr_type_i == VMSIF) begin
                        result[i] = 1;
                    end
                    break;
                end else begin
                    result[i] = 1;
                end
            end
        end
    end else begin
        result = '0;
    end
end

assign data_vd_o = result;

endmodule
