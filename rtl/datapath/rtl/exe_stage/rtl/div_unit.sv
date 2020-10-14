/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : div_unit.v
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Victor Soria Pardos 
 * Email(s)       : victor.soria@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author   | Description
 * -----------------------------------------------
 */

import drac_pkg::*;

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
    output logic          stall_o        // operation in flight
);

    // Declarations
    logic done_tick;

    logic [2:0] state_q, state_d;
    logic [5:0] n_q, n_d;
    logic div_zero;
    logic same_sign;
    logic int_32_q, int_32_d;
    bus64_t dvnd_def;
    bus64_t dvsr_def;
    bus64_t quo_aux;
    bus64_t rmd_aux;

    bus64_t remanent_out;
    bus64_t dividend_quotient_out;
    bus64_t divisor_out;
    bus64_t remanent_q, remanent_d;
    bus64_t dividend_quotient_q, dividend_quotient_d;
    bus64_t divisor_q, divisor_d;

    div_4bits div_4bits_ints(
        .remanent_i(remanent_q),
        .dividend_quotient_i(dividend_quotient_q),
        .divisor_i(divisor_q),

        .remanent_o(remanent_out),
        .dividend_quotient_o(dividend_quotient_out),
        .divisor_o(divisor_out)
    );

    parameter IDLE  = 3'b000,
              OP    = 3'b001,
              FIRST = 3'b010,
              DONE  = 3'b011;

    assign div_zero = (~(|dvsr_i)) || (int_32_i && ~(|dvsr_i[31:0]));
    assign same_sign = int_32_i ? ~(dvsr_i[31] ^ dvnd_i[31]) : ~(dvsr_i[63] ^ dvnd_i[63]);

    assign dvnd_def = ((dvnd_i[63] & signed_op_i & !int_32_i) |
                (dvnd_i[31] & signed_op_i & int_32_i)) ? ~dvnd_i + 64'b1 : dvnd_i;
    assign dvsr_def = ((dvsr_i[63] & signed_op_i & !int_32_i) |
                (dvsr_i[31] & signed_op_i & int_32_i)) ? ~dvsr_i + 64'b1 : dvsr_i;

    

    // FSMD next-state logic
    always_comb begin
        remanent_d              = 0;
        dividend_quotient_d     = 0;
        state_d                 = state_q;
        stall_o                 = 1'b0;
        done_tick               = 1'b0;
        divisor_d               = divisor_q;
        n_d                     = n_q;
        int_32_d                = int_32_q;
        case (state_q)
            IDLE: begin            // dvsr = 64'h00000000FFFFF948; dvnd  = 64'hFFFFFF9A00000000;
                if (request_i & ~kill_div_i) begin
                    stall_o             = 1'b1;
                    remanent_d          = 0;
                    dividend_quotient_d = int_32_i ? {dvnd_def[31:0],32'b0} : dvnd_def; // dividend with sign
                    divisor_d           = int_32_i ? {32'b0, dvsr_def[31:0]} : dvsr_def;// divisor with sign
                    int_32_d            = int_32_i;
                    n_d                 = int_32_i ? 15 : 31;//7 : 15;
                    state_d             = OP;
                end else begin
                    state_d     = IDLE;
                    stall_o     = 1'b0;
                end             
            end
            OP: begin
                if (kill_div_i) begin
                    state_d = IDLE;
                    stall_o = 1'b0;
                end else begin
                    stall_o = 1'b1;
                    remanent_d = remanent_out;
                    dividend_quotient_d = dividend_quotient_out;
                    divisor_d = divisor_out;
	                if (n_q == 0) begin
                       state_d = DONE;
		            end else n_d = n_q - 1;
                end
            end
            DONE: begin
                if (kill_div_i) begin
                    state_d = IDLE;
                    stall_o = 1'b0;
                end else begin
                    stall_o     = 1'b0;
                    done_tick = 1'b1;
                    state_d     = IDLE;
                end
            end
            default: state_d = IDLE;
        endcase // state_q
    end

    // output
    assign quo_aux = done_tick ? (div_zero ? 64'hFFFFFFFFFFFFFFFF :
                (signed_op_i ? (same_sign ? dividend_quotient_q : ~dividend_quotient_q + 64'b1) : dividend_quotient_q)) : 64'b0;
    assign quo_o = int_32_i ? {{32{quo_aux[31]}},quo_aux[31:0]} : quo_aux;
    assign rmd_aux = done_tick ? (div_zero ? dvnd_i : (signed_op_i ?
                (((dvnd_i[63] &  !int_32_i) | (dvnd_i[31] & int_32_i)) ?
                ~remanent_q + 64'b1 : remanent_q) : remanent_q)) : 64'b0;
    assign rmd_o = int_32_i ? {{32{rmd_aux[31]}},rmd_aux[31:0]} : rmd_aux;


    // FSMD state & DATA registers
    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            state_q             <= IDLE;
            remanent_q          <= 0;
            dividend_quotient_q <= 0;
            divisor_q           <= 0;
            n_q                 <= 0;
            int_32_q            <= 0;
        end else begin
            state_q             <= state_d;
            remanent_q          <= remanent_d;
            dividend_quotient_q <= dividend_quotient_d;
            divisor_q           <= divisor_d;
            n_q                 <= n_d;
            int_32_q            <= int_32_d;
        end
    end

endmodule // divider
//`default_nettype wire

