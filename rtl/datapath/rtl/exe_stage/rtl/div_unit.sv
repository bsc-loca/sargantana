/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : div_unit.v
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

module div_unit (
    input  logic          clk_i,
    input  logic          rstn_i,
    input  logic          kill_div_i,
    input  logic          request_i,
    input  logic          int_32_i,
    input  logic          signed_op_i,
    input  bus64_t        dvnd_i,         // rs1
    input  bus64_t        dvsr_i,         // rs2

    output bus64_t        quo_o,
    output bus64_t        rmd_o,
    output logic          stall_o,        // operation in flight
    output logic          done_tick_o     // operation finished
);

    // Declarations
    logic [2:0] state_q;
    logic [2:0] state_d;
    bus64_t rh_q;
    bus64_t rh_d;
    bus64_t rl_q;
    bus64_t rl_d;
    bus64_t rh_tmp;
    bus64_t divisor_q;
    bus64_t divisor_d;
    logic [64:0] n_q;
    logic [64:0] n_d;
    logic q_bit;
    logic div_zero;
    logic same_sign;
    bus64_t dvnd_def;
    bus64_t dvsr_def;
    bus64_t quo_aux;
    bus64_t rmd_aux;

    parameter IDLE = 3'b000,
              OP   = 3'b001,
              LAST = 3'b010,
              DONE = 3'b011;

    assign div_zero = ~(|dvsr_i);
    assign same_sign = int_32_i ? ~(dvsr_i[31] ^ dvnd_i[31]) : ~(dvsr_i[63] ^ dvnd_i[63]);

    assign dvnd_def = ((dvnd_i[63] & signed_op_i & !int_32_i) |
                (dvnd_i[31] & signed_op_i & int_32_i)) ? ~dvnd_i + 64'b1 : dvnd_i;
    assign dvsr_def = ((dvsr_i[63] & signed_op_i & !int_32_i) |
                (dvsr_i[31] & signed_op_i & int_32_i)) ? ~dvsr_i + 64'b1 : dvsr_i;

    // FSMD state & DATA registers
    always @(posedge clk_i, negedge rstn_i)
        if (~rstn_i) begin
            state_q     <= IDLE;
            rh_q        <= 0;
            rl_q        <= 0;
            divisor_q   <= 0;
            n_q         <= 0;
        end else begin
            state_q     <= state_d;
            rh_q        <= rh_d;
            rl_q        <= rl_d;
            divisor_q   <= divisor_d;
            n_q         <= n_d;
        end

    // FSMD next-state logic
    always @(*) begin
        state_d     = state_q;
        stall_o     = 1'b0;
        done_tick_o = 1'b0;
        rh_d        = rh_q;
        rl_d        = rl_q;
        divisor_d   = divisor_q;
        n_d         = n_q;
        case (state_q)
            IDLE: begin            // dvsr = 64'h00000000FFFFF948; dvnd  = 64'hFFFFFF9A00000000;
                if (request_i & ~kill_div_i) begin
                    stall_o     = 1'b1;
                    rh_d        = 0;
                    rl_d        = int_32_i ? {dvnd_def[31:0],32'b0} : dvnd_def; // dividend with sign
                    divisor_d   = int_32_i ? {32'b0, dvsr_def[31:0]} : dvsr_def;// divisor with sign
                    n_d         = int_32_i ? 33 : 65;
                    state_d     = OP;
                end
            end
            OP: begin
                if (kill_div_i) begin
                    state_d = IDLE;
                    stall_o = 1'b0;
                end else begin
                    stall_o = 1'b1;
                    rl_d = {rl_q[62:0], q_bit};
                    rh_d = {rh_tmp[62:0], rl_q[63]};  // shit rh and rl left
                    n_d  = n_q - 1;                   // decrease index
                    if (n_d == 1)
                        state_d = LAST;
                end
            end
            LAST: begin
                if (kill_div_i) begin
                    state_d = IDLE;
                    stall_o = 1'b0;
                end else begin
                    stall_o = 1'b1;
                    rl_d = {rl_q[62:0], q_bit};
                    rh_d = rh_tmp;
                    state_d = DONE;
                end
            end
            DONE: begin
                if (kill_div_i) begin
                    state_d = IDLE;
                    stall_o = 1'b0;
                end else begin
                    stall_o     = 1'b0;
                    done_tick_o = 1'b1;
                    state_d     = IDLE;
                    stall_o     = 1'b0;
                end
            end
            default: state_d = IDLE;
        endcase // state_q
    end

    // compare and substract circuit
    always @(*)
        if (rh_q >= divisor_q) begin
            rh_tmp = rh_q - divisor_q;
            q_bit = 1'b1;
        end else begin
            rh_tmp = rh_q;
            q_bit = 1'b0;
        end

    // output
    assign quo_aux = done_tick_o ? (div_zero ? 64'hFFFFFFFFFFFFFFFF :
                (signed_op_i ? (same_sign ? rl_q : ~rl_q + 64'b1) : rl_q)) : 64'b0;
    assign quo_o = int_32_i ? {{32{quo_aux[31]}},quo_aux[31:0]} : quo_aux;
    assign rmd_aux = done_tick_o ? (div_zero ? dvnd_i : (signed_op_i ?
                (((dvnd_i[63] &  !int_32_i) | (dvnd_i[31] & int_32_i)) ?
                ~rh_q + 64'b1 : rh_q) : rh_q)) : 64'b0;
    assign rmd_o = int_32_i ? {{32{rmd_aux[31]}},rmd_aux[31:0]} : rmd_aux;

endmodule // divider
//`default_nettype wire

