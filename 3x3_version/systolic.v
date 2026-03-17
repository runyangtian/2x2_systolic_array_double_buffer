`timescale 1ns/1ps
`include "array_3x3.v"

module systolic (
    input         clk,
    input         rst_n,

    input  [3:0]  a11, a12, a13,
    input  [3:0]  a21, a22, a23,
    input  [3:0]  a31, a32, a33,

    input  [3:0]  b11, b12, b13,
    input  [3:0]  b21, b22, b23,
    input  [3:0]  b31, b32, b33,

    input         in_valid,

    output reg [9:0] c11, c12, c13,
    output reg [9:0] c21, c22, c23,
    output reg [9:0] c31, c32, c33,
    output reg       out_valid
);

    // S1 (uses PE weight buffer w0)
    reg [3:0] s1_a11, s1_a12, s1_a13;
    reg [3:0] s1_a21, s1_a22, s1_a23;
    reg [3:0] s1_a31, s1_a32, s1_a33;

    reg [3:0] s1_b11, s1_b12, s1_b13;
    reg [3:0] s1_b21, s1_b22, s1_b23;
    reg [3:0] s1_b31, s1_b32, s1_b33;

    reg       s1_busy;
    reg       s1_w_ready;

    // S2 (uses PE weight buffer w1)
    reg [3:0] s2_a11, s2_a12, s2_a13;
    reg [3:0] s2_a21, s2_a22, s2_a23;
    reg [3:0] s2_a31, s2_a32, s2_a33;

    reg [3:0] s2_b11, s2_b12, s2_b13;
    reg [3:0] s2_b21, s2_b22, s2_b23;
    reg [3:0] s2_b31, s2_b32, s2_b33;

    reg       s2_busy;
    reg       s2_w_ready;
    reg [1:0] s2_w_load_step;   // 0:none, 1:row1 done, 2:row2 done, 3:row3 done

    // Run control
    reg       run_s2;           // 0: run slot-1, 1: run slot-2
    reg       mac_buf_sel;      // 0: MAC uses w0, 1: MAC uses w1
    reg [2:0] phase;            // 0...7

    // Array interface
    wire [9:0] c11_int, c12_int, c13_int;
    wire [9:0] c21_int, c22_int, c23_int;
    wire [9:0] c31_int, c32_int, c33_int;

    reg  [3:0] a_r1_in, a_r2_in, a_r3_in;

    reg  [3:0] b_r1_c1, b_r1_c2, b_r1_c3;
    reg  [3:0] b_r2_c1, b_r2_c2, b_r2_c3;
    reg  [3:0] b_r3_c1, b_r3_c2, b_r3_c3;

    reg        ld_r1_en, ld_r2_en, ld_r3_en;
    reg        load_buf_sel;
    reg        clear_i;
    reg        pe_en_i;

    wire [3:0] a_row1_in = a_r1_in;
    wire [3:0] a_row2_in = a_r2_in;
    wire [3:0] a_row3_in = a_r3_in;

    wire [3:0] b_row1_col1 = b_r1_c1;
    wire [3:0] b_row1_col2 = b_r1_c2;
    wire [3:0] b_row1_col3 = b_r1_c3;

    wire [3:0] b_row2_col1 = b_r2_c1;
    wire [3:0] b_row2_col2 = b_r2_c2;
    wire [3:0] b_row2_col3 = b_r2_c3;

    wire [3:0] b_row3_col1 = b_r3_c1;
    wire [3:0] b_row3_col2 = b_r3_c2;
    wire [3:0] b_row3_col3 = b_r3_c3;

    wire       load_en1 = ld_r1_en;
    wire       load_en2 = ld_r2_en;
    wire       load_en3 = ld_r3_en;

    wire       load_sel = load_buf_sel;
    wire       act_sel  = mac_buf_sel;

    wire       clear = clear_i;
    wire       pe_en = pe_en_i;

    // 3x3 systolic array instance
    array_3x3 #(
        .Data_W(4),
        .Psum_W(10)
    ) u_array (
        .clk      (clk),
        .rst_n    (rst_n),

        .a1_in    (a_row1_in),
        .a2_in    (a_row2_in),
        .a3_in    (a_row3_in),

        .b11      (b_row1_col1),
        .b12      (b_row1_col2),
        .b13      (b_row1_col3),
        .b21      (b_row2_col1),
        .b22      (b_row2_col2),
        .b23      (b_row2_col3),
        .b31      (b_row3_col1),
        .b32      (b_row3_col2),
        .b33      (b_row3_col3),

        .load_en1 (load_en1),
        .load_en2 (load_en2),
        .load_en3 (load_en3),

        .load_sel (load_sel),
        .act_sel  (act_sel),

        .clear    (clear),
        .pe_en    (pe_en),

        .c11      (c11_int),
        .c12      (c12_int),
        .c13      (c13_int),
        .c21      (c21_int),
        .c22      (c22_int),
        .c23      (c23_int),
        .c31      (c31_int),
        .c32      (c32_int),
        .c33      (c33_int)
    );

    // Controller FSM
    localparam ST_IDLE    = 3'd0;
    localparam ST_S1_B_R1 = 3'd1;
    localparam ST_S1_B_R2 = 3'd2;
    localparam ST_S1_B_R3 = 3'd3;
    localparam ST_RUN     = 3'd4;

    reg [2:0] st;

    // Combinational control
    always @(*) begin
        a_r1_in = 4'd0;
        a_r2_in = 4'd0;
        a_r3_in = 4'd0;

        b_r1_c1 = 4'd0; b_r1_c2 = 4'd0; b_r1_c3 = 4'd0;
        b_r2_c1 = 4'd0; b_r2_c2 = 4'd0; b_r2_c3 = 4'd0;
        b_r3_c1 = 4'd0; b_r3_c2 = 4'd0; b_r3_c3 = 4'd0;

        ld_r1_en     = 1'b0;
        ld_r2_en     = 1'b0;
        ld_r3_en     = 1'b0;
        load_buf_sel = 1'b0;

        clear_i = 1'b0;
        pe_en_i = 1'b0;

        case (st)
            ST_IDLE: begin
            end

            ST_S1_B_R1: begin
                load_buf_sel = 1'b0;
                ld_r1_en     = 1'b1;
                b_r1_c1      = s1_b11;
                b_r1_c2      = s1_b12;
                b_r1_c3      = s1_b13;
                clear_i      = 1'b1;
            end

            ST_S1_B_R2: begin
                load_buf_sel = 1'b0;
                ld_r2_en     = 1'b1;
                b_r2_c1      = s1_b21;
                b_r2_c2      = s1_b22;
                b_r2_c3      = s1_b23;
                clear_i      = 1'b1;
            end

            ST_S1_B_R3: begin
                load_buf_sel = 1'b0;
                ld_r3_en     = 1'b1;
                b_r3_c1      = s1_b31;
                b_r3_c2      = s1_b32;
                b_r3_c3      = s1_b33;
                clear_i      = 1'b1;
            end

            ST_RUN: begin
                pe_en_i = 1'b1;

                if (!run_s2) begin
                    case (phase)
                        3'd0: begin a_r1_in = s1_a11; a_r2_in = 4'd0;   a_r3_in = 4'd0;   end
                        3'd1: begin a_r1_in = s1_a21; a_r2_in = s1_a12; a_r3_in = 4'd0;   end
                        3'd2: begin a_r1_in = s1_a31; a_r2_in = s1_a22; a_r3_in = s1_a13; end
                        3'd3: begin a_r1_in = 4'd0;   a_r2_in = s1_a32; a_r3_in = s1_a23; end
                        3'd4: begin a_r1_in = 4'd0;   a_r2_in = 4'd0;   a_r3_in = s1_a33; end
                        default: begin a_r1_in = 4'd0; a_r2_in = 4'd0;  a_r3_in = 4'd0;   end
                    endcase
                end else begin
                    case (phase)
                        3'd0: begin a_r1_in = s2_a11; a_r2_in = 4'd0;   a_r3_in = 4'd0;   end
                        3'd1: begin a_r1_in = s2_a21; a_r2_in = s2_a12; a_r3_in = 4'd0;   end
                        3'd2: begin a_r1_in = s2_a31; a_r2_in = s2_a22; a_r3_in = s2_a13; end
                        3'd3: begin a_r1_in = 4'd0;   a_r2_in = s2_a32; a_r3_in = s2_a23; end
                        3'd4: begin a_r1_in = 4'd0;   a_r2_in = 4'd0;   a_r3_in = s2_a33; end
                        default: begin a_r1_in = 4'd0; a_r2_in = 4'd0;  a_r3_in = 4'd0;   end
                    endcase
                end

                // overlap load S2 weights while S1 runs
                if (!run_s2 && s2_busy && !s2_w_ready) begin
                    load_buf_sel = 1'b1;

                    if (s2_w_load_step == 2'd0) begin
                        ld_r1_en = 1'b1;
                        b_r1_c1  = s2_b11;
                        b_r1_c2  = s2_b12;
                        b_r1_c3  = s2_b13;
                    end else if (s2_w_load_step == 2'd1) begin
                        ld_r2_en = 1'b1;
                        b_r2_c1  = s2_b21;
                        b_r2_c2  = s2_b22;
                        b_r2_c3  = s2_b23;
                    end else if (s2_w_load_step == 2'd2) begin
                        ld_r3_en = 1'b1;
                        b_r3_c1  = s2_b31;
                        b_r3_c2  = s2_b32;
                        b_r3_c3  = s2_b33;
                    end
                end
            end

            default: begin
            end
        endcase
    end

    // Sequential control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st             <= ST_IDLE;
            phase          <= 3'd0;

            s1_busy        <= 1'b0;
            s1_w_ready     <= 1'b0;
            s2_busy        <= 1'b0;
            s2_w_ready     <= 1'b0;
            s2_w_load_step <= 2'd0;

            run_s2         <= 1'b0;
            mac_buf_sel    <= 1'b0;

            s1_a11 <= 4'd0; s1_a12 <= 4'd0; s1_a13 <= 4'd0;
            s1_a21 <= 4'd0; s1_a22 <= 4'd0; s1_a23 <= 4'd0;
            s1_a31 <= 4'd0; s1_a32 <= 4'd0; s1_a33 <= 4'd0;

            s1_b11 <= 4'd0; s1_b12 <= 4'd0; s1_b13 <= 4'd0;
            s1_b21 <= 4'd0; s1_b22 <= 4'd0; s1_b23 <= 4'd0;
            s1_b31 <= 4'd0; s1_b32 <= 4'd0; s1_b33 <= 4'd0;

            s2_a11 <= 4'd0; s2_a12 <= 4'd0; s2_a13 <= 4'd0;
            s2_a21 <= 4'd0; s2_a22 <= 4'd0; s2_a23 <= 4'd0;
            s2_a31 <= 4'd0; s2_a32 <= 4'd0; s2_a33 <= 4'd0;

            s2_b11 <= 4'd0; s2_b12 <= 4'd0; s2_b13 <= 4'd0;
            s2_b21 <= 4'd0; s2_b22 <= 4'd0; s2_b23 <= 4'd0;
            s2_b31 <= 4'd0; s2_b32 <= 4'd0; s2_b33 <= 4'd0;

            c11 <= 10'd0; c12 <= 10'd0; c13 <= 10'd0;
            c21 <= 10'd0; c22 <= 10'd0; c23 <= 10'd0;
            c31 <= 10'd0; c32 <= 10'd0; c33 <= 10'd0;

            out_valid <= 1'b0;

        end else begin
            out_valid <= 1'b0;

            if (in_valid) begin
                if (!s1_busy && st == ST_IDLE) begin
                    s1_a11 <= a11; s1_a12 <= a12; s1_a13 <= a13;
                    s1_a21 <= a21; s1_a22 <= a22; s1_a23 <= a23;
                    s1_a31 <= a31; s1_a32 <= a32; s1_a33 <= a33;

                    s1_b11 <= b11; s1_b12 <= b12; s1_b13 <= b13;
                    s1_b21 <= b21; s1_b22 <= b22; s1_b23 <= b23;
                    s1_b31 <= b31; s1_b32 <= b32; s1_b33 <= b33;

                    s1_busy     <= 1'b1;
                    s1_w_ready  <= 1'b0;

                    st          <= ST_S1_B_R1;
                    run_s2      <= 1'b0;
                    mac_buf_sel <= 1'b0;
                    phase       <= 3'd0;

                end else if (s1_busy && !s2_busy) begin
                    s2_a11 <= a11; s2_a12 <= a12; s2_a13 <= a13;
                    s2_a21 <= a21; s2_a22 <= a22; s2_a23 <= a23;
                    s2_a31 <= a31; s2_a32 <= a32; s2_a33 <= a33;

                    s2_b11 <= b11; s2_b12 <= b12; s2_b13 <= b13;
                    s2_b21 <= b21; s2_b22 <= b22; s2_b23 <= b23;
                    s2_b31 <= b31; s2_b32 <= b32; s2_b33 <= b33;

                    s2_busy        <= 1'b1;
                    s2_w_ready     <= 1'b0;
                    s2_w_load_step <= 2'd0;
                end
            end

            case (st)
                ST_IDLE: begin
                end

                ST_S1_B_R1: begin
                    st <= ST_S1_B_R2;
                end

                ST_S1_B_R2: begin
                    st <= ST_S1_B_R3;
                end

                ST_S1_B_R3: begin
                    s1_w_ready  <= 1'b1;
                    st          <= ST_RUN;
                    run_s2      <= 1'b0;
                    mac_buf_sel <= 1'b0;
                    phase       <= 3'd0;
                end

                ST_RUN: begin
                    if (phase < 3'd7) phase <= phase + 3'd1;
                    else              phase <= 3'd0;

                    if (!run_s2 && s2_busy && !s2_w_ready) begin
                        if (s2_w_load_step == 2'd0) begin
                            s2_w_load_step <= 2'd1;
                        end else if (s2_w_load_step == 2'd1) begin
                            s2_w_load_step <= 2'd2;
                        end else if (s2_w_load_step == 2'd2) begin
                            s2_w_load_step <= 2'd3;
                            s2_w_ready     <= 1'b1;
                        end
                    end

                    if (phase == 3'd0) begin
                        c31 <= 0;
                        c32 <= 0;
                        c33 <= 0;
                    end

                    if (phase == 3'd3) begin
                        c31 <= c31_int;
                    end

                    if (phase == 3'd4) begin
                        c32 <= c32_int;
                        c31 <= c31_int;
                    end

                    if (phase == 3'd5) begin
                        c31 <= c31_int;
                        c33 <= c33_int;
                        c32 <= c32_int;
                    end

                    if (phase == 3'd6) begin
                        c33 <= c33_int;
                        c32 <= c32_int;
                    end

                    if (phase == 3'd7) begin
                        c33 <= c33_int;
                        out_valid <= 1'b1;

                        if (!run_s2) begin
                            s1_busy    <= 1'b0;
                            s1_w_ready <= 1'b0;

                            if (s2_busy && s2_w_ready) begin
                                run_s2      <= 1'b1;
                                mac_buf_sel <= 1'b1;
                                phase       <= 3'd0;
                            end else begin
                                st <= ST_IDLE;
                            end
                        end else begin
                            s2_busy    <= 1'b0;
                            s2_w_ready <= 1'b0;
                            run_s2      <= 1'b0;
                            mac_buf_sel <= 1'b0;
                            st          <= ST_IDLE;
                        end
                    end
                end

                default: begin
                    st <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
