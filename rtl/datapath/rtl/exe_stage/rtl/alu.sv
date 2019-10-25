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
        ADD,ADDW: begin
            result_o = data_rs1_i + data_rs2_i;
        end
        SUB.SUBW: begin
            result_o = data_rs1_i - data_rs2_i;
        end
        SLL: begin
            result_o = data_rs1_i << data_rs2_i;
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
            result_o = data_rs1_i >> data_rs2_i;
        end
        SRA: begin
            result_o = data_rs1_i >>> data_rs2_i;
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

