`timescale 1ns/1ps
`include "pe.v"

module array_2x2 #(
    parameter Data_W = 4,
    parameter Psum_W = 9
)(
    input                   clk,
    input                   rst_n,

    input      [Data_W-1:0] a1_in,
    input      [Data_W-1:0] a2_in,

    input      [Data_W-1:0] b11,
    input      [Data_W-1:0] b12,
    input      [Data_W-1:0] b21,
    input      [Data_W-1:0] b22,

    input                   load_en1,
    input                   load_en2,

    input                   load_sel,
    input                   act_sel,

    input                   clear,
    input                   pe_en,

    output     [Psum_W-1:0] c11,
    output     [Psum_W-1:0] c12,
    output     [Psum_W-1:0] c21,
    output     [Psum_W-1:0] c22
);

    wire [Data_W-1:0] a00_out;
    wire [Data_W-1:0] a10_out;

    wire [Data_W-1:0] b00_out_unused;
    wire [Data_W-1:0] b01_out_unused;
    wire [Data_W-1:0] b10_out_unused;
    wire [Data_W-1:0] b11_out_unused;

    pe #(
        .Data_W(Data_W),
        .Psum_W(Psum_W)
    ) u_pe11 (
        .clk        (clk),
        .rst_n      (rst_n),

        .a_in       (a1_in),
        .b_in       (b11),
        .cin        ({Psum_W{1'b0}}),

        .a_out      (a00_out),
        .b_out      (b00_out_unused),
        .cout       (c11),

        .load_en    (load_en1),
        .load_sel   (load_sel),
        .act_sel    (act_sel),

        .clear (clear),
        .pe_en (pe_en)
    );

    pe #(
        .Data_W(Data_W),
        .Psum_W(Psum_W)
    ) u_pe12 (
        .clk        (clk),
        .rst_n      (rst_n),

        .a_in       (a00_out),
        .b_in       (b12),
        .cin        ({Psum_W{1'b0}}),

        .a_out      (),
        .b_out      (b01_out_unused),
        .cout       (c12),

        .load_en    (load_en1),
        .load_sel   (load_sel),
        .act_sel    (act_sel),

        .clear (clear),
        .pe_en (pe_en)
    );

    pe #(
        .Data_W(Data_W),
        .Psum_W(Psum_W)
    ) u_pe21 (
        .clk        (clk),
        .rst_n      (rst_n),

        .a_in       (a2_in),
        .b_in       (b21),
        .cin        (c11),

        .a_out      (a10_out),
        .b_out      (b10_out_unused),
        .cout       (c21),

        .load_en    (load_en2),
        .load_sel   (load_sel),
        .act_sel    (act_sel),

        .clear (clear),
        .pe_en (pe_en)
    );

    pe #(
        .Data_W(Data_W),
        .Psum_W(Psum_W)
    ) u_pe22 (
        .clk        (clk),
        .rst_n      (rst_n),

        .a_in       (a10_out),
        .b_in       (b22),
        .cin        (c12),

        .a_out      (),
        .b_out      (b11_out_unused),
        .cout       (c22),

        .load_en    (load_en2),
        .load_sel   (load_sel),
        .act_sel    (act_sel),

        .clear (clear),
        .pe_en (pe_en)
    );

endmodule

