//`default_nettype none
import drac_pkg::*;

module alu (
    input bus64_t  data_rs1_i,
    input bus64_t  data_rs2_i,
    input instr_type_t instr_type_i,

    output bus64_t result_o
);

/*
assign mul = $signed(data_rs1_i) * $signed(data_rs2_i);
assign mul_u = data_rs1_i * data_rs2_i;
assign mul_su = $signed(data_rs1_i) * data_rs2_i;
*/
always_comb begin
    case (instr_type_i)
        ADD: begin
            result_o = data_rs1_i + data_rs2_i;
        end
        ADDW: begin
            result_o[31:0] = data_rs1_i[31:0] + data_rs2_i[31:0];
            result_o[63:32] = {32{result_o[31]}};
        end
        SUB: begin
            result_o = data_rs1_i - data_rs2_i;
        end
        SUBW: begin
            result_o[31:0] = data_rs1_i[31:0] - data_rs2_i[31:0];
            result_o[63:32] = {32{result_o[31]}};
        end
        SLL: begin
            result_o = data_rs1_i << data_rs2_i[5:0];
        end
        SLLW: begin
            result_o[31:0] = data_rs1_i[31:0] << data_rs2_i[4:0];
            result_o[63:32] = {32{result_o[31]}};
        end
        SLT: begin
            result_o = {63'b0, $signed(data_rs1_i) < $signed(data_rs2_i)};
        end
        SLTU: begin
            result_o = {63'b0, data_rs1_i < data_rs2_i};
        end
        XOR: begin
            result_o = data_rs1_i ^ data_rs2_i;
        end
        SRL: begin
            result_o = data_rs1_i >> data_rs2_i[5:0];
        end
        SRLW: begin
            result_o[31:0] = data_rs1_i[31:0] >> data_rs2_i[4:0];
            result_o[63:32] = {32{result_o[31]}};
        end
        SRA: begin
            result_o = $signed(data_rs1_i) >>> data_rs2_i[5:0];
        end
        SRAW: begin
            result_o[31:0] = $signed(data_rs1_i[31:0]) >>> data_rs2_i[4:0];
            result_o[63:32] = {32{result_o[31]}};
        end
        OR: begin
            result_o = data_rs1_i | data_rs2_i;
        end
        AND: begin
            result_o = data_rs1_i & data_rs2_i;
        end
        default: begin
            result_o = 0;
        end
    endcase
end

endmodule
//`default_nettype wire

