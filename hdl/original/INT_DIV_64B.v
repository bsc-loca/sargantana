module INT_DIV_64B (
    input           clk_i,
    input           rst_ni,
    input           kill_div_i,
    input           request_i,
    input           int_32_i,
    input           signed_op_i,
    input   [63:0]  dvnd_i,         // rs1
    input   [63:0]  dvsr_i,         // rs2
    output  [63:0]  quo_o,
    output  [63:0]  rmd_o,
    output reg      stall_o,        // operation in flight
    output reg      done_tick_o     // operation finished
);

    reg [2:0] state_q, state_d;

    parameter   IDLE    = 3'b000,
                OP      = 3'b001,
                LAST    = 3'b010,
                DONE    = 3'b011;

    reg [63:0]     rh_q, rh_d, rl_q, rl_d, rh_tmp;
    reg [63:0]     divisor_q, divisor_d;
    reg [64:0]       n_q, n_d;
    reg             q_bit;

    wire div_zero;
    wire same_sign;
    wire [63:0] dvnd_int, dvsr_int;

    assign div_zero = int_32_i ? ~(|dvsr_i[31:0]): ~(|dvsr_i);
    assign same_sign = int_32_i ? ~(dvsr_i[31] ^ dvnd_i[31]) : ~(dvsr_i[63] ^ dvnd_i[63]);

    assign dvnd_int =  ((dvnd_i[63] & signed_op_i & !int_32_i) | (dvnd_i[31] & signed_op_i & int_32_i)) ? ~dvnd_i + 64'b1 : dvnd_i;
    assign dvsr_int =  ((dvsr_i[63] & signed_op_i & !int_32_i) | (dvsr_i[31] & signed_op_i & int_32_i)) ? ~dvsr_i + 64'b1 : dvsr_i;


    // FSMD state & data registers
    always @(posedge clk_i)
        if (~rst_ni) begin
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
            IDLE:   begin               // dvsr  = 64'h00000000FFFFF948;    dvnd  = 64'hFFFFFF9A00000000;
                if (request_i & ~kill_div_i) begin
                    stall_o     = 1'b1;
                    rh_d        = 0;
                    rl_d        = int_32_i ? {dvnd_int[31:0],32'b0} : dvnd_int;     // dividend with sign
                    divisor_d   = int_32_i ? {32'b0, dvsr_int[31:0]} : dvsr_int;    // divisor with sign
                    n_d         = int_32_i ? 33 : 65;
                    state_d     = OP;
                end
            end
            OP:     begin
                if (kill_div_i) begin
                    state_d = IDLE;
                    stall_o = 1'b0;                    
                end else begin
                    stall_o = 1'b1;
                    rl_d = {rl_q[62:0], q_bit};
                    rh_d = {rh_tmp[62:0], rl_q[63]};  // shit rh and rl left
                    n_d  = n_q - 1;                     // decrease index
                    if (n_d == 1)
                        state_d = LAST;
                end
            end
            LAST:   begin
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
            DONE:   begin
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
            default:    state_d = IDLE;
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
    assign quo_o = done_tick_o ? (div_zero ? 64'hFFFFFFFFFFFFFFFF : (signed_op_i ? (same_sign ? rl_q : ~rl_q + 64'b1) : rl_q)) : 64'b0 ;
    assign rmd_o = done_tick_o ? (div_zero ? dvnd_i : (signed_op_i ? ( ((dvnd_i[63] &  !int_32_i) | (dvnd_i[31] & int_32_i)) ? ~rh_q + 64'b1 : rh_q) : rh_q)) : 64'b0;

endmodule // divider
