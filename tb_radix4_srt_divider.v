`timescale 1ns/1ps

module tb_radix4_srt_divider;

reg         clk;
reg         rst_n;
reg         start;
reg  [31:0] dividend_N;
reg  [31:0] divisor_D;

wire [31:0] Q_final;
wire [31:0] R_final;
wire        valid;

//////////////////////////////////////////////////////
// DUT
//////////////////////////////////////////////////////

radix4_srt_divider DUT
(
    .clk(clk),
    .rst_n(rst_n),
    .start(start),
    .dividend_N(dividend_N),
    .divisor_D(divisor_D),
    .Q_final(Q_final),
    .R_final(R_final),
    .valid(valid)
);

//////////////////////////////////////////////////////
// Clock
//////////////////////////////////////////////////////

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

//////////////////////////////////////////////////////
// Test Task
//////////////////////////////////////////////////////

task run_case;

input [31:0] N;
input [31:0] D;

begin

    @(posedge clk);

    dividend_N <= N;
    divisor_D  <= D;
    start      <= 1'b1;

    @(posedge clk);
    start <= 1'b0;

    wait(valid);

    $display("--------------------------------------------");
    $display("Dividend = %0d", $signed(N));
    $display("Divisor  = %0d", $signed(D));
    $display("Quotient = %0d", $signed(Q_final));
    $display("Remainder= %0d", $signed(R_final));

    if(D!=0)
    begin
        $display("Expected Quotient = %0d",$signed(N)/$signed(D));
        $display("Expected Remainder= %0d",$signed(N)%$signed(D));
    end

    @(posedge clk);

end

endtask

//////////////////////////////////////////////////////
// Stimulus
//////////////////////////////////////////////////////

initial begin

    rst_n = 0;
    start = 0;
    dividend_N = 0;
    divisor_D = 0;

    repeat(5) @(posedge clk);

    rst_n = 1;

    ///////////////////////////////////////////
    // Positive
    ///////////////////////////////////////////

    run_case(32'd14,32'd4);

    run_case(32'd14,32'd3);

    run_case(32'd100,32'd7);

    run_case(32'd255,32'd13);

    ///////////////////////////////////////////
    // Negative dividend
    ///////////////////////////////////////////

    run_case(-32'sd14,32'd4);

    ///////////////////////////////////////////
    // Negative divisor
    ///////////////////////////////////////////

    run_case(32'd14,-32'sd4);

    ///////////////////////////////////////////
    // Both negative
    ///////////////////////////////////////////

    run_case(-32'sd14,-32'sd4);

    ///////////////////////////////////////////
    // Exact division
    ///////////////////////////////////////////

    run_case(32'd128,32'd8);

    ///////////////////////////////////////////
    // Large number
    ///////////////////////////////////////////

    run_case(32'd123456789,32'd12345);

    ///////////////////////////////////////////
    // Divide by 1
    ///////////////////////////////////////////

    run_case(32'd987654321,32'd1);

    ///////////////////////////////////////////
    // Dividend < divisor
    ///////////////////////////////////////////

    run_case(32'd5,32'd17);

    ///////////////////////////////////////////

    #100;

    $display("====================================");
    $display("Simulation Finished");
    $display("====================================");

    $finish;

end

//////////////////////////////////////////////////////
// Waveform
//////////////////////////////////////////////////////

initial begin
    $dumpfile("radix4_srt_divider.vcd");
    $dumpvars(0,tb_radix4_srt_divider);
end

endmodule
