/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vfirst.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Marc Clascà Ramírez
 * Email(s)       : marc.clasca@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Marc C.   | Initial write
 * -----------------------------------------------
 */



module vfirst 
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input instr_type_t              instr_type_i,   // Instruction type
    input sew_t                     sew_i,          // Element width
    input bus_simd_t                data_vs2_i,     // 64-bit source operand 2
    input bus_mask_t                data_vm,        // 16-bit mask
    input logic                     use_mask,        //
    input logic[VMAXELEM_LOG:0]     vl_i,            // Current vector lenght in elements    
    output bus64_t                  data_rd_o       // 64-bit result
);

// This module computes the first (active) element of the vector mask source 2 set 1, and returns its index.
// This is implemented using an inverse priority encoder

bus_mask_t data_a_masked; 
bus64_t result;

assign data_a_masked = use_mask ? (data_vs2_i[((VLEN/8)-1):0] & data_vm) : data_vs2_i[((VLEN/8)-1):0];

always_comb begin
    result = {64{1'b1}};
    if(instr_type_i == VFIRST) begin 
        case (sew_i)
            SEW_8: begin
                for (int i = 0; (i < (VLEN/8)); ++i) begin
                    if(i < vl_i) begin
                        if(data_a_masked[i]) begin
                            result = i;
                            break;
                        end
                    end
                end
            end
            SEW_16: begin
                for (int i = 0; (i < (VLEN/16)); ++i) begin
                    if(i < vl_i) begin                    
                        if(data_a_masked[i]) begin
                            result = i;
                            break;
                        end
                    end
                end
            end
            SEW_32: begin
                for (int i = 0; (i < (VLEN/32)); ++i) begin
                    if(i < vl_i) begin
                        if(data_a_masked[i]) begin
                            result = i;
                            break;
                        end
                    end
                end
            end
            SEW_64: begin
                for (int i = 0; (i < (VLEN/64)); ++i) begin
                    if(i < vl_i) begin
                        if(data_a_masked[i]) begin
                            result = i;
                            break;
                        end
                    end
                end
            end
            default: begin
                for (int i = 0; (i < (VLEN/8)); ++i) begin
                    if(i < vl_i) begin
                        if(data_a_masked[i]) begin
                            result = i;
                            break;
                        end
                    end
                end
            end
        endcase
    end
end

assign data_rd_o = result;

endmodule
