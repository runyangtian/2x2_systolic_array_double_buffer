`timescale 1ns/1ps
module tb_systolic;

    reg clk;
    reg rst_n;
    reg in_valid;

    reg [3:0] a11, a12, a13;
    reg [3:0] a21, a22, a23;
    reg [3:0] a31, a32, a33;

    reg [3:0] b11, b12, b13;
    reg [3:0] b21, b22, b23;
    reg [3:0] b31, b32, b33;

    wire [9:0] c11, c12, c13;
    wire [9:0] c21, c22, c23;
    wire [9:0] c31, c32, c33;
    wire       out_valid;

    systolic dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),

        .a11(a11), .a12(a12), .a13(a13),
        .a21(a21), .a22(a22), .a23(a23),
        .a31(a31), .a32(a32), .a33(a33),

        .b11(b11), .b12(b12), .b13(b13),
        .b21(b21), .b22(b22), .b23(b23),
        .b31(b31), .b32(b32), .b33(b33),

        .c11(c11), .c12(c12), .c13(c13),
        .c21(c21), .c22(c22), .c23(c23),
        .c31(c31), .c32(c32), .c33(c33),

        .out_valid(out_valid)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0;
        in_valid = 0;

        a11=0; a12=0; a13=0;
        a21=0; a22=0; a23=0;
        a31=0; a32=0; a33=0;

        b11=0; b12=0; b13=0;
        b21=0; b22=0; b23=0;
        b31=0; b32=0; b33=0;

        repeat(5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Op1
        a11=1; a12=2; a13=3;
        a21=4; a22=5; a23=6;
        a31=7; a32=8; a33=9;

        b11=1; b12=2; b13=3;
        b21=4; b22=5; b23=6;
        b31=7; b32=8; b33=9;

        in_valid = 1;
        @(posedge clk);
        in_valid = 0;

        @(posedge clk);

        // Op2
        a11=1; a12=0; a13=0;
        a21=0; a22=1; a23=0;
        a31=0; a32=0; a33=1;

        b11=2; b12=3; b13=4;
        b21=5; b22=6; b23=7;
        b31=8; b32=9; b33=1;

        in_valid = 1;
        @(posedge clk);
        in_valid = 0;

        @(posedge out_valid);
        $display("op1 finished");

        @(posedge out_valid);
        $display("op2 finished");

        #100;
        $display("All tests finished.");
        $finish;
    end

    initial begin
        $dumpfile("tb_systolic.vcd");
        $dumpvars(0, tb_systolic);
    end

endmodule
