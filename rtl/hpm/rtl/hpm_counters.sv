/* -----------------------------------------------
* Project Name   : DRAC
* File           : hpm.sv
* Organization   : Barcelona Supercomputing Center
* Author(s)      : Oscar Lostes Cazorla
* Email(s)       : oscar.lostes@bsc.es
* References     :
* -----------------------------------------------
* Revision History
*  Revision   | Author     | Commit | Description
*  0.1        | Oscar.LC   |
* -----------------------------------------------
*/

module hpm_counters
    import drac_pkg::*;
    import riscv_pkg::*;
(
    input   logic           clk_i,
    input   logic           rstn_i,

    // Access interface
    input   logic [CSR_ADDR_SIZE-1:0]   addr_i,
    input   logic                       we_i,
    input   bus64_t                     data_i,
    output  bus64_t                     data_o,

    // Events
    input   logic           branch_miss,
    input   logic           is_branch,
    input   logic           branch_taken,
    input   logic           exe_store,
    input   logic           exe_load,
    input   logic           icache_req,
    input   logic           icache_kill,
    input   logic           stall_if,
    input   logic           stall_id,
    input   logic           stall_rr,
    input   logic           stall_exe,
    input   logic           stall_wb,
    input   logic           buffer_miss,
    input   logic           imiss_kill,
    input   logic           icache_bussy,
    input   logic           imiss_time,
    input   logic           load_store,
    input   logic           data_depend,
    input   logic           struct_depend,
    input   logic           grad_list_full,
    input   logic           free_list_empty
);
    localparam HPM_NUM_COUNTERS = 29; // TODO: Constant
    localparam HPM_NUM_EVENTS   = 21; // TODO: Constant

    localparam HPM_NUM_EVENTS_BITS   = $clog2(HPM_NUM_EVENTS);
    localparam HPM_NUM_COUNTERS_BITS = $clog2(HPM_NUM_COUNTERS);

    // HPM Counters
    bus64_t counter_d[HPM_NUM_COUNTERS:1];
    bus64_t counter_q[HPM_NUM_COUNTERS:1];

    logic events[HPM_NUM_COUNTERS:1];

    // Event selector
    logic [HPM_NUM_EVENTS_BITS-1:0] mhpmevent_d[HPM_NUM_COUNTERS:1];
    logic [HPM_NUM_EVENTS_BITS-1:0] mhpmevent_q[HPM_NUM_COUNTERS:1];

    // TODO: mhpminhibit

    always_comb begin
        events[HPM_NUM_COUNTERS:1] = '{default:0};

        // Check if the selected event is triggered for a given counter
        for (int unsigned i = 1; i <= HPM_NUM_COUNTERS; i++) begin
            case (mhpmevent_q[i])
                1:  events[i] = branch_miss;
                2:  events[i] = is_branch;
                3:  events[i] = branch_taken;
                4:  events[i] = exe_store;
                5:  events[i] = exe_load;
                6:  events[i] = icache_req;
                7:  events[i] = icache_kill;
                8:  events[i] = stall_if;
                9:  events[i] = stall_id;
                10: events[i] = stall_rr;
                11: events[i] = stall_exe;
                12: events[i] = stall_wb;
                13: events[i] = buffer_miss;
                14: events[i] = imiss_kill;
                15: events[i] = icache_bussy;
                16: events[i] = imiss_time;
                17: events[i] = load_store;
                18: events[i] = data_depend;
                19: events[i] = struct_depend;
                20: events[i] = grad_list_full;
                21: events[i] = free_list_empty;
                default: events[i] = 0;
            endcase
        end
    end


    always_comb begin
        counter_d = counter_q;
        data_o = 'b0;
        mhpmevent_d = mhpmevent_q;

        for(int unsigned i = 1; i <= HPM_NUM_COUNTERS; i++) begin
            if (mhpmevent_q[i] == 0) begin
                counter_d[i] = 'b0;
            end else if (!we_i) begin
                counter_d[i] = counter_q[i] + events[i];
            end
        end

        //Read
        unique case (addr_i)
            CSR_MHPM_COUNTER_3,
            CSR_MHPM_COUNTER_4,
            CSR_MHPM_COUNTER_5,
            CSR_MHPM_COUNTER_6,
            CSR_MHPM_COUNTER_7,
            CSR_MHPM_COUNTER_8,
            CSR_MHPM_COUNTER_9,
            CSR_MHPM_COUNTER_10,
            CSR_MHPM_COUNTER_11,
            CSR_MHPM_COUNTER_12,
            CSR_MHPM_COUNTER_13,
            CSR_MHPM_COUNTER_14,
            CSR_MHPM_COUNTER_15,
            CSR_MHPM_COUNTER_16,
            CSR_MHPM_COUNTER_17,
            CSR_MHPM_COUNTER_18,
            CSR_MHPM_COUNTER_19,
            CSR_MHPM_COUNTER_20,
            CSR_MHPM_COUNTER_21,
            CSR_MHPM_COUNTER_22,
            CSR_MHPM_COUNTER_23,
            CSR_MHPM_COUNTER_24,
            CSR_MHPM_COUNTER_25,
            CSR_MHPM_COUNTER_26,
            CSR_MHPM_COUNTER_27,
            CSR_MHPM_COUNTER_28,
            CSR_MHPM_COUNTER_29,
            CSR_MHPM_COUNTER_30,
            CSR_MHPM_COUNTER_31: begin
                if (we_i) begin
                    counter_d[addr_i-CSR_MHPM_COUNTER_3 + 1] = data_i;
                end else begin
                    data_o = counter_q[addr_i-CSR_MHPM_COUNTER_3 + 1];
                end
            end

            CSR_MHPM_EVENT_3,
            CSR_MHPM_EVENT_4,
            CSR_MHPM_EVENT_5,
            CSR_MHPM_EVENT_6,
            CSR_MHPM_EVENT_7,
            CSR_MHPM_EVENT_8,
            CSR_MHPM_EVENT_9,
            CSR_MHPM_EVENT_10,
            CSR_MHPM_EVENT_11,
            CSR_MHPM_EVENT_12,
            CSR_MHPM_EVENT_13,
            CSR_MHPM_EVENT_14,
            CSR_MHPM_EVENT_15,
            CSR_MHPM_EVENT_16,
            CSR_MHPM_EVENT_17,
            CSR_MHPM_EVENT_18,
            CSR_MHPM_EVENT_19,
            CSR_MHPM_EVENT_20,
            CSR_MHPM_EVENT_21,
            CSR_MHPM_EVENT_22,
            CSR_MHPM_EVENT_23,
            CSR_MHPM_EVENT_24,
            CSR_MHPM_EVENT_25,
            CSR_MHPM_EVENT_26,
            CSR_MHPM_EVENT_27,
            CSR_MHPM_EVENT_28,
            CSR_MHPM_EVENT_29,
            CSR_MHPM_EVENT_30,
            CSR_MHPM_EVENT_31: begin
                if (we_i) begin
                    mhpmevent_d[addr_i-CSR_MHPM_EVENT_3 + 1] = data_i[HPM_NUM_EVENTS_BITS-1:0];
                end else begin
                    data_o[HPM_NUM_EVENTS_BITS-1:0] = mhpmevent_q[addr_i-CSR_MHPM_EVENT_3 + 1];
                end
            end

            default: data_o =  1'b0;
        endcase
    end

    //Registers
    always_ff @(posedge clk_i or negedge rstn_i) begin
        if (!rstn_i) begin
            counter_q   <= '{default:0};
            mhpmevent_q <= '{default:0};
        end else begin
            counter_q   <= counter_d;
            mhpmevent_q <= mhpmevent_d;
        end
    end

endmodule
