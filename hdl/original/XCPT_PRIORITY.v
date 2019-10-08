`include "LAGARTO_CONFIG.v"

module XCPT_PRIORITY(
input                   priority_0,
input                   priority_1,
input                   priority_2,
input                   priority_3,
input                   priority_4,
input                   priority_5,
input                   priority_6,
input                   priority_7,
input       `WORD_DATA  cause_0,
input       `WORD_DATA  cause_1,
input       `WORD_DATA  cause_2,
input       `WORD_DATA  cause_3,
input       `WORD_DATA  cause_4,
input       `WORD_DATA  cause_5,
input       `WORD_DATA  cause_6,
input       `WORD_DATA  cause_7,

output                  xcpt,
output  reg `WORD_DATA  xcpt_cause
);

always@(*)
begin
    casex({priority_0,priority_1,priority_2,priority_3,priority_4,priority_5,priority_6,priority_7})
        8'b1xxxxxxx:    xcpt_cause = cause_0;
        8'b01xxxxxx:    xcpt_cause = cause_1;
        8'b001xxxxx:    xcpt_cause = cause_2;
        8'b0001xxxx:    xcpt_cause = cause_3;
        8'b00001xxx:    xcpt_cause = cause_4;
        8'b000001xx:    xcpt_cause = cause_5;
        8'b0000001x:    xcpt_cause = cause_6;
        8'b00000001:    xcpt_cause = cause_7;
        default:        xcpt_cause = 64'b0; 
    endcase
end

assign  xcpt = priority_0 | priority_1 | priority_2 | priority_3 | priority_4 | priority_5 | priority_6 | priority_7;
endmodule
