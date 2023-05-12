// Module used to dump information comming from writeback stage
module rename_checking_behav
(
input clk,
input rst,
input [5:0] r0,
input [5:0] r1,
input [5:0] r2,
input [5:0] r3,
input [5:0] r4,
input [5:0] r5,
input [5:0] r6,
input [5:0] r7,
input [5:0] r8,
input [5:0] r9,
input [5:0] r10,
input [5:0] r11,
input [5:0] r12,
input [5:0] r13,
input [5:0] r14,
input [5:0] r15,
input [5:0] r16,
input [5:0] r17,
input [5:0] r18,
input [5:0] r19,
input [5:0] r20,
input [5:0] r21,
input [5:0] r22,
input [5:0] r23,
input [5:0] r24,
input [5:0] r25,
input [5:0] r26,
input [5:0] r27,
input [5:0] r28,
input [5:0] r29,
input [5:0] r30,
input [5:0] r31,
input [4:0] head,
input [4:0] tail,
input [5:0] num
);
 


// DPI calls definition
import "DPI-C" function
 void rename_checking_dump (input longint unsigned r0, input longint unsigned r1, input longint unsigned r2, input longint unsigned r3, 
                            input longint unsigned r4, input longint unsigned r5, input longint unsigned r6, input longint unsigned r7, 
                            input longint unsigned r8, input longint unsigned r9, input longint unsigned r10, input longint unsigned r11, 
                            input longint unsigned r12, input longint unsigned r13, input longint unsigned r14, input longint unsigned r15, 
                            input longint unsigned r16, input longint unsigned r17, input longint unsigned r18, input longint unsigned r19, 
                            input longint unsigned r20, input longint unsigned r21, input longint unsigned r22, input longint unsigned r23, 
                            input longint unsigned r24, input longint unsigned r25, input longint unsigned r26, input longint unsigned r27, 
                            input longint unsigned r28, input longint unsigned r29, input longint unsigned r30, input longint unsigned r31, 
                            input longint unsigned head, input longint unsigned tail, input longint unsigned num);
import "DPI-C" function void rename_checking_init();

// Main always
always @(posedge clk) begin
  if (!rst) begin
    rename_checking_dump (r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, 
                            r15, r16, r17, r18, r19, r20, r21, r22, r23, r24, r25, r26, 
                            r27, r28, r29, r30, r31, head, tail, num);
  end
end

endmodule
