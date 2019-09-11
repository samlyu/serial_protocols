`timescale 1ns/1ps

module spi_duplex
#(
	parameter	CLK_FREQ = 50_000_000,
				SPI_FREQ = 5_000_000,
				DATA_WIDTH = 8,
				CPOL = 0,	// 0: idle at 0; 1: idle at 1
				CPHA = 0	// ^==0: sample@pos, shift@neg; ^==1: sample@neg, shift@pos
)
(
	input	clk, arstn,
	input	spi_m_start,
	input	[DATA_WIDTH-1:0]	data_m_send, data_s_send,
	output	spi_m_done, spi_s_done,
	output	[DATA_WIDTH-1:0]	data_m_recv, data_s_recv
);

// spi wires
wire	sclk, miso, mosi, csn;

// inst - spi_master
spi_master
#(
	.CLK_FREQ(CLK_FREQ),
	.SPI_FREQ(SPI_FREQ),
	.DATA_WIDTH(DATA_WIDTH),
	.CPOL(CPOL),
	.CPHA(CPHA)
)
spi_master_inst
(
	.clk(clk),
	.arstn(arstn),
	.data_send(data_m_send),
	.spi_start(spi_m_start),
	.sclk(sclk),
	.csn(csn),
	.miso(miso),
	.mosi(mosi),
	.spi_done(spi_m_done),
	.data_recv(data_m_recv)
);

// inst - spi_slave
spi_slave
#(
	.CLK_FREQ(CLK_FREQ),
	.SPI_FREQ(SPI_FREQ),
	.DATA_WIDTH(DATA_WIDTH),
	.CPOL(CPOL),
	.CPHA(CPHA)
)
spi_slave_inst
(
	.clk(clk),
	.arstn(arstn),
	.data_send(data_s_send),
	.sclk(sclk),
	.csn(csn),
	.miso(miso),
	.mosi(mosi),
	.spi_done(spi_s_done),
	.data_recv(data_s_recv)
);

endmodule
