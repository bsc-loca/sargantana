//`default_nettype none
import drac_pkg::*;

module integer_unit (
    input bus64_t  data_rs1_i,
    input bus64_t  data_rs2_i,
    input alu_op_t alu_op_i,

    output bus64_t result_o,
    output logic   stall_o
);

logic [127:0] mul;
logic [127:0] mul_u;
logic [127:0] mul_su;

assign mul = $signed(data_rs1_i) * $signed(data_rs2_i);
assign mul_u = data_rs1_i * data_rs2_i;
assign mul_su = $signed(data_rs1_i) * data_rs2_i;

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
        // M Extension
        ALU_MUL: begin
            result_o = mul[63:0];
        end
        ALU_MULH: begin
            result_o = mul[127:64];
        end
        ALU_MULHSU: begin
            result_o = mul_su[127:64];
        end
        ALU_MULHS: begin
            result_o = mul_u[127:64];
        end
        ALU_DIV: begin
            result_o = $signed(data_rs1_i) / $signed(data_rs2_i);
        end
        ALU_DIVU: begin
            result_o = data_rs1_i / data_rs2_i;
        end
        ALU_REM: begin
            result_o = $signed(data_rs1_i) % $signed(data_rs2_i);
        end
        ALU_REMU: begin
            result_o = data_rs1_i % data_rs2_i;
        end
        default: begin
            result_o = 0;
        end
    endcase
end

assign stall_o = '0;

endmodule
//`default_nettype wire

