`timescale 1ns/1ps

module uart_duplex_tb();

parameter	CLK_FREQ = 50_000_000,
			BAUD_RATE = 115200,
			PARITY = "EVEN",
			DATA_WIDTH = 8,
			CLK_CYCLE = 20;

reg	clk, arstn;
reg	tx_start;
wire	tx_done;
reg	[DATA_WIDTH-1:0]	tx_data;
wire	rx_done;
wire	[DATA_WIDTH-1:0]	rx_data;
wire	rx_error;

// clk
initial begin
	clk = 0;
	forever	#(CLK_CYCLE/2)	clk = ~clk;
end

// arstn
initial begin
	arstn = 1'b0;
	@(posedge clk)
		#(CLK_CYCLE*50)	arstn = 1'b1;
end

initial begin
	tx_data = 'b11001001;
	tx_start = 1'b0;
	@(posedge arstn)
		#(CLK_CYCLE*10)	tx_start = 1'b1;
		#(CLK_CYCLE)	tx_start = 1'b0;
	@(negedge tx_done)
		#(CLK_CYCLE*50)	$finish;
end

initial begin
	@(posedge rx_done) begin
		if(rx_data == tx_data)
			$display("PASS: TX = %h, RX = %h", tx_data, rx_data);
		else
			$display("FAIL: TX = %h, RX = %h", tx_data, rx_data);
	end
end

uart_duplex
#(
	.CLK_FREQ(CLK_FREQ),
	.BAUD_RATE(BAUD_RATE),
	.PARITY(PARITY),
	.DATA_WIDTH(DATA_WIDTH)
)
DUT(
	.clk(clk), 
	.arstn(arstn),
	.tx_start(tx_start),
	.tx_data(tx_data),
	.tx_done(tx_done),
	.rx_data(rx_data),
	.rx_done(rx_done),
	.rx_error(rx_error)
);

endmodule
