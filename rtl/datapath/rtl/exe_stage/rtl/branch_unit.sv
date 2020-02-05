/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : branch_unit.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Rubén Langarita
 * Email(s)       : ruben.langarita@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author   | Description
 * -----------------------------------------------
 */
//`default_nettype none
import drac_pkg::*;


module branch_unit(
    input instr_type_t                  instr_type_i,

    input addrPC_t                      pc_i,
    input bus64_t                       data_rs1_i,
    input bus64_t                       data_rs2_i,
    input bus64_t                       imm_i,

    output branch_pred_decision_t       taken_o,
    output addrPC_t                     result_o,
    output addrPC_t			link_pc_o
);

logic equal;
logic less;
logic less_u;

addrPC_t  target;

// Calculate all posible conditions
assign equal = data_rs1_i == data_rs2_i;
assign less = $signed(data_rs1_i) < $signed(data_rs2_i);
assign less_u = data_rs1_i < data_rs2_i;

// Calculate target
always_comb begin
    case (instr_type_i)
        JAL: begin
            // Jal always puts a zero in the lower bit
            target = (pc_i + imm_i) & 64'hFFFFFFFFFFFFFFFE; 
        end
        JALR: begin
            // Jalr always puts a zero in the lower bit
            target = (data_rs1_i + imm_i) & 64'hFFFFFFFFFFFFFFFE;
        end
        BLT, BLTU, BGE, BGEU, BEQ, BNE: begin
            target = pc_i + imm_i;
        end
        default: begin
            target = 0;
        end
    endcase
end

// Calculate taken
always_comb begin
    case (instr_type_i)
        JAL: begin
            taken_o = PRED_NOT_TAKEN; // guillemlp this is done at decode stage
        end
        JALR: begin
            taken_o = PRED_TAKEN;
        end
        BEQ: begin   //branch on equal
            taken_o = (equal)? PRED_TAKEN : PRED_NOT_TAKEN;
        end
        BNE: begin //branch on not equal
            taken_o = (~equal)? PRED_TAKEN : PRED_NOT_TAKEN;
        end
        BLT: begin //branch on less than
            taken_o = (less)? PRED_TAKEN : PRED_NOT_TAKEN;
        end
        BGE: begin //branch on greater than or equal
            taken_o = (~less)? PRED_TAKEN : PRED_NOT_TAKEN;
        end
        BLTU: begin //branch if less than unsigned
            taken_o = (less_u)? PRED_TAKEN : PRED_NOT_TAKEN;
        end
        BGEU: begin //branch if greater than or equal unsigned
            taken_o = (~less_u)? PRED_TAKEN : PRED_NOT_TAKEN;
        end
        default: begin
            taken_o = PRED_NOT_TAKEN;
        end
    endcase
end

assign result_o = (taken_o == PRED_TAKEN)? target : pc_i + 4;
assign link_pc_o = pc_i + 4;

endmodule
//`default_nettype wire

