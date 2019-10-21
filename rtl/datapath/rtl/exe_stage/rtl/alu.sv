//`default_nettype none
import drac_pkg::*;

module alu (
    input bus64_t  data_rs1_i,
    input bus64_t  data_rs2_i,
    input alu_op_t alu_op_i,

    output bus64_t result_o
);

/*
assign mul = $signed(data_rs1_i) * $signed(data_rs2_i);
assign mul_u = data_rs1_i * data_rs2_i;
assign mul_su = $signed(data_rs1_i) * data_rs2_i;
*/
always_comb begin
    case (alu_op_i)
        ALU_ADD: begin
            result_o = data_rs1_i + data_rs2_i;
        end
        ALU_SUB: begin
            result_o = data_rs1_i - data_rs2_i;
        end
        ALU_SLL: begin
            result_o = data_rs1_i << data_rs2_i;
        end
        ALU_SLT: begin
            result_o = {63'b0, $signed(data_rs1_i) < $signed(data_rs2_i)};
        end
        ALU_SLTU: begin
            result_o = {63'b0, data_rs1_i < data_rs2_i};
        end
        ALU_XOR: begin
            result_o = data_rs1_i ^ data_rs2_i;
        end
        ALU_SRL: begin
            result_o = data_rs1_i >> data_rs2_i;
        end
        ALU_SRA: begin
            result_o = data_rs1_i >>> data_rs2_i;
        end
        ALU_OR: begin
            result_o = data_rs1_i | data_rs2_i;
        end
        ALU_AND: begin
            result_o = data_rs1_i & data_rs2_i;
        end
        default: begin
            result_o = 0;
        end
    endcase
end

endmodule
//`default_nettype wire

