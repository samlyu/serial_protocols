`timescale 1ns/1ps

module ADS8688_manchn(
	input	clk, arstn,
	input	manchn_start,
	input	[15:0]	chsel,
	output	sclk, csn, mosi,
	input	miso,
	output	manchn_done,
	output	[15:0]	ch_data
	);

wire	[16+16-1:0]	data_send, data_recv;
wire	spi_start, spi_done;
reg		flag;
reg		done_reg;
wire	done_neg;

always@(posedge clk or negedge arstn) begin
	if(~arstn)
		flag <= 1'b0;
	else if(spi_done)
		flag <= ~flag;
end

assign spi_start = (~flag) ? manchn_start : done_neg;

always@(posedge clk or negedge arstn) begin
	if(~arstn)
		done_reg <= 1'b0;
	else
		done_reg <= spi_done;
end
assign done_neg = done_reg & ~spi_done;

assign data_send = (~flag) ? {chsel, 16'h00} : 32'h00;

assign manchn_done = flag & spi_done;

assign ch_data = manchn_done ? data_recv[15:0] : 'd0;

spi_master
#(
	.CLK_FREQ(50_000_000),
	.SPI_FREQ(5_000_000),
	.DATA_WIDTH(16+16),
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
