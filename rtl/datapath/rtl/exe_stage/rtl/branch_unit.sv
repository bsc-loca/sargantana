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
    input instr_type_t  instr_type_i,

    input addrPC_t      pc_i,
    input bus64_t       data_rs1_i,
    input bus64_t       data_rs2_i,
    input bus64_t       imm_i,

    output logic        taken_o,
    output addrPC_t     target_o,
    output addrPC_t     result_o,

    output bus64_t      reg_data_o
);

logic equal;
logic less;
logic less_u;

// Calculate all posible conditions
assign equal = data_rs1_i == data_rs2_i;
assign less = $signed(data_rs1_i) < $signed(data_rs2_i);
assign less_u = data_rs1_i < data_rs2_i;

// Calculate target
always_comb begin
    case (instr_type_i)
        JAL: begin
            target_o = pc_i + imm_i;
        end
        JALR: begin
            target_o = data_rs1_i + imm_i;
        end
        BLT, BLTU, BGE, BGEU, BEQ, BNE: begin
            target_o = pc_i + imm_i;
        end
        default: begin
            target_o = 0;
        end
    endcase
end

// Calculate taken
always_comb begin
    case (instr_type_i)
        JAL: begin
            taken_o = 0; // guillemlp this is done at decode stage
        end
        JALR: begin
            taken_o = 1;
        end
        BEQ: begin   //branch on equal
            taken_o = equal;
        end
        BNE: begin //branch on not equal
            taken_o = ~equal;
        end
        BLT: begin //branch on less than
            taken_o = less;
        end
        BGE: begin //branch on greater than or equal
            taken_o = ~less;
        end
        BLTU: begin //branch if less than unsigned
            taken_o = less_u;
        end
        BGEU: begin //branch if greater than or equal unsigned
            taken_o = ~less_u;
        end
        default: begin
            taken_o = 0;
        end
    endcase
end

assign result_o = taken_o ? target_o : pc_i + 4;
assign reg_data_o = pc_i + 4;

endmodule
//`default_nettype wire

