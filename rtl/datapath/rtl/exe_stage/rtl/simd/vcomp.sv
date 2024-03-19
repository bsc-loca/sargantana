/* -----------------------------------------------
 * Project Name   : DRAC
 * File           : vcomp.sv
 * Organization   : Barcelona Supercomputing Center
 * Author(s)      : Gerard Candón Arenas
 * Email(s)       : gerard.candon@bsc.es
 * -----------------------------------------------
 * Revision History
 *  Revision   | Author    | Description
 *  0.1        | Gerard C. | 
 * -----------------------------------------------
 */

module vcomp 
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input instr_type_t          instr_type_i,   // Instruction type
    input sew_t                 sew_i,          // Element width
    input bus64_t               data_vs1_i,     // 64-bit source operand 1
    input bus64_t               data_vs2_i,     // 64-bit source operand 2
    output bus64_t              data_vd_o       // 64-bit result
);

//This module performs vector comparison operations. The strategy is to use as
//little comparations as possible (in this case, just >(signed) and == with byte
//granularity).

logic [7:0] use_sign_bit;
logic is_signed;
logic is_max;
//logic is_min;
logic is_seq;
logic is_sne;
logic is_slt;
logic is_sle;
logic is_sgt;
logic [7:0] is_greater;
logic [7:0] is_equal;
bus64_t data_a, data_b;

//vcnt performs the same operations as vmseq. The equal counts is performed
//outside the FUs.
assign is_signed = ((instr_type_i == VMAX)   || (instr_type_i == VMIN ) || 
                    (instr_type_i == VMSLT)  || (instr_type_i == VMSLE) || (instr_type_i == VMSGT)) ? 1'b1 : 1'b0;
assign is_max =    ((instr_type_i == VMAX)   || (instr_type_i == VMAXU))    ? 1'b1 : 1'b0;
//assign is_min =    ((instr_type_i == VMIN)   || (instr_type_i == VMINU))    ? 1'b1 : 1'b0;
assign is_seq =    ((instr_type_i == VMSEQ)  || (instr_type_i == VCNT))     ? 1'b1 : 1'b0;
assign is_sne =    ((instr_type_i == VMSNE))                                ? 1'b1 : 1'b0;
assign is_slt =    ((instr_type_i == VMSLTU) || (instr_type_i == VMSLT))    ? 1'b1 : 1'b0;
assign is_sle =    ((instr_type_i == VMSLEU) || (instr_type_i == VMSLE))    ? 1'b1 : 1'b0;
assign is_sgt =    ((instr_type_i == VMSGTU) || (instr_type_i == VMSGT))    ? 1'b1 : 1'b0;

always_comb begin
    for (int i = 0; i<8; ++i) begin
        //If the operation is signed and the byte element of a source operand uses their sign bit,
        //we append the most significant bit of the element to itself.
        //Otherwise, we append a 0, to ensure an unsigned comparison.
        is_greater[i] = $signed({is_signed & use_sign_bit[i] & data_vs1_i[(i*8)+7], data_vs1_i[(i*8)+:8]}) >
                        $signed({is_signed & use_sign_bit[i] & data_vs2_i[(i*8)+7], data_vs2_i[(i*8)+:8]});
        is_equal[i] = data_vs1_i[(i*8)+:8] == data_vs2_i[(i*8)+:8];
    end

    if (is_max) begin
        data_a = data_vs1_i;
        data_b = data_vs2_i;
    end else begin
        //To perform a min operation we just swap the source operands
        data_a = data_vs2_i;
        data_b = data_vs1_i;
    end
    
    // "use_sign_bit[i]" determines if byte i of the source operand is the
    // most significant byte of a vector element. On signed operations, the
    // most significant byte has to perform a signed comparison, while less
    // significant bytes must perform an unsigned comparison.
    //
    // To determine if an element is greater than another, using only byte
    // comparators, we compare their most significant bytes. Let's supose
    // SEW=32.
    // If a[3] > b[3], then a > b. 
    // Otherwise, if a[3] == b[3] and a[2] > b[2], then a > b.
    // Otherwise, if a[3:2] == b[3:2] and a[1] > b[1], then a > b.
    // Otherwise, if a[3:1] == b[3:1] and a[0] > b[0], then a > b.
    // Otherwise, a <= b.
    data_vd_o = '1;
    case (sew_i)
        SEW_8: begin
            for (int i = 0; i<8; ++i) begin
                //Determine most significant byte
                use_sign_bit[i] = 1'b1;

                //VMSEQ
                if (is_seq) begin
                    data_vd_o[i] = is_equal[i];
                //VMSNE
                end else if (is_sne) begin
                    data_vd_o[i] = ~is_equal[i];
                //VMSLT
                end else if (is_slt) begin
                    data_vd_o[i] = is_greater[i];
                //VMSLE
                end else if (is_sle) begin
                    data_vd_o[i] = is_greater[i] | is_equal[i];
                //VMSGT
                end else if (is_sgt) begin
                    data_vd_o[i] = ~(is_greater[i] | is_equal[i]);

                //VMAX and VMIN
                end else if (is_greater[i]) begin
                    data_vd_o[(i*8)+:8] = data_a[(i*8)+:8];
                end else begin
                    data_vd_o[(i*8)+:8] = data_b[(i*8)+:8];
                end
            end
            if (is_seq | is_sne | is_slt | is_sle | is_sgt) begin
                data_vd_o[63:8] = '1;
            end
        end
        SEW_16: begin
            for (int i = 0; i<4; ++i) begin
                //Determine most significant byte
                use_sign_bit[i*2] = 1'b0;
                use_sign_bit[(i*2)+1] = 1'b1;

                //VMSEQ
                if (is_seq) begin
                    data_vd_o[i] = &(is_equal[(2*i)+:2]);
                end else if (is_sne) begin
                    data_vd_o[i] = ~(&(is_equal[(2*i)+:2]));
                //VMSLT
                end else if (is_slt) begin
                    data_vd_o[i] = is_greater[(2*i)+1] | (is_equal[(2*i)+1] & is_greater[2*i]);
                //VMSLE
                end else if (is_sle) begin
                    data_vd_o[i] = ((&is_equal[(2*i)+:2]) | (is_greater[(2*i)+1] |
                                    (is_equal[(2*i)+1] & is_greater[2*i])));
                //VMSGT
                end else if (is_sgt) begin
                    data_vd_o[i] = ~((&is_equal[(2*i)+:2]) | (is_greater[(2*i)+1] |
                                     (is_equal[(2*i)+1] & is_greater[2*i])));

                //VMAX and VMIN
                end else if (is_greater[(2*i)+1] |
                            (is_equal[(2*i)+1] & is_greater[2*i])) begin
                    data_vd_o[(i*16)+:16] = data_a[(i*16)+:16];
                end else begin
                    data_vd_o[(i*16)+:16] = data_b[(i*16)+:16];
                end
            end
            if (is_seq | is_sne | is_slt | is_sle | is_sgt) begin
                data_vd_o[63:4] = '1;
            end
        end
        SEW_32: begin
            for (int i = 0; i<2; ++i) begin
                //Determine most significant byte
                use_sign_bit[i*4] = 1'b0;
                use_sign_bit[(i*4)+1] = 1'b0;
                use_sign_bit[(i*4)+2] = 1'b0;
                use_sign_bit[(i*4)+3] = 1'b1;

                //VMSEQ
                if (is_seq) begin
                    data_vd_o[i] = &(is_equal[(4*i)+:4]);
                end else if (is_sne) begin
                    data_vd_o[i] = ~(&(is_equal[(4*i)+:4]));
                //VMSLT
                end else if (is_slt) begin
                    data_vd_o[i] =  (is_greater[(4*i)+3] |
                                    (is_equal[(4*i)+3] & (is_greater[(4*i)+2] |
                                    (is_equal[(4*i)+2] & (is_greater[(4*i)+1] |
                                    (is_equal[(4*i)+1] & (is_greater[4*i])))))));
                //VMSLE
                end else if (is_sle) begin
                    data_vd_o[i] =  ((&is_equal[(4*i)+:4]) | (is_greater[(4*i)+3] |
                                    (is_equal[(4*i)+3] & (is_greater[(4*i)+2] |
                                    (is_equal[(4*i)+2] & (is_greater[(4*i)+1] |
                                    (is_equal[(4*i)+1] & (is_greater[4*i]))))))));
                //VMSGT
                end else if (is_sgt) begin
                    data_vd_o[i] =  ~((&is_equal[(4*i)+:4]) | (is_greater[(4*i)+3] |
                                     (is_equal[(4*i)+3] & (is_greater[(4*i)+2] |
                                     (is_equal[(4*i)+2] & (is_greater[(4*i)+1] |
                                     (is_equal[(4*i)+1] & (is_greater[4*i]))))))));

                //VMAX and VMIN
                end else if (is_greater[(4*i)+3] |
                            (is_equal[(4*i)+3] & (is_greater[(4*i)+2] |
                            (is_equal[(4*i)+2] & (is_greater[(4*i)+1] |
                            (is_equal[(4*i)+1] & (is_greater[4*i]))))))) begin
                    data_vd_o[(i*32)+:32] = data_a[(i*32)+:32];
                end else begin
                    data_vd_o[(i*32)+:32] = data_b[(i*32)+:32];
                end
            end
            if (is_seq | is_sne | is_slt | is_sle | is_sgt) begin
                data_vd_o[63:2] = '1;
            end
        end
        SEW_64: begin
            //Determine most significant byte
            use_sign_bit[6:0] = 7'b0;
            use_sign_bit[7] = 1'b1;

            //VMSEQ
            if (is_seq) begin
                data_vd_o = &(is_equal);
            end else if (is_sne) begin
                data_vd_o = ~(&(is_equal));
            //VMSLT
            end else if (is_slt) begin
                data_vd_o =     (is_greater[7] |
                                (is_equal[7] & (is_greater[6] |
                                (is_equal[6] & (is_greater[5] |
                                (is_equal[5] & (is_greater[4] |
                                (is_equal[4] & (is_greater[3] |
                                (is_equal[3] & (is_greater[2] |
                                (is_equal[2] & (is_greater[1] |
                                (is_equal[1] & (is_greater[0])))))))))))))));
            //VMSLE
            end else if (is_sle) begin
                data_vd_o = ((&is_equal) | (is_greater[7] |
                            (is_equal[7] & (is_greater[6] |
                            (is_equal[6] & (is_greater[5] |
                            (is_equal[5] & (is_greater[4] |
                            (is_equal[4] & (is_greater[3] |
                            (is_equal[3] & (is_greater[2] |
                            (is_equal[2] & (is_greater[1] |
                            (is_equal[1] & (is_greater[0]))))))))))))))));
            //VMSGT
            end else if (is_sgt) begin
                data_vd_o = ~((&is_equal) | (is_greater[7] |
                             (is_equal[7] & (is_greater[6] |
                             (is_equal[6] & (is_greater[5] |
                             (is_equal[5] & (is_greater[4] |
                             (is_equal[4] & (is_greater[3] |
                             (is_equal[3] & (is_greater[2] |
                             (is_equal[2] & (is_greater[1] |
                             (is_equal[1] & (is_greater[0]))))))))))))))));

            //VMAX and VMIN
            end else if (is_greater[7] |
               (is_equal[7] & (is_greater[6] |
               (is_equal[6] & (is_greater[5] |
               (is_equal[5] & (is_greater[4] |
               (is_equal[4] & (is_greater[3] |
               (is_equal[3] & (is_greater[2] |
               (is_equal[2] & (is_greater[1] |
               (is_equal[1] & (is_greater[0]))))))))))))))) begin
                data_vd_o = data_a;
            end else begin
                data_vd_o = data_b;
            end
            if (is_seq | is_sne | is_slt | is_sle | is_sgt) begin
                data_vd_o[63:1] = '1;
            end
        end 
    endcase
end
endmodule
