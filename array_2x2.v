`timescale 1ns/1ps
`include "pe.v"

module array_2x2 #(
    parameter Data_W = 4,
    parameter Psum_W = 9
)(
    input                   clk,
    input                   rst_n,

    input      [Data_W-1:0] a11_in,
    input      [Data_W-1:0] a21_in,

    input      [Data_W-1:0] b11_in,
    input      [Data_W-1:0] b12_in,

    input       [3:0]       load_en,
    input       [3:0]       load_sel,
    input       [3:0]       act_sel,

    input                   clear,
    input                   pe_en,

    output     [Psum_W-1:0] c21_out,
    output     [Psum_W-1:0] c22_out
);

    wire [Data_W-1:0] a11_out;
    wire [Data_W-1:0] a21_out;
    wire [Data_W-1:0] b11_out;
    wire [Data_W-1:0] b12_out;
    wire [Psum_W-1:0] c11_out;
    wire [Psum_W-1:0] c12_out;


    pe #(
        .Data_W(Data_W),
        .Psum_W(Psum_W)
    ) u_pe11 (
        .clk        (clk),
        .rst_n      (rst_n),

        .a_in       (a11_in),
        .b_in       (b11_in),
        .cin        ({Psum_W{1'b0}}),

        .a_out      (a11_out),
        .b_out      (b11_out),
        .cout       (c11_out),

        .load_en    (load_en[0]),
        .load_sel   (load_sel[0]),
        .act_sel    (act_sel[0]),

        .clear (clear),
        .pe_en (pe_en)
    );

    pe #(
        .Data_W(Data_W),
        .Psum_W(Psum_W)
    ) u_pe12 (
        .clk        (clk),
        .rst_n      (rst_n),

        .a_in       (a11_out),
        .b_in       (b12_in),
        .cin        ({Psum_W{1'b0}}),

        .a_out      (),
        .b_out      (b12_out),
        .cout       (c12_out),

        .load_en    (load_en[1]),
        .load_sel   (load_sel[1]),
        .act_sel    (act_sel[1]),

        .clear (clear),
        .pe_en (pe_en)
    );

    pe #(
        .Data_W(Data_W),
        .Psum_W(Psum_W)
    ) u_pe21 (
        .clk        (clk),
        .rst_n      (rst_n),

        .a_in       (a21_in),
        .b_in       (b11_out),
        .cin        (c11_out),

        .a_out      (a21_out),
        .b_out      (),
        .cout       (c21_out),

        .load_en    (load_en[2]),
        .load_sel   (load_sel[2]),
        .act_sel    (act_sel[2]),

        .clear (clear),
        .pe_en (pe_en)
    );

    pe #(
        .Data_W(Data_W),
        .Psum_W(Psum_W)
    ) u_pe22 (
        .clk        (clk),
        .rst_n      (rst_n),

        .a_in       (a21_out),
        .b_in       (b12_out),
        .cin        (c12_out),

        .a_out      (),
        .b_out      (),
        .cout       (c22_out),

        .load_en    (load_en[3]),
        .load_sel   (load_sel[3]),
        .act_sel    (act_sel[3]),

        .clear (clear),
        .pe_en (pe_en)
    );

endmodule


