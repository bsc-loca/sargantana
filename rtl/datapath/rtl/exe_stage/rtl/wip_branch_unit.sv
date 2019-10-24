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
`include "drac_pkg.sv"
import drac_pkg::*;


module branch_unit(
    input ctrl_xfer_op_t  ctrl_xfer_op_i,
    input branch_op_t     branch_op_i,

    input addr_t      pc_i,
    input bus64_t     data_rs1_i,
    input bus64_t     data_rs2_i,
    input bus64_t     imm_i,

    output logic      taken_o,
    output addr_t     target_o,
    output addr_t     result_o,

    output bus64_t    reg_data_o
);

logic equal;
logic less;
logic less_u;

// Calculate all posible conditions
assign equal = data_rs1_i == data_rs2_i;
assign less = $signed(data_rs1_i) < $signed(data_rs2_i);
assign less_u = data_rs1_i < data_rs2_i;

// Calculate if the branch is taken
always_comb begin
    case (ctrl_xfer_op_i)
        CT_JAL: begin
            taken_o  = 1;
            target_o = pc_i + imm_i;
        end
        CT_JALR: begin
            taken_o  = 1;
            target_o = pc_i + data_rs1_i + imm_i;
        end
        CT_BRANCH: begin
            target_o = pc_i + imm_i;
            case (branch_op_i)
                B_EQ: begin   //branch on equal
                    taken_o = equal;
                end
                B_NE: begin //branch on not equal
                    taken_o = ~equal;
                end
                B_LT: begin //branch on less than
                    taken_o = less;
                end
                B_GE: begin //branch on greater than or equal
                    taken_o = ~less;
                end
                B_LTU: begin //branch if less than unsigned
                    taken_o = less_u;
                end
                B_GEU: begin //branch if greater than or equal unsigned
                    taken_o = ~less_u;
                end
                default: begin
                    taken_o = 0;
                end
            endcase
        end
        default: begin
            taken_o  = 0;
            target_o = 0;
        end
    endcase
end

assign result_o   = taken_o ? target_o : pc_i + 4;
assign reg_data_o = pc_i + 4;

endmodule
//`default_nettype wire

