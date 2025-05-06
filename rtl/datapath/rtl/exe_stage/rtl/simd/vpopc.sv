/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vpopc.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Juan Antonio Rodriguez
 * Email(s)       : juan.rodriguez4@bsc.es
 * -----------------------------------------------
 */
 
import drac_pkg::*;
import riscv_pkg::*;

module vpopc (
    input instr_type_t              instr_type_i,   // Instruction type
    input sew_t                     sew_i,          // Element width
    input bus_simd_t                data_vs2_i,     // bus_simd_t source operand 2
    input bus_mask_t                data_vm_i,      // 64-bit mask
    input logic                     use_mask_i,     
    input logic[VMAXELEM_LOG:0]     vl_i,            // Current vector lenght in elements    
    output bus64_t                  data_vd_o       // 64-bit result
);
function [63:0] trunc_64bits(input [64:0] val_in);
    trunc_64bits = val_in[63:0];
endfunction

logic [63:0] count;

always_comb begin
    count = '0;
    if(instr_type_i == VPOPC) begin 
        unique case (sew_i)
            SEW_8 : begin
                for (int i = 0; i < (VLEN/8); i++) begin
                    if(i < vl_i) begin  
                        if (use_mask_i) begin
                            count = trunc_64bits(count + {{(XLEN-1){1'b0}}, (data_vs2_i[i] & data_vm_i[i])});
                        end else begin
                            count = trunc_64bits(count + {{(XLEN-1){1'b0}}, data_vs2_i[i]});
                        end
                    end else begin
                        count = count;    
                    end                        
                end                
            end
            SEW_16 : begin
                for (int i = 0; i < (VLEN/16); i++) begin
                    if(i < vl_i) begin                     
                        if (use_mask_i) begin
                            count = trunc_64bits(count + {{(XLEN-1){1'b0}}, (data_vs2_i[i] & data_vm_i[i])});
                        end else begin
                            count = trunc_64bits(count + {{(XLEN-1){1'b0}}, data_vs2_i[i]}); 
                        end
                    end else begin
                        count = count;
                    end
                end
            end
            SEW_32 : begin
                for (int i = 0; i < (VLEN/32); i++) begin
                    if(i < vl_i) begin 
                        if (use_mask_i) begin
                            count = trunc_64bits(count + {{(XLEN-1){1'b0}}, (data_vs2_i[i] & data_vm_i[i])});
                        end else begin
                            count = trunc_64bits(count + {{(XLEN-1){1'b0}}, data_vs2_i[i]});
                        end
                    end else begin
                        count = count;
                    end
                end
            end

            SEW_64 : begin
                for (int i = 0; i < (VLEN/64); i++) begin
                    if(i < vl_i) begin 
                        if (use_mask_i) begin
                            count = trunc_64bits(count + {{(XLEN-1){1'b0}}, (data_vs2_i[i] & data_vm_i[i])});
                        end else begin
                            count = trunc_64bits(count + {{(XLEN-1){1'b0}}, data_vs2_i[i]});
                        end
                    end else begin
                        count = count;
                    end
                end
            end
            default : begin
                count = '0;
            end
        endcase
    end
end

assign data_vd_o = count;

endmodule
