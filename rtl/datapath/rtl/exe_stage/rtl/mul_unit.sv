/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : mul_unit.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Rubén Langarita
 * Email(s)       : ruben.langarita@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author   | Description
 * -----------------------------------------------
 */
import drac_pkg::*;
//`default_nettype none

module mul_unit (
    input  logic         clk_i,
    input  logic         rstn_i,
    input  logic         kill_mul_i,
    input  logic         request_i,
    input  logic [2:0]   func3_i,
    input  logic         int_32_i,
    input  bus64_t       src1_i,         // rs1
    input  bus64_t       src2_i,         // rs2
    output bus64_t       result_o,
    output logic         stall_o,        // operation in flight
    output logic         done_tick_o     // operation finished
);

// Declarations
logic same_sign;
bus64_t src1_def;
bus64_t src2_def;
logic neg_def;
logic state_q;
logic [95:0] result1_d;
logic [95:0] result2_d;
logic [95:0] result1_q;
logic [95:0] result2_q;
bus128_t result_128;
bus128_t result_128_def;
bus64_t result_32_aux;
bus64_t result_32;
bus64_t result_64;

parameter IDLE = 1'b0,
          DONE = 1'b1;

assign same_sign = int_32_i ? ~(src2_i[31] ^ src1_i[31]) : ~(src2_i[63] ^ src1_i[63]);

// Source Operands, convert if source is negative and operation is signed
always@(*) begin
    case ({func3_i})
        3'b000: begin  // Multiply word, Low part, Signed - MUL , MULW
            src1_def = ((src1_i[63] & !int_32_i) | (src1_i[31]  & int_32_i)) ?
                        ~src1_i + 64'b1 : src1_i;
            src2_def = ((src2_i[63] & !int_32_i) | (src2_i[31]  & int_32_i)) ?
                        ~src2_i + 64'b1 : src2_i;
            neg_def  = !same_sign;
        end
        3'b001: begin  // Multiply word, High part, Signed - MULH
            src1_def = (src1_i[63]) ? ~src1_i + 64'b1 : src1_i;
            src2_def = (src2_i[63]) ? ~src2_i + 64'b1 : src2_i;
            neg_def  = !same_sign;
        end
        3'b010: begin  // Multiply word, High part, SignedxUnsigned - MULHSU
            src1_def = (src1_i[63]) ? ~src1_i + 64'b1 : src1_i;
            src2_def = src2_i;
            neg_def  = src1_i[63];
        end
        3'b011: begin  //  Multiply word, High part, Unsigned Unsigned MULHU
            src1_def = src1_i;
            src2_def = src2_i;
            neg_def  = 1'b0;
        end
        default: begin
            src1_def = 64'b0;
            src2_def = 64'b0;
            neg_def  = 1'b0;
        end
    endcase
end

assign result1_d = src1_def * src2_def[31:0];
assign result2_d = src1_def * src2_def[63:32];

// 32-bit multiplication MULW, operation finished
assign result_32_aux = neg_def ? ~result1_d[63:0] + 64'b1 : result1_d[63:0];
assign result_32 = {{32{result_32_aux[31]}},result_32_aux[31:0]};

// FSMD state & DATA registers
always @(posedge clk_i, negedge rstn_i)
    if (~rstn_i) begin
        state_q    <= IDLE;
        result1_q  <= 0;
        result2_q  <= 0;
    end else begin
        state_q    <= stall_o;
        result1_q  <= result1_d;
        result2_q  <= result2_d;
    end

// FSMD next-state logic
always @(*) begin
    case (state_q)
        IDLE: begin
            if (request_i & ~kill_mul_i) begin
                stall_o      = int_32_i ? 1'b0 : 1'b1;
                done_tick_o  = int_32_i ? 1'b1 : 1'b0;
            end else begin
                stall_o      = 1'b0;
                done_tick_o  = 1'b0;
            end
        end
        DONE: begin
            if (kill_mul_i) begin
                stall_o      = 1'b0;
                done_tick_o  = 1'b0;
            end else begin
                stall_o      = 1'b0;
                done_tick_o  = 1'b1;
            end
        end
    endcase // state_q
end

// 64-bit multiplication MUL
assign result_128 = {32'b0,result1_q} + {result2_q[95:0],32'b0};
// Convert if the result is negative
always@(*) begin
    result_128_def = neg_def ? ~result_128 + 128'b1 : result_128;
end

// Select correct word
always@(*) begin
    case ({func3_i})
        3'b000: begin  // Multiply word, Low part, Signed - MUL , MULW
            result_64 = result_128_def[63:0];
        end
        3'b001: begin  // Multiply word, High part, Signed - MULH
            result_64 = result_128_def[127:64];
        end
        3'b010: begin  // Multiply word, High part, SignedxUnsigned - MULHSU
            result_64 =  result_128_def[127:64];
        end
        3'b011: begin  //  Multiply word, High part, Unsigned Unsigned MULHU
            result_64 = result_128_def[127:64];
        end
        default: begin
            result_64 = 64'b0;
        end
    endcase
end 

// output
always@(*) begin
    result_o = done_tick_o ? (int_32_i ? result_32 : result_64) : 64'b0;
end

endmodule
//`default_nettype wire

