`timescale 1ns/1ps

module W25Q32JV_fastread(
	input	clk, arstn,
	input	fastread_start,
	input	[23:0]	addr,
	output	sclk, csn, mosi,
	input	miso,
	output	fastread_done,
	output	[7:0]	data_out_1, data_out_2
	);

wire	[8+24+8+16-1:0]	data_send, data_recv;
wire	spi_start, spi_done;

assign spi_start = fastread_start;
assign data_send = {8'h0b, addr, 8'h00, 8'h00, 8'h00};

assign fastread_done = spi_done;
assign data_out_1 = fastread_done ? data_recv[15:8] : 'd0;
assign data_out_2 = fastread_done ? data_recv[7:0] : 'd0;

spi_master
#(
	.CLK_FREQ(50_000_000),
	.SPI_FREQ(5_000_000),
	.DATA_WIDTH(8+24+8+16),
	.CPOL(0),	// 0: idle at 0; 1: idle at 1
	.CPHA(0)	// 0: sample@pos, shift@neg; 1: sample@neg, shift@pos 
)
spi_ctrl(
	.clk(clk),
	.arstn(arstn),
	.data_send(data_send),
	.spi_start(spi_start),
	.sclk(sclk),
	.csn(csn),
	.mosi(mosi),
	.miso(miso),
	.spi_done(spi_done),
	.data_recv(data_recv)
);

endmodule
