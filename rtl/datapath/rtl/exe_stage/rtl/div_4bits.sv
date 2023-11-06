/*
 * Copyright 2023 BSC*
 * *Barcelona Supercomputing Center (BSC)
 * 
 * SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 * 
 * Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 * may not use this file except in compliance with the License, or, at your
 * option, the Apache License version 2.0. You may obtain a copy of the
 * License at
 * 
 * https://solderpad.org/licenses/SHL-2.1/
 * 
 * Unless required by applicable law or agreed to in writing, any work
 * distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */

module div_4bits 
    import drac_pkg::*;
(
    input  bus64_t        remanent_i,           // Contains the remanent of the previous division    
    input  bus64_t        dividend_quotient_i,  // Contains at same time the dividend and the quotient of previous division
    input  bus64_t        divisor_i,            // Contains the divisor

    output bus64_t        remanent_o,           // Contains the remanent of the actual 8 bit division
    output bus64_t        dividend_quotient_o,  // Contains at same time dividend and quotient of actual 8 bit division
    output bus64_t        divisor_o
);

    // Declarations
    /* verilator lint_off UNOPTFLAT */
    bus64_t tmp_remanent[1:0];
    /* verilator lint_on UNOPTFLAT */
    bus64_t tmp_remanent_sub[1:0];
    bus64_t tmp_dividend_quotient[1:0];
    logic   quotient_bit[1:0];

    always_comb begin
        tmp_remanent[1] = {remanent_i[62:0], dividend_quotient_i[63]};
        tmp_dividend_quotient[1] = {dividend_quotient_i[62:0], quotient_bit[1]};
        for(int i = 0; i >= 0; i--) begin
            tmp_remanent[i] = {tmp_remanent_sub[i+1][62:0],tmp_dividend_quotient[i+1][63]};
            tmp_dividend_quotient[i] = {tmp_dividend_quotient[i+1][62:0], quotient_bit[i]};
        end
    end

    always_comb begin
        for(int i = 1; i >= 0; i--) begin
            if (tmp_remanent[i] >= divisor_i) begin
                tmp_remanent_sub[i] = tmp_remanent[i] - divisor_i;
                quotient_bit[i] = 1'b1;
            end else begin
                tmp_remanent_sub[i] = tmp_remanent[i];
                quotient_bit[i] = 1'b0;
            end
        end
    end
    
    assign remanent_o = tmp_remanent_sub[0];
    assign dividend_quotient_o = tmp_dividend_quotient[0];
    assign divisor_o = divisor_i;

endmodule // divider 8 bits


