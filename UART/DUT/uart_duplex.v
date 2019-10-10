`timescale 1ns/1ps

module uart_duplex
#(
	parameter	CLK_FREQ = 50_000_000,
				BAUD_RATE = 115200,
				PARITY = "NONE",
				DATA_WIDTH = 8
)
(
	input	clk, arstn,
	input	tx_start,
	input	[DATA_WIDTH-1:0]	tx_data,
	output	tx_done,
	output	[DATA_WIDTH-1:0]	rx_data,
	output	rx_done,
	output	rx_error
);

wire	serial;

uart_tx
#(
	.CLK_FREQ(CLK_FREQ),
	.BAUD_RATE(BAUD_RATE),
	.PARITY(PARITY),
	.DATA_WIDTH(DATA_WIDTH)
)
uart_tx_inst(
	.clk(clk), 
	.arstn(arstn),
	.tx_start(tx_start),
	.tx_done(tx_done),
	.tx_data(tx_data),
	.TXD(serial)
);

uart_rx
#(
	.CLK_FREQ(CLK_FREQ),
	.BAUD_RATE(BAUD_RATE),
	.PARITY(PARITY),
	.DATA_WIDTH(DATA_WIDTH)
)
uart_rx_inst(
	.clk(clk), 
	.arstn(arstn),
	.rx_error(rx_error),
	.rx_done(rx_done),
	.rx_data(rx_data),
	.RXD(serial)
);

endmodule
