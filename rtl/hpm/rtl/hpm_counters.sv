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
    input   logic           branch_miss_i,
    input   logic           is_branch_i,
    input   logic           branch_taken_i,
    input   logic           exe_store_i,
    input   logic           exe_load_i,
    input   logic           icache_req_i,
    input   logic           icache_kill_i,
    input   logic           stall_if_i,
    input   logic           stall_id_i,
    input   logic           stall_rr_i,
    input   logic           stall_exe_i,
    input   logic           stall_wb_i,
    input   logic           buffer_miss_i,
    input   logic           imiss_kill_i,
    input   logic           icache_bussy_i,
    input   logic           imiss_time_i,
    input   logic           load_store_i,
    input   logic           data_depend_i,
    input   logic           struct_depend_i,
    input   logic           grad_list_full_i,
    input   logic           free_list_empty_i,
    input   logic           itlb_access_i,
    input   logic           itlb_miss_i,
    input   logic           dtlb_access_i,
    input   logic           dtlb_miss_i,
    input   logic           ptw_hit_i,
    input   logic           ptw_miss_i,
    input   logic           itlb_miss_cycle_i
);
    localparam HPM_NUM_COUNTERS = 29; // TODO: Constant
    localparam HPM_NUM_EVENTS   = 28; // TODO: Constant

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
                1:  events[i] = branch_miss_i;
                2:  events[i] = is_branch_i;
                3:  events[i] = branch_taken_i;
                4:  events[i] = exe_store_i;
                5:  events[i] = exe_load_i;
                6:  events[i] = icache_req_i;
                7:  events[i] = icache_kill_i;
                8:  events[i] = stall_if_i;
                9:  events[i] = stall_id_i;
                10: events[i] = stall_rr_i;
                11: events[i] = stall_exe_i;
                12: events[i] = stall_wb_i;
                13: events[i] = buffer_miss_i;
                14: events[i] = imiss_kill_i;
                15: events[i] = icache_bussy_i;
                16: events[i] = imiss_time_i;
                17: events[i] = load_store_i;
                18: events[i] = data_depend_i;
                19: events[i] = struct_depend_i;
                20: events[i] = grad_list_full_i;
                21: events[i] = free_list_empty_i;
                22: events[i] = itlb_access_i;
                23: events[i] = itlb_miss_i;
                24: events[i] = dtlb_access_i;
                25: events[i] = dtlb_miss_i;
                26: events[i] = ptw_hit_i;
                27: events[i] = ptw_miss_i;
                28: events[i] = itlb_miss_cycle_i;
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
