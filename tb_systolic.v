`timescale 1ns/1ps
module tb_systolic;

    reg clk;
    reg rst_n;
    reg in_valid;
    reg [3:0] a11, a12, a21, a22;
    reg [3:0] b11, b12, b21, b22;

    wire [8:0] c11, c12, c21, c22;
    wire       out_valid;

    systolic dut (
        .clk(clk), .rst_n(rst_n), .in_valid(in_valid),
        .a11(a11), .a12(a12), .a21(a21), .a22(a22),
        .b11(b11), .b12(b12), .b21(b21), .b22(b22),
        .c11(c11), .c12(c12), .c21(c21), .c22(c22),
        .out_valid(out_valid)
    );

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n = 0; in_valid = 0;
        a11=0; a12=0; a21=0; a22=0; b11=0; b12=0; b21=0; b22=0;
        repeat(5) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        a11=1; a12=2; a21=3; a22=4; b11=5; b12=6; b21=7; b22=8;
        in_valid = 1;
        @(posedge clk);
        in_valid = 0;

	//wait(out_valid);
	//$display("Op1 finished");

        @(posedge clk);
        a11=1; a12=0; a21=0; a22=1; b11=2; b12=3; b21=4; b22=5;
        in_valid = 1;
        @(posedge clk);
        in_valid = 0;

	//wait(out_valid);
	//$display("Op2 finished");

    
	    wait(out_valid);
        $display("op1 finished");

    
	    wait(out_valid);
        $display("op2 finished");

	#100
        $display("All tests finished.");
        $finish;
    end

    initial begin
        $dumpfile("tb_systolic.vcd");
        $dumpvars(0, tb_systolic);
    end

endmodule
