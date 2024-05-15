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
    input bus_simd_t               data_vs2_i,     // 64-bit source operand 2
    input bus_mask_t            data_vm,        // 16-bit mask
    input logic                 use_mask,        //
    output bus64_t              data_vd_o       // 64-bit result
);

// This module outputs a mask register that has all elements set until before the first active element set in source vs2

bus64_t result;
logic[(VLEN/8)-1:1] data_vs2;

always_comb begin
    result = '0;
    data_vs2 = '0;
    if ((instr_type_i == VMSBF) || (instr_type_i == VMSIF) || (instr_type_i == VMSOF)) begin //to control power
        if ((instr_type_i == VMSBF)) begin
            result[0] = ~data_vs2_i[0] | ((~data_vm[0]) & use_mask); 
        end else if((instr_type_i == VMSOF)) begin
            result[0] = ((data_vm[0] & use_mask & data_vs2_i[0]) | (~use_mask & data_vs2_i[0]));
        end else begin //if VMSIF   
            result[0] = 1'b1; 
        end

        for (int i=1; (i<(VLEN/8)); ++i) begin
            //Vector change to reuse resources
            if ((instr_type_i == VMSBF) || (instr_type_i == VMSOF)) begin
                data_vs2[i] = data_vs2_i[i];
            end else begin
                data_vs2[i] = data_vs2_i[i-1];
            end

            if((instr_type_i == VMSOF)) begin
                if (result[i-1]) begin
                    break;
                end
                result[i] = ((data_vm[i] & use_mask & data_vs2_i[i]) | (~use_mask & data_vs2_i[i]));
            end else begin    
                result[i] = (~data_vs2[i] | ((~data_vm[i]) & use_mask)) & result[i-1];
            end
        end
    end else begin
        result = '0;
    end
end

assign data_vd_o = result;

endmodule
