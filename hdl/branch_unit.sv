
`default_nettype none
`include "definitions.v"

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

module branch_unit(
    input ctrl_xfer_op_t  ctrl_xfer_op_i,
    input branch_op_t     branch_op_i,

    input wire `ADDR  pc_i,
    input bus64_t     data_op1_i,
    input bus64_t     data_op2_i,
    input bus64_t     imm_i,

    output wire       taken_o,
    output reg `ADDR  target_o,
    output reg `ADDR  result_o,

    output bus64_t    reg_data_o
);

logic equal;
logic less;
logic less_u;

// Calculate all posible conditions
assign equal = data_op1_i == data_op2_i;
assign less = $signed(data_op1_i) < $signed(data_op2_i);
assign less_u = data_op1_i < data_op2_i;

// Calculate if the branch is taken
always_comb begin
    case (ctrl_xfer_op_i)
        B_JAL: begin
            taken_o  = 1;
            target_o = pc_i + imm_i;
        end
        B_JALR: begin
            taken_o  = 1;
            target_o = pc_i + data_op1_i + imm_i;
        end
        B_BRANCH: begin
            target_o = pc_i + imm_i;
            case (branch_op_i)
                CT_EQ: begin   //branch on equal
                    taken_o = equal;
                end
                CT_NE: begin //branch on not equal
                    taken_o = ~equal;
                end
                CT_LT: begin //branch on less than
                    taken_o = less;
                end
                CT_GE: begin //branch on greater than or equal
                    taken_o = ~less;
                end
                CT_LTU: begin //branch if less than unsigned
                    taken_o = less_u;
                end
                CT_GEU: begin //branch if greater than or equal unsigned
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
`default_nettype wire

