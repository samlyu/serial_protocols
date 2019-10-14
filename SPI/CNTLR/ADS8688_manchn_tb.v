`timescale 1ns/1ps

module ADS8688_manchn_tb();

parameter CLK_CYCLE = 20;

reg	clk, arstn;
reg	manchn_start;
reg	[15:0]	chsel;
wire	sclk, csn, mosi;
reg		miso;
wire	manchn_done;
wire	[15:0]	ch_data;

// clk
initial begin
	clk = 0;
	forever	#(CLK_CYCLE/2)	clk = ~clk;
end

// arstn
initial begin
	arstn = 1'b0;
	@(posedge clk)
		#(CLK_CYCLE)	arstn = 1'b1;
end

// manchn_start
task gen_manchn_start;
begin
	manchn_start = 1'b0;
	@(posedge arstn)
		#(CLK_CYCLE*15)	manchn_start <= 1'b1;
		#(CLK_CYCLE)	manchn_start <= 1'b0;
end
endtask

// chsel
task gen_chsel;
begin
	chsel = 'd0;
	@(posedge manchn_start)
		#(CLK_CYCLE)	chsel = 16'hc400;
	@(negedge manchn_done)
		#(CLK_CYCLE*15)	$finish;
end
endtask

always@(negedge sclk) begin
	miso = $random;
end

initial fork
	gen_manchn_start;
	gen_chsel;
join

ADS8688_manchn DUT(
	.clk(clk),
	.arstn(arstn),
	.manchn_start(manchn_start),
	.chsel(chsel),
	.sclk(sclk),
	.csn(csn),
	.mosi(mosi),
	.miso(miso),
	.manchn_done(manchn_done),
	.ch_data(ch_data)
	);

endmodule
