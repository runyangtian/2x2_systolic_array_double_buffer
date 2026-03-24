`timescale 1ns/1ps

module pe #(
    parameter Data_W = 4,
    parameter Psum_W = 9
)(
    input                   clk,
    input                   rst_n,
    input                   clear,

    input      [Data_W-1:0] a_in,
    input      [Data_W-1:0] b_in,
    input      [Psum_W-1:0] cin,

    output reg [Data_W-1:0] a_out,
    output reg [Data_W-1:0] b_out,
    output reg [Psum_W-1:0] cout,

    input                   pe_en,
    input                   load_en,
    input                   load_sel,
    input                   act_sel
);

    reg  [Data_W-1:0]   w0_buf, w1_buf;
    wire [Data_W-1:0]   w_act;
    wire [2*Data_W-1:0] product;
    reg  [Psum_W-1:0]   mul_ext;

    assign w_act   = act_sel ? w1_buf : w0_buf;
    assign product = a_in * w_act;

    always @(*) begin
        mul_ext = 0;
        mul_ext[2*Data_W-1:0] = product;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w0_buf <= 0;
            w1_buf <= 0;
            a_out  <= 0;
            b_out  <= 0;
            cout   <= 0;
        end 
        else begin
            a_out <= a_in;
            b_out <= b_in;

            if (load_en) begin
                if (load_sel) w1_buf <= b_in;
                else          w0_buf <= b_in;
            end

            if (clear) 
                cout <= 0;
            else if (pe_en) 
                cout <= cin + mul_ext;
            else 
                cout <= cin;
        end
    end

endmodule
