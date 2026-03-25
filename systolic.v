`timescale 1ns/1ps
`include "array_2x2.v"

module systolic #(
    parameter Data_W = 4,
    parameter Psum_W = 9
)(
    input                   clk,
    input                   rst_n,
    input                   in_valid,

    input      [Data_W-1:0] a11,
    input      [Data_W-1:0] a12,
    input      [Data_W-1:0] a21,
    input      [Data_W-1:0] a22,

    input      [Data_W-1:0] b11,
    input      [Data_W-1:0] b12,
    input      [Data_W-1:0] b21,
    input      [Data_W-1:0] b22,

    output reg [Psum_W-1:0] c11,
    output reg [Psum_W-1:0] c12,
    output reg [Psum_W-1:0] c21,
    output reg [Psum_W-1:0] c22,
    output reg              out_valid
);

    localparam ST_IDLE  = 3'd0;
    localparam ST_PRE0  = 3'd1;
    localparam ST_PRE1  = 3'd2;
    localparam ST_RUN0  = 3'd3;
    localparam ST_RUN1  = 3'd4;
    localparam ST_RUN2  = 3'd5;
    localparam ST_DRAIN = 3'd6;

    reg [2:0] state;

    reg                 cur_valid;
    reg [Data_W-1:0]    cur_a11, cur_a12, cur_a21, cur_a22;
    reg [Data_W-1:0]    cur_b11, cur_b12, cur_b21, cur_b22;

    reg                 nxt_valid;
    reg                 nxt_loaded;
    reg [1:0]           nxt_prog;
    reg [Data_W-1:0]    nxt_a11, nxt_a12, nxt_a21, nxt_a22;
    reg [Data_W-1:0]    nxt_b11, nxt_b12, nxt_b21, nxt_b22;

    reg                 active_bank;
    wire                inactive_bank;

    assign inactive_bank = ~active_bank;

    reg  [Data_W-1:0]   arr_a_top;      // input into PE11 from west
    reg  [Data_W-1:0]   arr_a_bot;      // input into PE21 from west
    reg  [Data_W-1:0]   arr_b_col0;     // input into PE11 from north
    reg  [Data_W-1:0]   arr_b_col1;     // input into PE12 from north

    // bit order: {PE22, PE21, PE12, PE11}
    reg  [3:0]          arr_load_en;    // 0: keep, 1: load
    reg  [3:0]          arr_load_sel;   // 0: load to buf0, 1: load to buf1
    reg  [3:0]          arr_act_sel;    // 0: compute with buf0, 1: compute with buf1   
    reg                 arr_clear;
    reg                 arr_pe_en;

    wire [Psum_W-1:0]   arr_c_row0;
    wire [Psum_W-1:0]   arr_c_row1;

    reg                 do_nxt_p0;
    reg                 do_nxt_p1;
    reg                 do_nxt_p2;
    reg                 do_overlap_run0;

    reg                 pending_c22;
    reg                 drain_has_next;

    array_2x2 #(
        .Data_W (Data_W),
        .Psum_W (Psum_W)
    ) u_array_2x2 (
        .clk      (clk),
        .rst_n    (rst_n),

        .a11_in   (arr_a_top),
        .a21_in   (arr_a_bot),

        .b11_in   (arr_b_col0),
        .b12_in   (arr_b_col1),

        .load_en  (arr_load_en),
        .load_sel (arr_load_sel),
        .act_sel  (arr_act_sel),

        .clear    (arr_clear),
        .pe_en    (arr_pe_en),

        .c21_out  (arr_c_row0),
        .c22_out  (arr_c_row1)
    );

    // overlap scheduling
    always @(*) begin
        do_nxt_p0       = 1'b0;
        do_nxt_p1       = 1'b0;
        do_nxt_p2       = 1'b0;
        do_overlap_run0 = 1'b0;

        case (state)
            ST_RUN0: begin
                if (nxt_valid && !nxt_loaded && (nxt_prog == 2'd0))
                    do_nxt_p0 = 1'b1;
            end

            ST_RUN1: begin
                if (nxt_valid && !nxt_loaded && (nxt_prog == 2'd1))
                    do_nxt_p1 = 1'b1;
            end

            ST_RUN2: begin
                if (nxt_valid && !nxt_loaded && (nxt_prog == 2'd2)) begin
                    do_nxt_p2       = 1'b1;
                    do_overlap_run0 = 1'b1;
                end
            end

            default: begin
            end
        endcase
    end

    // combinational scheduler
    always @(*) begin
        arr_a_top    = {Data_W{1'b0}};
        arr_a_bot    = {Data_W{1'b0}};
        arr_b_col0   = {Data_W{1'b0}};
        arr_b_col1   = {Data_W{1'b0}};

        arr_load_en  = 4'b0000;
        arr_load_sel = 4'b0000;
        arr_act_sel  = {4{active_bank}};

        arr_clear    = 1'b0;
        arr_pe_en    = 1'b0;

        case (state)
            ST_IDLE: begin      // 0
                arr_clear = 1'b0;
            end

            ST_PRE0: begin      // 1
                // col0 -> b21, only PE11 loads current bank
                arr_clear    = 1'b1;
                arr_b_col0   = cur_b21;
                arr_load_en  = 4'b0001;
                arr_load_sel = {1'b0, 1'b0, 1'b0, active_bank};
            end

            ST_PRE1: begin      // 2
                // col0 -> b11, col1 -> b22
                // PE11 / PE12 / PE21 load current bank
                arr_clear    = 1'b1;
                arr_b_col0   = cur_b11;
                arr_b_col1   = cur_b22;
                arr_load_en  = 4'b0111;
                arr_load_sel = {1'b0, active_bank, active_bank, active_bank};
            end

            ST_RUN0: begin      // 3
                arr_pe_en   = 1'b1;
                arr_a_top   = cur_a11;
                arr_a_bot   = {Data_W{1'b0}};
                arr_b_col1  = cur_b12;

                // only PE11 is valid for current op in this cycle
                arr_act_sel = {inactive_bank, inactive_bank, inactive_bank, active_bank};

                if (do_nxt_p0) begin
                    // PE22 / PE12 load current bank
                    // PE11 loads nxt_b21 into inactive bank
                    arr_b_col0   = nxt_b21;
                    arr_load_en  = 4'b1011;
                    arr_load_sel = {active_bank, 1'b0, active_bank, inactive_bank};
                end
                else begin
                    arr_load_en  = 4'b1010;
                    arr_load_sel = {active_bank, 1'b0, active_bank, 1'b0};
                end
            end

            ST_RUN1: begin      // 4, 6
                arr_pe_en   = 1'b1;
                arr_a_top   = cur_a21;
                arr_a_bot   = cur_a12;

                // PE22 still belongs to previous-right-column timing
                // PE21 / PE12 / PE11 belong to current running op
                arr_act_sel = {inactive_bank, active_bank, active_bank, active_bank};

                if (do_nxt_p1) begin
                    // preload next step1 into inactive bank
                    arr_b_col0   = nxt_b11;
                    arr_b_col1   = nxt_b22;
                    arr_load_en  = 4'b0111;
                    arr_load_sel = {1'b0, inactive_bank, inactive_bank, inactive_bank};
                end
            end

            ST_RUN2: begin      // 5, 7
                arr_pe_en = 1'b1;

                if (do_overlap_run0) begin
                    // current op final wave on bottom row
                    // next op first wave on PE11 only
                    arr_a_top   = nxt_a11;
                    arr_a_bot   = cur_a22;
                    arr_act_sel = {active_bank, active_bank, active_bank, inactive_bank};

                    // preload next step2 into inactive bank: PE22 / PE12
                    arr_b_col1   = nxt_b12;
                    arr_load_en  = 4'b1010;
                    arr_load_sel = {inactive_bank, 1'b0, inactive_bank, 1'b0};
                end
                else begin
                    // no overlap, still finish current right-column timing
                    arr_a_top   = {Data_W{1'b0}};
                    arr_a_bot   = cur_a22;
                    arr_act_sel = {active_bank, active_bank, active_bank, inactive_bank};
                end
            end

            ST_DRAIN: begin     // 8
                // one extra cycle to flush final PE22 output
                arr_pe_en   = 1'b1;
                arr_a_top   = {Data_W{1'b0}};
                arr_a_bot   = {Data_W{1'b0}};
                arr_act_sel = {active_bank, inactive_bank, inactive_bank, inactive_bank};
            end

            default: begin
                arr_clear = 1'b0;
            end
        endcase
    end

    // sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_IDLE;

            cur_valid      <= 1'b0;
            nxt_valid      <= 1'b0;
            nxt_loaded     <= 1'b0;
            nxt_prog       <= 2'd0;

            active_bank    <= 1'b0;

            pending_c22    <= 1'b0;
            drain_has_next <= 1'b0;

            c11            <= {Psum_W{1'b0}};
            c12            <= {Psum_W{1'b0}};
            c21            <= {Psum_W{1'b0}};
            c22            <= {Psum_W{1'b0}};
            out_valid      <= 1'b0;

            cur_a11 <= 0; cur_a12 <= 0; cur_a21 <= 0; cur_a22 <= 0;
            cur_b11 <= 0; cur_b12 <= 0; cur_b21 <= 0; cur_b22 <= 0;

            nxt_a11 <= 0; nxt_a12 <= 0; nxt_a21 <= 0; nxt_a22 <= 0;
            nxt_b11 <= 0; nxt_b12 <= 0; nxt_b21 <= 0; nxt_b22 <= 0;
        end
        else begin
            out_valid <= 1'b0;

            // capture outputs at their real timing points
            if (state == ST_RUN1) begin
                c21 <= arr_c_row0;
            end

            if (state == ST_RUN2) begin
                c22 <= arr_c_row1;
                c21 <= arr_c_row0;
            end

            if (pending_c22 || (state == ST_DRAIN)) begin
                c21 <= arr_c_row0;
                c22 <= arr_c_row1;
                out_valid <= 1'b1;
                pending_c22 <= 1'b0;
            end

            if (state == ST_IDLE && out_valid) begin
                c22 <= arr_c_row1;
            end

            // accept input ops
            if (in_valid) begin
                if (!cur_valid && state == ST_IDLE) begin
                    cur_valid <= 1'b1;

                    cur_a11 <= a11; cur_a12 <= a12;
                    cur_a21 <= a21; cur_a22 <= a22;

                    cur_b11 <= b11; cur_b12 <= b12;
                    cur_b21 <= b21; cur_b22 <= b22;
                end
                else if (!nxt_valid) begin
                    nxt_valid  <= 1'b1;
                    nxt_loaded <= 1'b0;
                    nxt_prog   <= 2'd0;

                    nxt_a11 <= a11; nxt_a12 <= a12;
                    nxt_a21 <= a21; nxt_a22 <= a22;

                    nxt_b11 <= b11; nxt_b12 <= b12;
                    nxt_b21 <= b21; nxt_b22 <= b22;
                end
            end

            if (do_nxt_p0) begin
                nxt_prog <= 2'd1;
            end
            else if (do_nxt_p1) begin
                nxt_prog <= 2'd2;
            end
            else if (do_nxt_p2) begin
                nxt_prog   <= 2'd3;
                nxt_loaded <= 1'b1;
            end

            case (state)
                ST_IDLE: begin
                    if (cur_valid || in_valid)
                        state <= ST_PRE0;
                end

                ST_PRE0: begin
                    state <= ST_PRE1;
                end

                ST_PRE1: begin
                    state <= ST_RUN0;
                end

                ST_RUN0: begin
                    state <= ST_RUN1;
                end

                ST_RUN1: begin
                    state <= ST_RUN2;
                end

                ST_RUN2: begin
                    if (do_overlap_run0) begin
                        // current c22 will appear at next cycle
                        pending_c22 <= 1'b1;

                        cur_valid <= 1'b1;

                        cur_a11 <= nxt_a11; cur_a12 <= nxt_a12;
                        cur_a21 <= nxt_a21; cur_a22 <= nxt_a22;

                        cur_b11 <= nxt_b11; cur_b12 <= nxt_b12;
                        cur_b21 <= nxt_b21; cur_b22 <= nxt_b22;

                        nxt_valid  <= 1'b0;
                        nxt_loaded <= 1'b0;
                        nxt_prog   <= 2'd0;

                        active_bank <= ~active_bank;
                        state <= ST_RUN1;
                    end
                    else begin
                        // whether there is a queued next op or not,
                        // final PE22 needs one drain cycle first
                        drain_has_next <= nxt_valid;
                        state <= ST_DRAIN;
                    end
                end

                ST_DRAIN: begin
                    if (drain_has_next) begin
                        cur_valid <= 1'b1;

                        cur_a11 <= nxt_a11; cur_a12 <= nxt_a12;
                        cur_a21 <= nxt_a21; cur_a22 <= nxt_a22;

                        cur_b11 <= nxt_b11; cur_b12 <= nxt_b12;
                        cur_b21 <= nxt_b21; cur_b22 <= nxt_b22;

                        nxt_valid      <= 1'b0;
                        nxt_loaded     <= 1'b0;
                        nxt_prog       <= 2'd0;
                        drain_has_next <= 1'b0;

                        state <= ST_PRE0;
                    end
                    else begin
                        cur_valid      <= 1'b0;
                        drain_has_next <= 1'b0;
                        state <= ST_IDLE;
                    end
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
