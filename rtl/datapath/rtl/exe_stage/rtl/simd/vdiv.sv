/* -----------------------------------------------
 * Project Name   : DRAC 
 * File           : vdiv.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Alireza Foroodnia 
 * Email(s)       : alireza.foroodnia@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 * -----------------------------------------------
 */

// This module is responsible to execute DIV/REM operations, to this end it fetches data from outside
// in the first clock the data is reformed and signs and magnitudes are calculated.
// After turning raw data into process ready data, a 32 clock cycles computation starts.
// once this is done we need 1 clock cycle to compute the final data which will have the final sign
// or exceptional data in case of div by zero.
// Overall the whole process takes 34 cycles to complete


import drac_pkg::*;
import riscv_pkg::*;
 
module vdiv 
(
  input wire                  clk_i,          // Clock
  input wire                  rstn_i,         // Reset 
  input instr_type_t          instr_type_i,   // Instruction type
  input logic                 instr_valid_i,  // Valid signal of the incoming Inst
  input sew_t                 sew_i,          // Element width
  input bus64_t               data_vs1_i,     // 64-bit source operand 1
  input bus64_t               data_vs2_i,     // 64-bit source operand 2
  input logic [5:0]           exe_stages,     // execution stages of this DIV/REM
  output bus64_t              data_vd_o       // 64-bit result
);


// These functions are used to indicate the type of incoming or
// current instruction
function logic is_signed_inst(input instr_type_t instr);
    is_signed_inst = ((instr == VDIV)   ||
               (instr == VREM)) ? 1'b1 : 1'b0;
endfunction

function logic is_division(input instr_type_t instr);
    is_division = ((instr == VDIV)   ||
               (instr == VDIVU)) ? 1'b1 : 1'b0;
endfunction

function logic is_remainder(input instr_type_t instr);
    is_remainder = ((instr == VREM)   ||
               (instr == VREMU)) ? 1'b1 : 1'b0;
endfunction


// functions below are used to truncate data, the main use 
// is to match certain data widths while indexing or performing 
// index addition and subtractions
function [63:0] trunc_64_sum(input [64:0] val_in);
    trunc_64_sum = val_in[63:0];
endfunction

function [31:0] trunc_32_sum(input [32:0] val_in);
    trunc_32_sum = val_in[31:0];
endfunction

function [15:0] trunc_16_sum(input [16:0] val_in);
    trunc_16_sum = val_in[15:0];
endfunction

function [7:0] trunc_8_sum(input [8:0] val_in);
    trunc_8_sum = val_in[7:0];
endfunction



// variables below save the magnitudes, signs and division by zero
// this happen within the clock that the data arrives to the 
// vdiv module
bus64_t magnitudes_vs1_d;
bus64_t magnitudes_vs1_q;
bus64_t magnitudes_vs2_d;
bus64_t magnitudes_vs2_q;

logic [7:0] division_by_zero_d;
logic [7:0] division_by_zero_q;

// the result is negative if sign is 1 and positive if sign is 0
logic [7:0] result_signs_d;
logic [7:0] result_signs_q;

// The initial dividened elements
bus64_t dividened_elements_d;
bus64_t dividened_elements_q;

// these variables are used to hold the data which 
// is fed to the div_2bits modules
bus64_t remnant_q;
bus64_t dividend_quotient_q;
bus64_t divisor_q;

// these variables hold the very first input to the
// arithmetic module, used to begin arithmetics in the very first clock
bus64_t first_remnant;
bus64_t first_dividend_quotient;
bus64_t first_divisor;

// these variables feed data directly to the arithmetic module
bus64_t remnant_i;
bus64_t dividend_quotient_i;
bus64_t divisor_i;



// these variables are holding the partial or final
// outputs of div_2bits module
bus64_t remnant_out;
bus64_t dividend_quotient_out;
bus64_t divisor_out;


// these are the pre-final results of divisions
// the division by 0 and sign of the result is yet to applied to them.
bus64_t remnants;
bus64_t quotients;



// these are the final results of divisions
bus64_t remnants_out;
bus64_t quotients_out;


// as the name indicates these store the remaining cycles 
// and the remaining number of divisions.
logic [5:0] cycles_counter;
logic [3:0] number_of_divisions;

// the type and SEW of the instruction that is happening inside the module
instr_type_t          instr_type_d;
instr_type_t          instr_type_q;

// The SEW of the in-flight instruction
sew_t                 sew_d;
sew_t                 sew_q;

// The SEW that is fed to vdiv_2bits
sew_t                 sew_input;



assign remnant_i = ((is_division(instr_type_i) || is_remainder(instr_type_i)) && instr_valid_i) ? 
first_remnant : remnant_q;

assign dividend_quotient_i = ((is_division(instr_type_i) || is_remainder(instr_type_i)) && instr_valid_i) ? 
first_dividend_quotient : dividend_quotient_q;

assign divisor_i = ((is_division(instr_type_i) || is_remainder(instr_type_i)) && instr_valid_i) ?
first_divisor : divisor_q;

assign sew_input = ((is_division(instr_type_i) || is_remainder(instr_type_i)) && instr_valid_i) ?
sew_i : sew_q;



//--------------------------------------------------------------------------------------------------
//----- FIRST CLOCK OF NEW INSTRUCTION  ------------------------------------------------------------
//--------------------------------------------------------------------------------------------------

always_comb begin
    // if a new instruction is issued to the vdiv unit the data, division by zero and
    // signs are formed here, the instr_valid_i is important as it indicates wether the 
    // simd unit is stalled for any reason or not, and while stalled the new instruction must
    // not enter the execution pipeline.
    
    first_remnant = '0;
    first_dividend_quotient = '0;
    first_divisor = '0;
    
    if((is_division(instr_type_i) || is_remainder(instr_type_i)) && instr_valid_i) begin

        result_signs_d       = '0;
        division_by_zero_d   = '0;

        sew_d = sew_i;
        instr_type_d = instr_type_i;
        dividened_elements_d = data_vs2_i;

        // The magnitude of data is being extracted and final sign and division by 0 is infered here
        // from the incoming data.
        case (sew_i)
            SEW_8: begin
                for (int i = 0 ; i < (DATA_SIZE/8) ; ++i ) begin

                    result_signs_d[i] = (is_signed_inst(instr_type_i)) ? (data_vs1_i[((i * 8) + 7)] ^ data_vs2_i[((i * 8) + 7)]) : 1'b0;
                    division_by_zero_d[i] = (data_vs1_i[(i * 8) +: 8] == '0) ? 1'b1 : 1'b0;

                    magnitudes_vs1_d[(i * 8) +: 8] = (is_signed_inst(instr_type_i) && data_vs1_i[((i * 8) + 7)]) ? 
                    trunc_8_sum(~data_vs1_i[(i * 8) +: 8] + 8'b1): data_vs1_i[(i * 8) +: 8];

                    magnitudes_vs2_d[(i * 8) +: 8] = (is_signed_inst(instr_type_i) && data_vs2_i[((i * 8) + 7)]) ? 
                    trunc_8_sum(~data_vs2_i[(i * 8) +: 8] + 8'b1): data_vs2_i[(i * 8) +: 8];

                    // for the very first clock cycle, the input data is formed here.
                    first_dividend_quotient = {56'b0, magnitudes_vs2_d[63:56]};
                    first_divisor = {56'b0, magnitudes_vs1_d[63:56]};
                end
            end
            SEW_16: begin
                for (int i = 0 ; i < (DATA_SIZE/16) ; ++i ) begin

                    result_signs_d[i] = (is_signed_inst(instr_type_i)) ? (data_vs1_i[((i * 16) + 15) +: 1] ^ data_vs2_i[((i * 16) + 15) +: 1]) : 1'b0;
                    division_by_zero_d[i] = (data_vs1_i[(i * 16) +: 16] == '0) ? 1'b1 : 1'b0;
                    
                    magnitudes_vs1_d[(i * 16) +: 16] = (is_signed_inst(instr_type_i) && data_vs1_i[((i * 16) + 15)]) ? 
                    trunc_16_sum(~data_vs1_i[(i * 16) +: 16] + 16'b1): data_vs1_i[(i * 16) +: 16];

                    magnitudes_vs2_d[(i * 16) +: 16] = (is_signed_inst(instr_type_i) && data_vs2_i[((i * 16) + 15)]) ? 
                    trunc_16_sum(~data_vs2_i[(i * 16) +: 16] + 16'b1): data_vs2_i[(i * 16) +: 16];

                    first_dividend_quotient = {48'b0, magnitudes_vs2_d[63:48]};
                    first_divisor = {48'b0, magnitudes_vs1_d[63:48]};                    
                    
                end
                
            end
            SEW_32: begin
                for (int i = 0 ; i < (DATA_SIZE/32) ; ++i ) begin

                    result_signs_d[i] = (is_signed_inst(instr_type_i)) ? (data_vs1_i[((i * 32) + 31) +: 1] ^ data_vs2_i[((i * 32) + 31) +: 1]) : 1'b0;
                    division_by_zero_d[i] = (data_vs1_i[(i * 32) +: 32] == '0) ? 1'b1 : 1'b0;

                    magnitudes_vs1_d[(i * 32) +: 32] = (is_signed_inst(instr_type_i) && data_vs1_i[((i * 32) + 31)]) ? 
                    trunc_32_sum(~data_vs1_i[(i * 32) +: 32] + 32'b1): data_vs1_i[(i * 32) +: 32];
                    
                    magnitudes_vs2_d[(i * 32) +: 32] = (is_signed_inst(instr_type_i) && data_vs2_i[((i * 32) + 31)]) ? 
                    trunc_32_sum(~data_vs2_i[(i * 32) +: 32] + 32'b1): data_vs2_i[(i * 32) +: 32];
                    
                    first_dividend_quotient = {32'b0, magnitudes_vs2_d[63:32]};
                    first_divisor = {32'b0, magnitudes_vs1_d[63:32]};
                end
                
            end
            SEW_64: begin
                for (int i = 0 ; i < (DATA_SIZE/64) ; ++i ) begin

                    result_signs_d[i] = (is_signed_inst(instr_type_i)) ? (data_vs1_i[((i * 64) + 63) +: 1] ^ data_vs2_i[((i * 64) + 63) +: 1]) : 1'b0;
                    division_by_zero_d[i] = (data_vs1_i[(i * 64) +: 64] == '0) ? 1'b1 : 1'b0;

                    magnitudes_vs1_d[(i * 64) +: 64] = (is_signed_inst(instr_type_i) && data_vs1_i[((i * 64) + 63)]) ? 
                    trunc_64_sum(~data_vs1_i[(i * 64) +: 64] + 64'b1): data_vs1_i[(i * 64) +: 64];
                    
                    magnitudes_vs2_d[(i * 64) +: 64] = (is_signed_inst(instr_type_i) && data_vs2_i[((i * 64) + 63)]) ? 
                    trunc_64_sum(~data_vs2_i[(i * 64) +: 64] + 64'b1): data_vs2_i[(i * 64) +: 64];

                    first_dividend_quotient = magnitudes_vs2_d;
                    first_divisor = magnitudes_vs1_d;
                end
            end

            default: begin
                for (int i = 0 ; i < (DATA_SIZE/64) ; ++i ) begin

                    result_signs_d[i] = (is_signed_inst(instr_type_i)) ? (data_vs1_i[((i * 64) + 63) +: 1] ^ data_vs2_i[((i * 64) + 63) +: 1]) : 1'b0;
                    division_by_zero_d[i] = (data_vs1_i[(i * 64) +: 64] == '0) ? 1'b1 : 1'b0;

                    magnitudes_vs1_d[(i * 64) +: 64] = (is_signed_inst(instr_type_i) && data_vs1_i[((i * 64) + 63)]) ? 
                    trunc_64_sum(~data_vs1_i[(i * 64) +: 64] + 64'b1): data_vs1_i[(i * 64) +: 64];
                    
                    magnitudes_vs2_d[(i * 64) +: 64] = (is_signed_inst(instr_type_i) && data_vs2_i[((i * 64) + 63)]) ? 
                    trunc_64_sum(~data_vs2_i[(i * 64) +: 64] + 64'b1): data_vs2_i[(i * 64) +: 64];

                    first_dividend_quotient = magnitudes_vs2_d;
                    first_divisor = magnitudes_vs1_d;
                end
            end
        endcase
    end
    else begin
        // when no new instruction is being issued, we basically propagate the data of previous
        // instruction to the next one
        sew_d                   =           sew_q;
        instr_type_d            =           instr_type_q;
        dividened_elements_d    =           dividened_elements_q;
        magnitudes_vs1_d        =           magnitudes_vs1_q;
        magnitudes_vs2_d        =           magnitudes_vs2_q;
        division_by_zero_d      =           division_by_zero_q;
        result_signs_d          =           result_signs_q;
    end
end



//--------------------------------------------------------------------------------------------------
//----- PIPELINE -----------------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------

// this is not a linear pipeline, it has a circular form and the same hardware is used every cycle
// till the instruction finish execution.


// this module is responsible to perform 2 iterations of the division algorithm,
// the used algorithm is similar to pen and paper algorithm and takes N iterations 
// for data width of N bits.
div_2bits div_2bits_simd (
        .remanent_i(remnant_i),
        .dividend_quotient_i(dividend_quotient_i),
        .divisor_i(divisor_i),
        .remanent_o(remnant_out),
        .dividend_quotient_o(dividend_quotient_out),
        .divisor_o(divisor_out),
        .sew_i(sew_i)
    );


always_ff @(posedge clk_i, negedge rstn_i) begin
        if (~rstn_i) begin
            remnant_q                   <= '0;
            dividend_quotient_q         <= '0;
            divisor_q                   <= '0;

            magnitudes_vs1_q            <= '0;
            magnitudes_vs2_q            <= '0;
            result_signs_q              <= '0;
            division_by_zero_q          <= '0;
            dividened_elements_q        <= '0;

            cycles_counter              <= '0;
            number_of_divisions         <= '0;

            remnants                    <= '0;
            quotients                   <= '0;

            sew_q                       <= SEW_8;
            instr_type_q                <= ADD;
            
        end else begin

            // In any clock regardless of input or state, we have to propagate the 
            // data of new or already executing instruction.

            sew_q                   <=  sew_d;
            instr_type_q            <=  instr_type_d;
            dividened_elements_q    <=  dividened_elements_d;
            magnitudes_vs1_q        <=  magnitudes_vs1_d;
            magnitudes_vs2_q        <=  magnitudes_vs2_d;
            division_by_zero_q      <=  division_by_zero_d;
            result_signs_q          <=  result_signs_d;


            if((is_division(instr_type_i) || is_remainder(instr_type_i)) && instr_valid_i) begin
                
                // In the very first clock initial data was processed and stored in _d variables like magnitudes_vs1_d
                // In the second clock and in this case statment, that prcessed data is being sent to the inputs of
                // div_2bits modules
                // The number_of_divisions is set to save the number of remaining Divisions
                // The cycle_counter will also save the number of clock cycles it takes to finalize 
                // this specific element's division, so the smaller the SEW the less clocks it takes
                remnant_q            <= remnant_out;
                dividend_quotient_q  <= dividend_quotient_out;
                divisor_q            <= divisor_out;
                case (sew_d)

                    SEW_8: begin
                        number_of_divisions <= 4'b0111;
                        cycles_counter <= 6'b000010;
                    end

                    SEW_16: begin
                        number_of_divisions <= 4'b0011;
                        cycles_counter <= 6'b000110;
                    end

                    SEW_32: begin
                        number_of_divisions <= 4'b0001;
                        cycles_counter <= 6'b001110;
                    end

                    SEW_64: begin
                        number_of_divisions <= 4'b0000;
                        cycles_counter <= 6'b011110;
                    end

                endcase

            end
            else begin
                // If the in-flight DIV/REM still has clock remaining, let it happen
                if(cycles_counter != '0) begin
                    remnant_q            <= remnant_out;
                    dividend_quotient_q  <= dividend_quotient_out;
                    divisor_q            <= divisor_out;
                    cycles_counter       <= cycles_counter - 1'b1;
                end


                // if the previous devision is done and there is another one, save the previous one's
                // data and start the next one
                else if (number_of_divisions != '0) begin
                    
                    remnant_q              <= 'h0;
                    
                    case (sew_q)

                        SEW_8: begin
                            quotients[((number_of_divisions[2:0]) * 8) +: 8] <= dividend_quotient_out[0 +: 8];
                            remnants[((number_of_divisions[2:0]) * 8) +: 8] <= remnant_out[0 +: 8];
                            dividend_quotient_q <= {56'b0, magnitudes_vs2_q[((number_of_divisions[2:0] - 1'b1) * 8) +: 8]};
                            divisor_q <= {56'b0, magnitudes_vs1_q[((number_of_divisions[2:0] - 1'b1) * 8) +: 8]};
                            cycles_counter <= 6'b000011;
                            number_of_divisions <= number_of_divisions - 1'b1;
                        end

                        SEW_16: begin
                            quotients[((number_of_divisions[1:0]) * 16) +: 16] <= dividend_quotient_out[0 +: 16];
                            remnants[((number_of_divisions[1:0]) * 16) +: 16] <= remnant_out[0 +: 16];
                            dividend_quotient_q <= {48'b0, magnitudes_vs2_q[((number_of_divisions[1:0] - 1'b1) * 16) +: 16]};
                            divisor_q <= {48'b0, magnitudes_vs1_q[((number_of_divisions[1:0] - 1'b1) * 16) +: 16]};
                            cycles_counter <= 6'b000111;
                            number_of_divisions <= number_of_divisions - 1'b1;
                        end

                        SEW_32: begin
                            quotients[((number_of_divisions[0]) * 32) +: 32] <= dividend_quotient_out[0 +: 32];
                            remnants[((number_of_divisions[0]) * 32) +: 32] <= remnant_out[0 +: 32];
                            dividend_quotient_q <= {32'b0, magnitudes_vs2_q[((number_of_divisions[0] - 1'b1) * 32) +: 32]};
                            divisor_q <= {32'b0, magnitudes_vs1_q[((number_of_divisions[0] - 1'b1) * 32) +: 32]};
                            cycles_counter <= 6'b001111;
                            number_of_divisions <= number_of_divisions - 1'b1;
                        end

                        //the SEW_64 and default won't happen since there is only 1, 64bit opration at a time
                        SEW_64: begin

                            dividend_quotient_q <= magnitudes_vs2_q;
                            divisor_q <= magnitudes_vs1_q;
                            cycles_counter <= 6'b011111;
                            number_of_divisions <= number_of_divisions - 1'b1;
                        end

                        default : begin

                            dividend_quotient_q <= magnitudes_vs2_q;
                            divisor_q <= magnitudes_vs1_q;
                            cycles_counter <= 6'b011111;
                            number_of_divisions <= number_of_divisions - 1'b1;
                        end

                endcase
                
                // when there is no more cycles and no more divisions, just save the result
                // this result is not used for output, but is saved for later DIV/REMs that
                // has matching operands.
                end else begin
                    case (sew_q)

                        SEW_8: begin
                            quotients[0 +: 8] <= dividend_quotient_out[0 +: 8];
                            remnants[0 +: 8] <= remnant_out[0 +: 8];
                            
                        end

                        SEW_16: begin
                            quotients[0 +: 16] <= dividend_quotient_out[0 +: 16];
                            remnants[0 +: 16] <= remnant_out[0 +: 16];
                            
                        end

                        SEW_32: begin
                            quotients[0 +: 32] <= dividend_quotient_out[0 +: 32];
                            remnants[0 +: 32] <= remnant_out[0 +: 32];
                            
                        end

                         SEW_64: begin
                            quotients[0 +: 64] <= dividend_quotient_out[0 +: 64];
                            remnants[0 +: 64] <= remnant_out[0 +: 64];
                            
                        end

                        default : begin
                            quotients[0 +: 64] <= dividend_quotient_out[0 +: 64];
                            remnants[0 +: 64] <= remnant_out[0 +: 64];
                            
                        end

                    endcase
                end
            end
        end
    end



//--------------------------------------------------------------------------------------------------
//----- OUTPUT INSTRUCTION -------------------------------------------------------------------------
//--------------------------------------------------------------------------------------------------

always_comb begin
    // Depending on the SEW and Divison by zero and final sign of the operation and results stored inside
    // quotients and remnants the final result is produced.
    case (sew_q)
        
        SEW_8: begin
            for (int i = 0 ; i < (DATA_SIZE/8) ; ++i) begin
                if(division_by_zero_q[i]) begin
                    quotients_out[(i * 8) +: 8] = 8'hFF;
                    remnants_out[(i * 8) +: 8] = dividened_elements_q[(i * 8) +: 8];
                end
                else begin
                    if (i > 0) begin
                        if((is_signed_inst(instr_type_q))) begin
                            quotients_out[(i * 8) +: 8] = result_signs_q[i] ? trunc_8_sum(~quotients[(i * 8) +: 8] + 8'b1) : quotients[(i * 8) +: 8];
                            remnants_out[(i * 8) +: 8] = dividened_elements_q[(i * 8) + 7]  ? trunc_8_sum(~remnants[(i * 8) +: 8] + 8'b1) : remnants[(i * 8) +: 8];
                        end
                        else begin
                            quotients_out[(i * 8) +: 8] = quotients[(i * 8) +: 8] ;
                            remnants_out[(i * 8) +: 8] = remnants[(i * 8) +: 8];
                        end
                    end
                    // when a 1 clock division is issued, the data of the last division is used to produce the final output
                    // and no other computation happens.
                    else if((is_division(instr_type_i) || is_remainder(instr_type_i)) && instr_valid_i && (exe_stages == 1'b1))begin
                        if((is_signed_inst(instr_type_i))) begin
                            quotients_out[(i * 8) +: 8] = result_signs_q[i] ? trunc_8_sum(~quotients[(i * 8) +: 8] + 8'b1) : quotients[(i * 8) +: 8];
                            remnants_out[(i * 8) +: 8] = dividened_elements_q[(i * 8) + 7]  ? trunc_8_sum(~remnants[(i * 8) +: 8] + 8'b1) : remnants[(i * 8) +: 8];
                        end
                        else begin
                            quotients_out[(i * 8) +: 8] = quotients[(i * 8) +: 8] ;
                            remnants_out[(i * 8) +: 8] = remnants[(i * 8) +: 8];
                        end
                    end 
                    
                    else begin 
                        if((is_signed_inst(instr_type_q))) begin
                            quotients_out[(i * 8) +: 8] = result_signs_q[i] ? trunc_8_sum(~dividend_quotient_out[(i * 8) +: 8] + 8'b1) : dividend_quotient_out[(i * 8) +: 8];
                            remnants_out[(i * 8) +: 8] = dividened_elements_q[(i * 8) + 7]  ? trunc_8_sum(~remnant_out[(i * 8) +: 8] + 8'b1) : remnant_out[(i * 8) +: 8];
                        end
                        else begin
                            quotients_out[(i * 8) +: 8] = dividend_quotient_out[(i * 8) +: 8] ;
                            remnants_out[(i * 8) +: 8] = remnant_out[(i * 8) +: 8];
                        end
                    end
                end
            end
        end

        SEW_16: begin
            for (int i = 0 ; i < (DATA_SIZE/16) ; ++i) begin
                if(division_by_zero_q[i]) begin
                    quotients_out[(i * 16) +: 16] = 16'hFFFF;
                    remnants_out[(i * 16) +: 16] = dividened_elements_q[(i * 16) +: 16]; 
                end
                else begin
                    if(i > 0) begin
                        if(is_signed_inst(instr_type_q)) begin
                            quotients_out[(i * 16) +: 16] = result_signs_q[i] ? trunc_16_sum(~quotients[(i * 16) +: 16] + 16'b1) : quotients[(i * 16) +: 16];
                            remnants_out[(i * 16) +: 16] = dividened_elements_q[(i * 16) + 15]  ? trunc_16_sum(~remnants[(i * 16) +: 16] + 16'b1) : remnants[(i * 16) +: 16];
                        end
                        else begin
                            quotients_out[(i * 16) +: 16] = quotients[(i * 16) +: 16] ;
                            remnants_out[(i * 16) +: 16] = remnants[(i * 16) +: 16];
                        end
                    end
                    // when a 1 clock division is issued, the data of the last division is used to produce the final output
                    // and no other computation happens.
                    else if((is_division(instr_type_i) || is_remainder(instr_type_i)) && instr_valid_i && (exe_stages == 1'b1))begin
                        if(is_signed_inst(instr_type_i)) begin
                                quotients_out[(i * 16) +: 16] = result_signs_q[i] ? trunc_16_sum(~quotients[(i * 16) +: 16] + 16'b1) : quotients[(i * 16) +: 16];
                                remnants_out[(i * 16) +: 16] = dividened_elements_q[(i * 16) + 15]  ? trunc_16_sum(~remnants[(i * 16) +: 16] + 16'b1) : remnants[(i * 16) +: 16];
                            end
                            else begin
                                quotients_out[(i * 16) +: 16] = quotients[(i * 16) +: 16] ;
                                remnants_out[(i * 16) +: 16] = remnants[(i * 16) +: 16];
                            end
                    end
                    else begin
                        if(is_signed_inst(instr_type_q)) begin
                            quotients_out[(i * 16) +: 16] = result_signs_q[i] ? trunc_16_sum(~dividend_quotient_out[(i * 16) +: 16] + 16'b1) : dividend_quotient_out[(i * 16) +: 16];
                            remnants_out[(i * 16) +: 16] = dividened_elements_q[(i * 16) + 15]  ? trunc_16_sum(~remnant_out[(i * 16) +: 16] + 16'b1) : remnant_out[(i * 16) +: 16];
                        end
                        else begin
                            quotients_out[(i * 16) +: 16] = dividend_quotient_out[(i * 16) +: 16] ;
                            remnants_out[(i * 16) +: 16] = remnant_out[(i * 16) +: 16];
                        end
                    end
                end
            end
        end

        SEW_32: begin
            for (int i = 0 ; i < (DATA_SIZE/32) ; ++i) begin
                if(division_by_zero_q[i]) begin
                    quotients_out[(i * 32) +: 32] = 32'hFFFFFFFF;
                    remnants_out[(i * 32) +: 32] = dividened_elements_q[(i * 32) +: 32];
                end
                else begin
                    if(i > 0) begin
                        if(is_signed_inst(instr_type_q)) begin
                            quotients_out[(i * 32) +: 32] = result_signs_q[i] ? trunc_32_sum(~quotients[(i * 32) +: 32] + 32'b1) : quotients[(i * 32) +: 32]  ;
                            remnants_out[(i * 32) +: 32] = dividened_elements_q[(i * 32) + 31]  ? trunc_32_sum(~remnants[(i * 32) +: 32] + 32'b1) : remnants[(i * 32) +: 32];
                        end
                        else begin
                            quotients_out[(i * 32) +: 32] = quotients[(i * 32) +: 32] ;
                            remnants_out[(i * 32) +: 32] = remnants[(i * 32) +: 32];
                        end
                    end
                    // when a 1 clock division is issued, the data of the last division is used to produce the final output
                    // and no other computation happens.
                    else if((is_division(instr_type_i) || is_remainder(instr_type_i)) && instr_valid_i && (exe_stages == 1'b1))begin
                        if(is_signed_inst(instr_type_i)) begin
                                quotients_out[(i * 32) +: 32] = result_signs_q[i] ? trunc_32_sum(~quotients[(i * 32) +: 32] + 32'b1) : quotients[(i * 32) +: 32]  ;
                                remnants_out[(i * 32) +: 32] = dividened_elements_q[(i * 32) + 31]  ? trunc_32_sum(~remnants[(i * 32) +: 32] + 32'b1) : remnants[(i * 32) +: 32];
                            end
                            else begin
                                quotients_out[(i * 32) +: 32] = quotients[(i * 32) +: 32] ;
                                remnants_out[(i * 32) +: 32] = remnants[(i * 32) +: 32];
                            end
                    end
                    else begin
                        if(is_signed_inst(instr_type_q)) begin
                            quotients_out[(i * 32) +: 32] = result_signs_q[i] ? trunc_32_sum(~dividend_quotient_out[(i * 32) +: 32] + 32'b1) : dividend_quotient_out[(i * 32) +: 32]  ;
                            remnants_out[(i * 32) +: 32] = dividened_elements_q[(i * 32) + 31]  ? trunc_32_sum(~remnant_out[(i * 32) +: 32] + 32'b1) : remnant_out[(i * 32) +: 32];
                        end
                        else begin
                            quotients_out[(i * 32) +: 32] = dividend_quotient_out[(i * 32) +: 32] ;
                            remnants_out[(i * 32) +: 32] = remnant_out[(i * 32) +: 32];
                        end
                    end
                end
            end
            
        end

        SEW_64: begin
            for (int i = 0 ; i < (DATA_SIZE/64) ; ++i) begin
                if(division_by_zero_q[i]) begin
                    quotients_out[(i * 64) +: 64] = 64'hFFFFFFFFFFFFFFFF;
                    remnants_out[(i * 64) +: 64] = dividened_elements_q[(i * 64) +: 64];
                end
                else
                    // The lines below are commented since they never happen,
                    // I won't delete them, they may have some use in the future 

                    // if(i > 0) begin
                    //     if(is_signed_inst(instr_type_q)) begin
                    //         quotients_out[(i * 64) +: 64] = result_signs_q[i] ? trunc_64_sum(~quotients[(i * 64) +: 64] + 64'b1) : quotients[(i * 64) +: 64]  ;
                    //         remnants_out[(i * 64) +: 64] = dividened_elements_q[(i * 64) + 63]  ? trunc_64_sum(~remnants[(i * 64) +: 64] + 64'b1) : remnants[(i * 64) +: 64];
                    //     end
                    //     else begin
                    //         quotients_out[(i * 64) +: 64] = quotients[(i * 64) +: 64] ;
                    //         remnants_out[(i * 64) +: 64] = remnants[(i * 64) +: 64];
                    //     end
                    // end
                    // else

                    // when a 1 clock division is issued, the data of the last division is used to produce the final output
                    // and no other computation happens. 
                    if((is_division(instr_type_i) || is_remainder(instr_type_i)) && instr_valid_i && (exe_stages == 1'b1))begin
                        if(is_signed_inst(instr_type_i)) begin
                                quotients_out[(i * 64) +: 64] = result_signs_q[i] ? trunc_64_sum(~quotients[(i * 64) +: 64] + 64'b1) : quotients[(i * 64) +: 64]  ;
                                remnants_out[(i * 64) +: 64] = dividened_elements_q[(i * 64) + 63]  ? trunc_64_sum(~remnants[(i * 64) +: 64] + 64'b1) : remnants[(i * 64) +: 64];
                            end
                            else begin
                                quotients_out[(i * 64) +: 64] = quotients[(i * 64) +: 64] ;
                                remnants_out[(i * 64) +: 64] = remnants[(i * 64) +: 64];
                            end
                    end 
                    else begin
                        if(is_signed_inst(instr_type_q)) begin
                            quotients_out[(i * 64) +: 64] = result_signs_q[i] ? trunc_64_sum(~dividend_quotient_out[(i * 64) +: 64] + 64'b1) : dividend_quotient_out[(i * 64) +: 64]  ;
                            remnants_out[(i * 64) +: 64] = dividened_elements_q[(i * 64) + 63]  ? trunc_64_sum(~remnant_out[(i * 64) +: 64] + 64'b1) : remnant_out[(i * 64) +: 64];
                        end
                        else begin
                            quotients_out[(i * 64) +: 64] = dividend_quotient_out[(i * 64) +: 64] ;
                            remnants_out[(i * 64) +: 64] = remnant_out[(i * 64) +: 64];
                        end
                    end
                
            end
        end

        default: begin
            for (int i = 0 ; i < (DATA_SIZE/64) ; ++i) begin
                if(division_by_zero_q[i]) begin
                    quotients_out[(i * 64) +: 64] = 64'hFFFFFFFFFFFFFFFF;
                    remnants_out[(i * 64) +: 64] = dividened_elements_q[(i * 64) +: 64];
                end
                else 
                    // The lines below are commented since they never happen,
                    // I won't delete them, they may have some use in the future 
                    

                    // if(i > 0) begin
                    //     if(is_signed_inst(instr_type_q)) begin
                    //         quotients_out[(i * 64) +: 64] = result_signs_q[i] ? trunc_64_sum(~quotients[(i * 64) +: 64] + 64'b1) : quotients[(i * 64) +: 64]  ;
                    //         remnants_out[(i * 64) +: 64] = dividened_elements_q[(i * 64) + 63]  ? trunc_64_sum(~remnants[(i * 64) +: 64] + 64'b1) : remnants[(i * 64) +: 64];
                    //     end
                    //     else begin
                    //         quotients_out[(i * 64) +: 64] = quotients[(i * 64) +: 64] ;
                    //         remnants_out[(i * 64) +: 64] = remnants[(i * 64) +: 64];
                    //     end
                    // end
                    // else

                    // when a 1 clock division is issued, the data of the last division is used to produce the final output
                    // and no other computation happens.
                    if((is_division(instr_type_i) || is_remainder(instr_type_i)) && instr_valid_i && (exe_stages == 1'b1))begin
                        if(is_signed_inst(instr_type_i)) begin
                                quotients_out[(i * 64) +: 64] = result_signs_q[i] ? trunc_64_sum(~quotients[(i * 64) +: 64] + 64'b1) : quotients[(i * 64) +: 64]  ;
                                remnants_out[(i * 64) +: 64] = dividened_elements_q[(i * 64) + 63]  ? trunc_64_sum(~remnants[(i * 64) +: 64] + 64'b1) : remnants[(i * 64) +: 64];
                            end
                            else begin
                                quotients_out[(i * 64) +: 64] = quotients[(i * 64) +: 64] ;
                                remnants_out[(i * 64) +: 64] = remnants[(i * 64) +: 64];
                            end
                    end
                    else 
                    begin 
                        if(is_signed_inst(instr_type_q)) begin
                            quotients_out[(i * 64) +: 64] = result_signs_q[i] ? trunc_64_sum(~dividend_quotient_out[(i * 64) +: 64] + 64'b1) : dividend_quotient_out[(i * 64) +: 64]  ;
                            remnants_out[(i * 64) +: 64] = dividened_elements_q[(i * 64) + 63]  ? trunc_64_sum(~remnant_out[(i * 64) +: 64] + 64'b1) : remnant_out[(i * 64) +: 64];
                        end
                        else begin
                            quotients_out[(i * 64) +: 64] = dividend_quotient_out[(i * 64) +: 64] ;
                            remnants_out[(i * 64) +: 64] = remnant_out[(i * 64) +: 64];
                        end
                    end
                
            end
        end

    endcase

end



assign data_vd_o = (instr_valid_i && (exe_stages == 1'b1)) ? 
(is_division(instr_type_i) ? quotients_out : remnants_out) : (is_division(instr_type_q) ? quotients_out : remnants_out);



endmodule



