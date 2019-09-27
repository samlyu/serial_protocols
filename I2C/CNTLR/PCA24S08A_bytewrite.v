`timescale 1ns/1ps

module PCA24S08A_bytewrite
#(
	parameter	CLK_FREQ = 50_000_000,
				I2C_FREQ = 500_000
)
(
	input	clk, arstn,
	input	bytewrite_start,
	input	[2:0]	block_num, page_num,
	input	[3:0]	byte_addr,
	input	[7:0]	data_write,
	output	bytewrite_done,

	inout	sda,
	output	scl
);

parameter DIV = CLK_FREQ / I2C_FREQ;

reg	flag;
reg	[10:0]	counter;

wire	i2c_start;
wire	[6:0]	addr;
wire	rw;
wire	[7:0]	data_send;
wire	i2c_done;

always@(posedge clk or negedge arstn) begin
	if(~arstn)
		flag <= 1'b0;
	else if(i2c_start) begin
		flag <= ~flag;
	end
end

always@(posedge clk or negedge arstn) begin
	if(~arstn)
		counter <= 'd0;
	else if(flag) begin
		counter <= counter + 1'b1;
	end
end

assign i2c_start = (~flag) ? bytewrite_start : (counter == DIV * 19);

assign addr = {5'b10101, block_num[2:1]};

assign rw = 1'b0;

assign data_send = (flag) ? {block_num[0], page_num, byte_addr} : data_write;

assign bytewrite_done = i2c_done;

i2c_master
#(
	.CLK_FREQ(CLK_FREQ),
	.I2C_FREQ(I2C_FREQ)
)
i2c_ctrl(
	.clk(clk),
	.arstn(arstn),
	.i2c_start(i2c_start),
	.addr(addr),
	.rw(rw),
	.data_send(data_send),
	.i2c_done(i2c_done),
	.data_recv(),
	.data_recv_done(),
	.sda(sda),
	.scl(scl)
);

endmodule
