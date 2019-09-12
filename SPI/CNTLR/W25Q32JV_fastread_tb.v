`timescale 1ns/1ps

module W25Q32JV_fastread_tb();

parameter CLK_CYCLE = 20;

reg	clk, arstn;
reg	fastread_start;
reg	[23:0]	addr;
wire	sclk, csn, mosi;
reg		miso;
wire	fastread_done;
wire	[7:0]	data_out_1, data_out_2;

// clk
initial begin
	clk = 0;
	forever	#(CLK_CYCLE/2)	clk = ~clk;
end

// arstn
initial begin
	arstn = 1'b0;
	#(CLK_CYCLE)	arstn = 1'b1;
end

// fastread_start
task gen_fastread_start;
begin
	fastread_start = 1'b0;
	@(posedge arstn)
		#(CLK_CYCLE)	fastread_start = 1'b1;
		#(CLK_CYCLE)	fastread_start = 1'b0;
	@(negedge fastread_done)
		#(CLK_CYCLE)	fastread_start = 1'b1;
		#(CLK_CYCLE)	fastread_start = 1'b0;
end
endtask

// addr
task gen_fastread_addr;
begin
	addr = 'd0;
	@(posedge arstn)
		addr = 24'haaccee;
	@(posedge fastread_done)
		addr = 24'hbbddff;
	@(negedge fastread_done);
	@(negedge fastread_done)
		#(CLK_CYCLE)	$finish;
end
endtask

// miso
always@(negedge sclk) begin
	miso = $random;
end

initial fork
	gen_fastread_start;
	gen_fastread_addr;
join

W25Q32JV_fastread DUT(
	.clk(clk),
	.arstn(arstn),
	.fastread_start(fastread_start),
	.addr(addr),
	.sclk(sclk),
	.csn(csn),
	.mosi(mosi),
	.miso(miso),
	.fastread_done(fastread_done),
	.data_out_1(data_out_1),
	.data_out_2(data_out_2)
	);

endmodule
