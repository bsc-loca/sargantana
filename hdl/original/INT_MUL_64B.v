module INT_MUL_64B (
    input           clk_i,
    input           rst_ni,
    input           kill_mul_i,
    input           request_i,
    input   [2:0]   func3,
    input           int_32_i,
    input   [63:0]  src1_i,         // rs1
    input   [63:0]  src2_i,         // rs2
    output  [63:0]  result_o,
    output reg      stall_o,        // operation in flight
    output reg      done_tick_o     // operation finished
);


    wire same_sign;
    assign same_sign = int_32_i ? ~(src2_i[31] ^ src1_i[31]) : ~(src2_i[63] ^ src1_i[63]);

    // Source Operands
    reg    [63:0]   src1_int,src2_int;
    reg             neg_int;
    always@(*)
    begin
        case ({func3})
            // Multiply word, Low part, Signed - MUL , MULW
            3'b000:    begin
                        src1_int = ((src1_i[63]  & !int_32_i) | (src1_i[31]  & int_32_i)) ? ~src1_i + 64'b1 : src1_i;
                        src2_int = ((src2_i[63]  & !int_32_i) | (src2_i[31]  & int_32_i)) ? ~src2_i + 64'b1 : src2_i;
                        neg_int  = !same_sign;
                        end
            // Multiply word, High part, Signed - MULH
            3'b001:    begin
                        src1_int = (src1_i[63])  ? ~src1_i + 64'b1 : src1_i;
                        src2_int = (src2_i[63])  ? ~src2_i + 64'b1 : src2_i;
                        neg_int  = !same_sign;
                        end
            // Multiply word, High part, SignedxUnsigned - MULHSU
            3'b010:    begin
                        src1_int = (src1_i[63])  ? ~src1_i + 64'b1 : src1_i;
                        src2_int = src2_i;
                        neg_int  = src1_i[63];
                        end
            //  Multiply word, High part, Unsigned Unsigned MULHU
            3'b011:    begin
                        src1_int = src1_i;
                        src2_int = src2_i;
                        neg_int  = 1'b0;
                        end
            default:    begin
                        src1_int = 64'b0;
                        src2_int = 64'b0;
                        neg_int  = 1'b0;
                        end
        endcase
    end 

    reg [2:0] state_q, state_d;
    reg [95:0]  stg1_result1_q,stg1_result1_d;
    reg [95:0]  stg1_result2_q,stg1_result2_d;

    wire [95:0] stg1_result1,stg1_result2;
    assign  stg1_result1= src1_int * src2_int[31:0];
    assign  stg1_result2= src1_int * src2_int[63:32];

    // 32-bit multiplication MULW
    wire [63:0] stg1_result;
    assign stg1_result = neg_int ?  ~stg1_result1_q[63:0] + 64'b1 : stg1_result1_q[63:0] ;
    //assign stg1_result = neg_int ?  ~stg1_result1[63:0] + 64'b1 : stg1_result1[63:0] ;

    // 64-bit multiplication MUL .... 
    wire [127:0] stg2_result;
    assign stg2_result = {32'b0,stg1_result1_q} + {stg1_result2_q[95:0],32'b0};

    wire    [127:0] AUX_MUL;
    assign  AUX_MUL= neg_int ? ~stg2_result + 128'b1 : stg2_result;

    reg    [63:0] AUX_MUL_RESULT;
    always@(*)
    begin
        case ({func3})
            // Multiply word, Low part, Signed - MUL , MULW
            3'b000:    begin
                        AUX_MUL_RESULT = AUX_MUL[63:0];
                        end
            // Multiply word, High part, Signed - MULH
            3'b001:    begin
                        AUX_MUL_RESULT = AUX_MUL[127:64];
                        end
            // Multiply word, High part, SignedxUnsigned - MULHSU
            3'b010:    begin
                        AUX_MUL_RESULT =  AUX_MUL[127:64];
                        end
            //  Multiply word, High part, Unsigned Unsigned MULHU
            3'b011:    begin
                        AUX_MUL_RESULT = AUX_MUL[127:64];
                        end
            default:    begin
                        AUX_MUL_RESULT = 64'b0;
                        end
        endcase
    end 


    parameter   IDLE    = 3'b000,
                DONE    = 3'b011;

    // FSMD state & data registers
    always @(posedge clk_i)
        if (~rst_ni) begin
            state_q         <= IDLE;
            stg1_result1_q   <= 0;
            stg1_result2_q   <= 0;
        end else begin
            state_q         <= state_d;
            stg1_result1_q  <= stg1_result1_d;
            stg1_result2_q  <= stg1_result2_d;
        end

    // FSMD next-state logic
    always @(*) begin
        state_d         = state_q;
        stall_o         = 1'b0;
        done_tick_o     = 1'b0;
        stg1_result1_d  = 96'b0;
        stg1_result2_d  = 96'b0;
        case (state_q)
            IDLE:   begin
                if (request_i & ~kill_mul_i) begin
                    stall_o         = /*int_32_i ? 1'b0:*/ 1'b1;
                    stg1_result1_d  = stg1_result1;
                    stg1_result2_d  = stg1_result2;
                    state_d         = /*int_32_i ? IDLE:*/ DONE;
                    done_tick_o     = /*int_32_i ? 1'b1:*/1'b0;
                end
            end
            DONE:   begin
                if (kill_mul_i) begin
                    state_d = IDLE;
                    stall_o = 1'b0;
                end else begin
                    stall_o     = 1'b0;
                    done_tick_o = 1'b1;
                    state_d     = IDLE;
                end
            end
            default:    state_d = IDLE;
        endcase // state_q
    end

    // output
    assign result_o = done_tick_o ? (int_32_i ? stg1_result:AUX_MUL_RESULT ): 64'b0 ;
endmodule // divider
