module realigner
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input logic clk_i,
    input logic rstn_i,
    input logic flush_i,

    // From I$
    input logic icache_valid_i,
    input bus32_t data_i,

    // From F1
    input logic f1_valid_i,
    input addrPC_t addr_i,

    // From F2
    input logic branch_predicted_i,

    // To D
    output logic valid_o,
    output addrPC_t pc_o,
    output addrPC_t next_pc_o,
    output bus32_t data_o,

    // To CU
    output logic keep_fetch_o
);

    logic is_compressed[1:0]; // 1 -> bits 31..16; 0 -> bits 15..0

    always_comb begin
        for (int i = 0; i < 2; ++i) begin
            is_compressed[i] = !(&data_i[16*i +: 2]);
        end
    end

    /*
     * --------------------------------------------------------------------------------------------
     * Storage logic for unaligned 32-bit instructions
     * --------------------------------------------------------------------------------------------
     */

    logic unaligned_d, unaligned_q;
    logic [15:0] unaligned_data_d, unaligned_data_q;
    addrPC_t unaligned_addr_d, unaligned_addr_q;

    addrPC_t current_pc;

    // If we have unaligned data stored it means that we have data prom the
    // previous fetch waiting to complete the instruction
    assign current_pc = (unaligned_q) ? unaligned_addr_q : addr_i;

    always_comb begin
        valid_o = ((f1_valid_i & icache_valid_i) & (
                // aligned
                !(|current_pc[1:0]) | // if it is aligned and we have all inputs valid we will always have a valid instruction
                // unaligned
                is_compressed[1] | // if it is not aligned but we have a compressed it will always be valid
                unaligned_q) // if it is not aligned and is not a compressed we need to check if we have a previous data stored
            || (unaligned_q && !(&unaligned_data_q[1:0]))
        );

        data_o = !(|current_pc[1:0]) ? 
                        ((is_compressed[0]) ? {16'b0, data_i[15:0]} :
                                              data_i) :
                        ((unaligned_q) ? ((&unaligned_data_q[1:0]) ? {data_i[15:0], unaligned_data_q} :
                                                                     {16'b0, unaligned_data_q}) :
                                         {16'b0, data_i[31:16]});

        pc_o = current_pc;

        if (unaligned_q) begin
            if (&unaligned_data_q[1:0]) begin
                next_pc_o = current_pc + 64'h04;
            end else begin
                next_pc_o = current_pc + 64'h02;
            end
        end else begin
            if (is_compressed[current_pc[1]]) begin
                next_pc_o = current_pc + 64'h02;
            end else begin
                next_pc_o = current_pc + 64'h04;
            end
        end

        keep_fetch_o = (f1_valid_i & icache_valid_i) & 
                            ((!(|current_pc[1:0]) & is_compressed[0] & is_compressed[1]) ||
                            (unaligned_d & !(&unaligned_data_d[1:0])))
                       ; 

        unaligned_d = ((f1_valid_i && icache_valid_i) ?
                            ((current_pc[1]) ?
                                ((unaligned_q) ? (&unaligned_data_q[1:0]) :
                                                 (!is_compressed[1])) :
                                is_compressed[0]) :
                            (unaligned_q & !valid_o)) & !branch_predicted_i;

        unaligned_addr_d = {addr_i[riscv_pkg::XLEN: 2], 2'b10};

        unaligned_data_d = data_i[31:16];
    end

    always_ff @(posedge clk_i, negedge rstn_i) begin
        if (!rstn_i) begin
            unaligned_q <= 1'b0;
            unaligned_addr_q <= '0;
            unaligned_data_q <= '0;
        end else begin
            if (flush_i) begin
                unaligned_q <= 1'b0;
            end else if ((f1_valid_i & icache_valid_i) || (unaligned_q && valid_o)) begin
                unaligned_q <= unaligned_d;
                unaligned_addr_q <= unaligned_addr_d;
                unaligned_data_q <= unaligned_data_d;
            end
        end
    end

    /*
     * --------------------------------------------------------------------------------------------
     * Output logic
     * --------------------------------------------------------------------------------------------
     */

    always_comb begin
    end

endmodule
