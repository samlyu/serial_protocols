`timescale 1ns/1ps

module PCA24S08A_bytewrite_tb();

parameter	CLK_FREQ = 50_000_000,
			I2C_FREQ = 500_000,
			CLK_CYCLE = 20,
			DIV = CLK_FREQ / I2C_FREQ;

reg	clk, arstn;
reg	bytewrite_start;
reg	[2:0]	block_num, page_num;
reg	[3:0]	byte_addr;
reg	[7:0]	data_write;
wire	bytewrite_done;

wire	sda, scl;

reg	sda_in, sda_in_en;

assign sda = sda_in_en ? sda_in : 1'bz;

// clk
initial begin
	clk = 0;
	forever	#(CLK_CYCLE/2)	clk = ~clk;
end

// arstn
initial begin
	arstn = 1'b0;
	#(CLK_CYCLE*75)	arstn = 1'b1;
end

task gen_bytewrite_start;
begin
	bytewrite_start = 1'b0;
	@(posedge arstn)
	@(posedge clk)
		#(CLK_CYCLE*10)	bytewrite_start = 1'b1;
		#(CLK_CYCLE)	bytewrite_start = 1'b0;
end
endtask

task gen_bytewrite_addr;
begin
	@(posedge bytewrite_start)
		block_num = 3'b110;
		page_num = 3'b010;
		byte_addr = 4'b1111;
	@(negedge bytewrite_done)
		#(CLK_CYCLE*75)	$finish;
end
endtask

task gen_bytewrite_data;
begin
	@(posedge bytewrite_start)
		data_write = 8'b11001001;
end
endtask

task gen_bytewrite_ack;
begin
	sda_in_en = 1'b0;
	@(negedge bytewrite_start)
		#(CLK_CYCLE*DIV*10)	// SACK1
			sda_in_en = 1'b1;
			sda_in = 1'b0;
		#(CLK_CYCLE*DIV)
			sda_in_en = 1'b0;
		#(CLK_CYCLE*DIV*8)	// SACK2
			sda_in_en = 1'b1;
			sda_in = 1'b0;
		#(CLK_CYCLE*DIV)
			sda_in_en = 1'b0;
		#(CLK_CYCLE*DIV*8)	// SACK2
			sda_in_en = 1'b1;
			sda_in = 1'b0;
		#(CLK_CYCLE*DIV)
			sda_in_en = 1'b0;
end
endtask

initial fork
	gen_bytewrite_start;
	gen_bytewrite_addr;
	gen_bytewrite_data;
	gen_bytewrite_ack;
join

PCA24S08A_bytewrite
#(
	.CLK_FREQ(CLK_FREQ),
	.I2C_FREQ(I2C_FREQ)
)
DUT(
	.clk(clk),
	.arstn(arstn),
	.bytewrite_start(bytewrite_start),
	.block_num(block_num),
	.page_num(page_num),
	.byte_addr(byte_addr),
	.data_write(data_write),
	.bytewrite_done(bytewrite_done),
	.sda(sda),
	.scl(scl)
);

endmodule
