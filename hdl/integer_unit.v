//----------------------------------------------------------------------------------------------------------------------
//                                        INTEGER FUNCTIONAL UNIT - ISA: RISCV ISA RV64I
//----------------------------------------------------------------------------------------------------------------------
// Integer computational instructions are either encoded as register-immediate operations using
// the I-type format or as register-register operations using the R-type format.
//  The destination is register rd for both register-immediate and register-register instructions.
//----------------------------------------------------------------------------------------------------------------------
//  EXCEPTIONS
// No integer computational instructions cause arithmetic exceptions.
//  SLLIW, SRLIW, and SRAIW generate an illegal instruction exception if imm[5] 6= 0.
//
//
//  AUTOR: CRISTOBAL RAMIREZ LAZO
//
//----------------------------------------------------------------------------------------------------------------------
`default_nettype none
`include "definitions.v"

module integer_unit (
    input wire        clk_i,
    input wire        rstn_i,

    input wire        wb_exception_i,

    input wire `ADDR  pc_i,
    input wire [15:0] control_i,
    input wire `INST  inst_i,

    input wire `DATA  data_source_1_i,
    input wire `DATA  data_source_2_i,

    output reg        ready_o,
    output reg `DATA  aluresult_o,
    output reg [4:0]  addr_write_o,

    output wire       lock_o,

    output wire       excepcion_illegal_inst_o,
    output wire       excepcion_div_by_0_o,
    output wire       excepcion_div_over_o
);

// Declarations
wire `DATA source_1;
wire `DATA source_2;
wire int_32;
reg `DATA aluresult_aux;
reg ready_aux;
reg illegal_inst_exception_aux;
wire `DATA source2_immediate_64;
wire `DATA source2_immediate_64_aux;
wire [5:0] shamt;
wire [5:0] shamt_aux;
wire [5:0] shiftword;
wire `DATA shift_right_arith;
wire [6:0] opcode_field;
wire [2:0] funct3_field;
wire [6:0] funct7_field;
wire [4:0] rd_field;
wire valid_inst;
wire valid_opcode;
wire immediate;
wire [11:0] source_immediate_12;
wire [19:0] source_immediate_20;
wire `DATA mul_result;
wire [63:0] int_division;
wire [63:0] int_reminder;
wire ready_div_rem;
wire signed_div;
wire valid_div;
reg `DATA aluresult_aux2;
reg ready_aux2;
wire `DATA source_immediate_64;
wire valid_mul;
wire lock_mul;
wire lock_div;
wire ready_mul;

// --------------------------------------------------------------------------------------------------
// SHIFT WORD INSTRUCTIONS AND IMMEDIATE OPERANDS
// --------------------------------------------------------------------------------------------------
assign source_1 = (int_32) ? {32'h0,data_source_1_i[31:0]} : data_source_1_i;
assign source_2 = (int_32) ? {32'h0,data_source_2_i[31:0]} : data_source_2_i;

assign opcode_field = inst_i[6:0];
assign funct3_field = inst_i[14:12];
assign funct7_field = inst_i[31:25];
assign rd_field = inst_i[11:7];

assign valid_inst = (control_i[0] | control_i[1]) & control_i[3] & ~control_i[5];
assign int_32 = control_i[9];
assign valid_opcode = control_i[10] & ~control_i[11];

assign immediate = control_i[1];
assign source_immediate_12 = inst_i[31:20];
assign source_immediate_20 = inst_i[31:12];

assign source2_immediate_64_aux = {{52{source_immediate_12[11]}},source_immediate_12[11:0]};
assign source2_immediate_64 = (int_32) ? {32'h0,source2_immediate_64_aux[31:0]}:source2_immediate_64_aux;

assign shamt = source_immediate_12[5:0] ;
assign shiftword = (int_32) ? {1'b0,source_2[4:0]}: source_2[5:0];
assign shamt_aux = (immediate) ? shamt:shiftword;

shift_word_right_arith shift_word_right_arith_inst(
    .shamt_i          (shamt_aux),
    .int_32_i         (int_32),
    .input_data_i     (source_1),
    .output_data_o    (shift_right_arith)
);

// --------------------------------------------------------------------------------------------------
// MULTIPLICATION  INSTRUCTIONS
// --------------------------------------------------------------------------------------------------

assign valid_mul = ((funct3_field == 3'b000) | (funct3_field == 3'b001) | (funct3_field == 3'b010) | (funct3_field == 3'b011)) & (funct7_field == 7'b0000001) & valid_inst & ~immediate;

mul_unit mul_unit_inst (
    .clk_i(clk_i),
    .rstn_i(rstn_i),
    .kill_mul_i(wb_exception_i),
    .request_i(valid_mul),
    .func3_i(funct3_field),
    .int_32_i(int_32),
    .src1_i(source_1),
    .src2_i(source_2),
    .result_o(mul_result),
    .stall_o(lock_mul),
    .done_tick_o(ready_mul)
);

// --------------------------------------------------------------------------------------------------
// DIVISION AND REMINDER INSTRUCTIONS
// --------------------------------------------------------------------------------------------------
//The semantics for division by zero and division overflow are summarized below.
//The quotient of division by zero has all bits set, i.e. 2XLEN-1 for unsigned division or -1 for signed division.
//The remainder of division by zero equals the dividend.
//Signed division overflow occurs only when the most-negative integer, 2XLEN-1, is divided by -1. The quotient of signed division
//overflow is equal to the dividend, and the remainder is zero. Unsigned division overflow cannot occur.
//
//                                    DIVIDEND    DIVISOR    DIVU        REMU    DIV          REM
// DIVISION_BY_ZERO_EXCEPTION         X           0          2^leng-1    X       -1           X
// OVERFLOW_EXCEPTION                 -2^leng-1   -1         -           -       -2^leng-1    0
// --------------------------------------------------------------------------------------------------
assign signed_div = ~funct3_field[0];
assign valid_div = ((funct3_field == 3'b100) | (funct3_field == 3'b101) | (funct3_field == 3'b110) | (funct3_field == 3'b111)) & (funct7_field == 7'b0000001) & valid_inst & ~immediate;

div_unit div_unit_inst(
    .clk_i          (clk_i),
    .rstn_i         (rstn_i),
    .kill_div_i     (wb_exception_i),
    .request_i      (valid_div),
    .int_32_i       (int_32),
    .signed_op_i    (signed_div),
    .dvnd_i         (data_source_1_i), // source_1
    .dvsr_i         (data_source_2_i), // source_2

    .quo_o          (int_division),
    .rmd_o          (int_reminder),
    .stall_o        (lock_div),
    .done_tick_o    (ready_div_rem)
);

always@(*) begin
    case ({valid_inst,immediate,funct3_field})
        // ------------------------------------------------------------------------------------------
        // register-register instructions
        // ------------------------------------------------------------------------------------------
        5'b10000: begin
            case(funct7_field)
                7'b0000000: begin  // add word  - add
                    aluresult_aux = source_1 + source_2;
                    ready_aux = 1'b1;
                    illegal_inst_exception_aux = 1'b0;
                end
                7'b0100000: begin  // subtract word - sub
                    aluresult_aux = source_1 - source_2;
                    ready_aux = 1'b1;
                    illegal_inst_exception_aux = 1'b0;
                end
                7'b0000001: begin  // multiply word, low part, signed - mul , mulw
                    aluresult_aux = mul_result;
                    ready_aux = ready_mul;
                    illegal_inst_exception_aux = 1'b0;
                end
                default: begin
                    aluresult_aux = `ZERO_DATA;
                    ready_aux = 1'b1;
                    illegal_inst_exception_aux = 1'b1;
                end
            endcase
        end
        5'b10001: begin
            case(funct7_field)
                7'b0000000: begin  // shift word left logical - sll
                    aluresult_aux = source_1 << shiftword ;
                    ready_aux = 1'b1;
                    illegal_inst_exception_aux = 1'b0;
                end
                7'b0000001: begin  // multiply word, high part, signed - mulh
                    aluresult_aux = mul_result;
                    ready_aux = ready_mul;
                    illegal_inst_exception_aux = 1'b0;
                end
                default: begin
                    aluresult_aux = `ZERO_DATA;
                    ready_aux = 1'b1;
                    illegal_inst_exception_aux = 1'b1;
                end
            endcase
        end
        5'b10010: begin
            case(funct7_field)
                7'b0000000: begin  // set on less than - slt
                    aluresult_aux = ($signed(source_1) < $signed(source_2))  ? `ONE_DATA : `ZERO_DATA;
                    ready_aux = 1'b1;
                    illegal_inst_exception_aux = 1'b0;
                end
                7'b0000001: begin  // multiply word, high part, signedxunsigned - mulhsu
                    aluresult_aux = mul_result;
                    ready_aux = ready_mul;
                    illegal_inst_exception_aux = 1'b0;
                end
                default: begin
                    aluresult_aux= `ZERO_DATA;
                    ready_aux= 1'b1;
                    illegal_inst_exception_aux = 1'b1;
                end
            endcase
        end
        5'b10011: begin
            case(funct7_field)
                7'b0000000: begin  // set on less than unsigned - sltu
                    aluresult_aux = (source_1 < source_2)  ? `ONE_DATA : `ZERO_DATA;
                    ready_aux = 1'b1;
                    illegal_inst_exception_aux = 1'b0;
                end
                7'b0000001: begin  // multiply word, high part, unsigned unsigned mulhu
                    aluresult_aux = mul_result;
                    ready_aux = ready_mul;
                    illegal_inst_exception_aux = 1'b0;
                end
                default: begin
                    aluresult_aux = `ZERO_DATA;
                    ready_aux = 1'b1;
                    illegal_inst_exception_aux = 1'b1;
                end
            endcase
        end
        5'b10100:  begin
            case(funct7_field)
            7'b0000000: begin  //exclusive or - xor
                aluresult_aux = source_1 ^ source_2;
                ready_aux = 1'b1;
                illegal_inst_exception_aux = 1'b0;
            end
            7'b0000001: begin  //  divide words, signed div
                aluresult_aux = int_division;
                ready_aux = ready_div_rem;
                illegal_inst_exception_aux = 1'b0;
            end
            default: begin
                aluresult_aux = `ZERO_DATA;
                ready_aux = 1'b1;
                illegal_inst_exception_aux = 1'b1;
            end
            endcase
        end

        5'b10101: begin
            case(funct7_field)
                7'b0000000: begin  //shift word right logical - srl
                    aluresult_aux = source_1 >> shiftword;
                    ready_aux = 1'b1;
                    illegal_inst_exception_aux = 1'b0;
                end
                7'b0100000: begin  //shift word right arithmetic - sra
                    aluresult_aux = shift_right_arith;
                    ready_aux = 1'b1;
                    illegal_inst_exception_aux = 1'b0;
                end
                7'b0000001: begin  //  divide words, unsigned div
                    aluresult_aux = int_division;
                    ready_aux = ready_div_rem;
                    illegal_inst_exception_aux = 1'b0;
                end
                default: begin
                    aluresult_aux = `ZERO_DATA;
                    ready_aux = 1'b1;
                    illegal_inst_exception_aux = 1'b1;
                end
            endcase
        end
        5'b10110:  begin
            case(funct7_field)
            7'b0000000: begin  // or
                aluresult_aux = source_1 | source_2;
                ready_aux = 1'b1;
                illegal_inst_exception_aux = 1'b0;
            end
            7'b0000001: begin  //  remider, signed - rem
                aluresult_aux = int_reminder;
                ready_aux = ready_div_rem;
                illegal_inst_exception_aux = 1'b0;
            end
            default: begin
                aluresult_aux = `ZERO_DATA;
                ready_aux = 1'b1;
                illegal_inst_exception_aux = 1'b1;
            end
            endcase
        end
        5'b10111:  begin
            case(funct7_field)
            7'b0000000: begin  // and
                aluresult_aux = source_1 & source_2;
                ready_aux = 1'b1;
                illegal_inst_exception_aux = 1'b0;
            end
            7'b0000001: begin  //  remider, unsigned - remu
                aluresult_aux = int_reminder;
                ready_aux = ready_div_rem;
                illegal_inst_exception_aux = 1'b0;
            end
            default: begin
                aluresult_aux = `ZERO_DATA;
                ready_aux = 1'b1;
                illegal_inst_exception_aux = 1'b1;
            end
            endcase
        end
        // ------------------------------------------------------------------------------------------------------
        // register-immediate instructions
        // ------------------------------------------------------------------------------------------------------
        5'b11000: begin  // add immediate - addi
            aluresult_aux = source_1 + source2_immediate_64;
            ready_aux = 1'b1;
            illegal_inst_exception_aux = 1'b0;
        end
        5'b11001: begin  // shift word left logical immediate - slli , slliw
            if(funct7_field[6:1] == 6'b000000) begin
                aluresult_aux = source_1 << shamt;
                ready_aux = 1'b1;
                illegal_inst_exception_aux = int_32 & shamt[5];
            end else begin
                aluresult_aux = `ZERO_DATA;
                ready_aux = 1'b1;
                illegal_inst_exception_aux = 1'b1;
            end
        end
        5'b11010: begin  // set on less than immediate - slti
            aluresult_aux = ( $signed(source_1) < $signed(source2_immediate_64))  ? `ONE_DATA : `ZERO_DATA;
            ready_aux = 1'b1;
            illegal_inst_exception_aux = 1'b0;
        end
        5'b11011: begin  // set on less than immediate unsigned - sltiu
            aluresult_aux = ( source_1 < source2_immediate_64)  ? `ONE_DATA : `ZERO_DATA;
            ready_aux = 1'b1;
            illegal_inst_exception_aux = 1'b0;
        end
        5'b11100: begin  // xor immediate - xori
            aluresult_aux = source_1 ^ source2_immediate_64;
            ready_aux = 1'b1;
            illegal_inst_exception_aux = 1'b0;
        end
        5'b11101: begin  //shift word right logical imediate, shift word right arithmetic imediate - srli , srai , srliw , sraiw
            if(funct7_field[6:1] == 6'b000000) begin
                aluresult_aux = source_1 >> shamt;
                ready_aux = 1'b1;
                illegal_inst_exception_aux = int_32 & shamt[5];
            end else if(funct7_field[6:1] == 6'b010000) begin
                aluresult_aux = shift_right_arith;
                ready_aux = 1'b1;
                illegal_inst_exception_aux = int_32 & shamt[5];
            end else begin
                aluresult_aux = `ZERO_DATA;
                ready_aux = 1'b1;
                illegal_inst_exception_aux = 1'b1;
            end
        end
        5'b11110: begin  // or immediate - ori
            aluresult_aux = source_1 | source2_immediate_64;
            ready_aux = 1'b1;
            illegal_inst_exception_aux = 1'b0;
        end
        5'b11111: begin  // and immediate - andi
            aluresult_aux = source_1 & source2_immediate_64;
            ready_aux = 1'b1;
            illegal_inst_exception_aux = 1'b0;
        end
        default: begin
            aluresult_aux = `ZERO_DATA;
            ready_aux = 1'b0;
            illegal_inst_exception_aux = 1'b0;
        end
    endcase
end

// ------------------------------------------------------------------------------------------------------
// OPERATIONS CONTROLED BY ONLY OPCODE
// ------------------------------------------------------------------------------------------------------
assign source_immediate_64 = {{32{source_immediate_20[19]}},source_immediate_20[19:0],12'b0} ;

always@(*) begin
    case (opcode_field[6:2])
        5'b01101: begin  // load upper immediate - lui
            aluresult_aux2 = source_immediate_64;
            ready_aux2 = 1'b1;
        end
        5'b00101: begin  // add upper immediate to pc - auipc
            aluresult_aux2 = source_immediate_64 + {{24{pc_i[39]}},pc_i};
            ready_aux2 = 1'b1;
        end
        default: begin
            aluresult_aux2 = `ZERO_DATA;
            ready_aux2 = 1'b0;
        end
    endcase
end

assign ready_o = (valid_opcode) ? ready_aux2 : ready_aux;
assign aluresult_o = (valid_opcode) ? aluresult_aux2 : (int_32) ? {{32{aluresult_aux[31]}},aluresult_aux[31:0]} : aluresult_aux;
assign addr_write_o = (valid_inst | valid_opcode) ?  rd_field : 5'b0;

assign excepcion_illegal_inst_o = illegal_inst_exception_aux;
assign excepcion_div_by_0_o = 1'b0;
assign excepcion_div_over_o = 1'b0;

assign lock_o = lock_div | lock_mul;

endmodule


//-----------------------------------------------------------------------------------------------
// functional unit - shift_word_right_arithmetic
//-----------------------------------------------------------------------------------------------

module shift_word_right_arith (
    input  wire [5:0]  shamt_i,
    input  wire        int_32_i,
    input  wire `DATA  input_data_i,
    output reg  `DATA  output_data_o
);

always@(*) begin
    case (shamt_i)
        6'b000000:  output_data_o = input_data_i;

        6'b000001:  output_data_o = (int_32_i) ? {{1{input_data_i[31]}},input_data_i[31:1]}: {{1{input_data_i[63]}},input_data_i[63:1]};
        6'b000010:  output_data_o = (int_32_i) ? {{2{input_data_i[31]}},input_data_i[31:2]}: {{2{input_data_i[63]}},input_data_i[63:2]};
        6'b000011:  output_data_o = (int_32_i) ? {{3{input_data_i[31]}},input_data_i[31:3]}: {{3{input_data_i[63]}},input_data_i[63:3]};
        6'b000100:  output_data_o = (int_32_i) ? {{4{input_data_i[31]}},input_data_i[31:4]}: {{4{input_data_i[63]}},input_data_i[63:4]};
        6'b000101:  output_data_o = (int_32_i) ? {{5{input_data_i[31]}},input_data_i[31:5]}: {{5{input_data_i[63]}},input_data_i[63:5]};
        6'b000110:  output_data_o = (int_32_i) ? {{6{input_data_i[31]}},input_data_i[31:6]}: {{6{input_data_i[63]}},input_data_i[63:6]};
        6'b000111:  output_data_o = (int_32_i) ? {{7{input_data_i[31]}},input_data_i[31:7]}: {{7{input_data_i[63]}},input_data_i[63:7]};
        6'b001000:  output_data_o = (int_32_i) ? {{8{input_data_i[31]}},input_data_i[31:8]}: {{8{input_data_i[63]}},input_data_i[63:8]};

        6'b001001:  output_data_o = (int_32_i) ? {{9{input_data_i[31]}},input_data_i[31:9]}: {{9{input_data_i[63]}},input_data_i[63:9]};
        6'b001010:  output_data_o = (int_32_i) ? {{10{input_data_i[31]}},input_data_i[31:10]}: {{10{input_data_i[63]}},input_data_i[63:10]};
        6'b001011:  output_data_o = (int_32_i) ? {{11{input_data_i[31]}},input_data_i[31:11]}: {{11{input_data_i[63]}},input_data_i[63:11]};
        6'b001100:  output_data_o = (int_32_i) ? {{12{input_data_i[31]}},input_data_i[31:12]}: {{12{input_data_i[63]}},input_data_i[63:12]};
        6'b001101:  output_data_o = (int_32_i) ? {{13{input_data_i[31]}},input_data_i[31:13]}: {{13{input_data_i[63]}},input_data_i[63:13]};
        6'b001110:  output_data_o = (int_32_i) ? {{14{input_data_i[31]}},input_data_i[31:14]}: {{14{input_data_i[63]}},input_data_i[63:14]};
        6'b001111:  output_data_o = (int_32_i) ? {{15{input_data_i[31]}},input_data_i[31:15]}: {{15{input_data_i[63]}},input_data_i[63:15]};
        6'b010000:  output_data_o = (int_32_i) ? {{16{input_data_i[31]}},input_data_i[31:16]}: {{16{input_data_i[63]}},input_data_i[63:16]};

        6'b010001:  output_data_o = (int_32_i) ? {{17{input_data_i[31]}},input_data_i[31:17]}: {{17{input_data_i[63]}},input_data_i[63:17]};
        6'b010010:  output_data_o = (int_32_i) ? {{18{input_data_i[31]}},input_data_i[31:18]}: {{18{input_data_i[63]}},input_data_i[63:18]};
        6'b010011:  output_data_o = (int_32_i) ? {{19{input_data_i[31]}},input_data_i[31:19]}: {{19{input_data_i[63]}},input_data_i[63:19]};
        6'b010100:  output_data_o = (int_32_i) ? {{20{input_data_i[31]}},input_data_i[31:20]}: {{20{input_data_i[63]}},input_data_i[63:20]};
        6'b010101:  output_data_o = (int_32_i) ? {{21{input_data_i[31]}},input_data_i[31:21]}: {{21{input_data_i[63]}},input_data_i[63:21]};
        6'b010110:  output_data_o = (int_32_i) ? {{22{input_data_i[31]}},input_data_i[31:22]}: {{22{input_data_i[63]}},input_data_i[63:22]};
        6'b010111:  output_data_o = (int_32_i) ? {{23{input_data_i[31]}},input_data_i[31:23]}: {{23{input_data_i[63]}},input_data_i[63:23]};
        6'b011000:  output_data_o = (int_32_i) ? {{24{input_data_i[31]}},input_data_i[31:24]}: {{24{input_data_i[63]}},input_data_i[63:24]};

        6'b011001:  output_data_o = (int_32_i) ? {{25{input_data_i[31]}},input_data_i[31:25]}: {{25{input_data_i[63]}},input_data_i[63:25]};
        6'b011010:  output_data_o = (int_32_i) ? {{26{input_data_i[31]}},input_data_i[31:26]}: {{26{input_data_i[63]}},input_data_i[63:26]};
        6'b011011:  output_data_o = (int_32_i) ? {{27{input_data_i[31]}},input_data_i[31:27]}: {{27{input_data_i[63]}},input_data_i[63:27]};
        6'b011100:  output_data_o = (int_32_i) ? {{28{input_data_i[31]}},input_data_i[31:28]}: {{28{input_data_i[63]}},input_data_i[63:28]};
        6'b011101:  output_data_o = (int_32_i) ? {{29{input_data_i[31]}},input_data_i[31:29]}: {{29{input_data_i[63]}},input_data_i[63:29]};
        6'b011110:  output_data_o = (int_32_i) ? {{30{input_data_i[31]}},input_data_i[31:30]}: {{30{input_data_i[63]}},input_data_i[63:30]};
        6'b011111:  output_data_o = (int_32_i) ? {{31{input_data_i[31]}},input_data_i[31]}: {{31{input_data_i[63]}},input_data_i[63:31]};

        6'b100000:  output_data_o =  {{32{input_data_i[63]}},input_data_i[63:32]};
        6'b100001:  output_data_o =  {{33{input_data_i[63]}},input_data_i[63:33]};
        6'b100010:  output_data_o =  {{34{input_data_i[63]}},input_data_i[63:34]};
        6'b100011:  output_data_o =  {{35{input_data_i[63]}},input_data_i[63:35]};
        6'b100100:  output_data_o =  {{36{input_data_i[63]}},input_data_i[63:36]};
        6'b100101:  output_data_o =  {{37{input_data_i[63]}},input_data_i[63:37]};
        6'b100110:  output_data_o =  {{38{input_data_i[63]}},input_data_i[63:38]};
        6'b100111:  output_data_o =  {{39{input_data_i[63]}},input_data_i[63:39]};
        6'b101000:  output_data_o =  {{40{input_data_i[63]}},input_data_i[63:40]};

        6'b101001:  output_data_o =  {{41{input_data_i[63]}},input_data_i[63:41]};
        6'b101010:  output_data_o =  {{42{input_data_i[63]}},input_data_i[63:42]};
        6'b101011:  output_data_o =  {{43{input_data_i[63]}},input_data_i[63:43]};
        6'b101100:  output_data_o =  {{44{input_data_i[63]}},input_data_i[63:44]};
        6'b101101:  output_data_o =  {{45{input_data_i[63]}},input_data_i[63:45]};
        6'b101110:  output_data_o =  {{46{input_data_i[63]}},input_data_i[63:46]};
        6'b101111:  output_data_o =  {{47{input_data_i[63]}},input_data_i[63:47]};
        6'b110000:  output_data_o =  {{48{input_data_i[63]}},input_data_i[63:48]};

        6'b110001:  output_data_o =  {{49{input_data_i[63]}},input_data_i[63:49]};
        6'b110010:  output_data_o =  {{50{input_data_i[63]}},input_data_i[63:50]};
        6'b110011:  output_data_o =  {{51{input_data_i[63]}},input_data_i[63:51]};
        6'b110100:  output_data_o =  {{52{input_data_i[63]}},input_data_i[63:52]};
        6'b110101:  output_data_o =  {{53{input_data_i[63]}},input_data_i[63:53]};
        6'b110110:  output_data_o =  {{54{input_data_i[63]}},input_data_i[63:54]};
        6'b110111:  output_data_o =  {{55{input_data_i[63]}},input_data_i[63:55]};
        6'b111000:  output_data_o =  {{56{input_data_i[63]}},input_data_i[63:56]};

        6'b111001:  output_data_o =  {{57{input_data_i[63]}},input_data_i[63:57]};
        6'b111010:  output_data_o =  {{58{input_data_i[63]}},input_data_i[63:58]};
        6'b111011:  output_data_o =  {{59{input_data_i[63]}},input_data_i[63:59]};
        6'b111100:  output_data_o =  {{60{input_data_i[63]}},input_data_i[63:60]};
        6'b111101:  output_data_o =  {{61{input_data_i[63]}},input_data_i[63:61]};
        6'b111110:  output_data_o =  {{62{input_data_i[63]}},input_data_i[63:62]};
        6'b111111:  output_data_o =  {{63{input_data_i[63]}},input_data_i[63]};

        default:    output_data_o = `ZERO_DATA;
    endcase
end
endmodule

//-----------------------------------------------------------------------------------------------
// END Functional Unit - Shift_Word_Right_Arithmetic
//-----------------------------------------------------------------------------------------------
`default_nettype wire

