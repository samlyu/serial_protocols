`timescale 1ns/1ps

module spi_master_tb();

parameter	CLK_FREQ = 50_000_000,
			SPI_FREQ = 5_000_000,
			DATA_WIDTH = 8,
			CPOL = 0,	// 0: idle at 0; 1: idle at 1
			CPHA = 0;	// 0: sample@pos, shift@neg; 1: sample@neg, shift@pos 

reg	clk, rstn;
reg	[DATA_WIDTH-1:0]	data_send;
reg	spi_start;
wire	sclk, csn, mosi;
reg	miso;
wire	spi_done;
wire	[DATA_WIDTH-1:0]	data_recv;

// clk
initial begin
	clk = 1'b1;
end

always begin
	#10 clk = ~clk;
end

// rstn
initial begin
	rstn = 1'b0;
	#20	rstn = 1'b1;
end

// miso
generate
	case(CPHA)
		0:	begin
			always@(negedge sclk) begin
				miso = $random;
			end
		end
		1:	begin
			always@(posedge sclk) begin
				miso = $random;
			end
		end
	endcase
endgenerate

// spi_start
task gen_spi_start;
begin
	spi_start = 1'b0;
	@(posedge rstn)
		#20	spi_start = 1'b1;
		#20	spi_start = 1'b0;
	@(negedge spi_done)
		#20 spi_start = 1'b1;
		#20	spi_start = 1'b0;
end
endtask

// data_send
task gen_data_send;
begin
	data_send = 'd0;
	@(posedge rstn)
		data_send = 8'b10100101;
	@(posedge spi_done)
		data_send = 8'b10011010;
	@(negedge spi_done);
	@(negedge spi_done)
		#20 $finish;
end
endtask

// monitor signals
always@(posedge sclk) begin
	$display("TIME = %d: MOSI = %b", $time, mosi);
end
always@(posedge spi_start) begin
	$display("TIME = %d: DATA = %b", $time, data_send);
end
// always@(negedge sclk) begin
// 	$display("T = %d: MISO = %b", $time, miso);
// end
// task gen_monitor;
// begin
// 	$display("--------------------");
// 	$monitor("%d, Start = %b, Done = %b, MOSI = %b, MISO = %b, DATA_SEND = %b", $time, spi_start, spi_done, mosi, miso, data_send);
// end
// endtask

initial fork
	gen_data_send;
	gen_spi_start;
	// gen_monitor;
join

spi_master
#(
	.CLK_FREQ(CLK_FREQ),
	.SPI_FREQ(SPI_FREQ),
	.DATA_WIDTH(DATA_WIDTH),
	.CPOL(CPOL),	// 0: idle at 0; 1: idle at 1
	.CPHA(CPHA)		// 0: sample@pos, shift@neg; 1: sample@neg, shift@pos 
)
DUT(
	.clk(clk),
	.rstn(rstn),
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
