`timescale 1ns/1ps

module spi_duplex_tb();

parameter	CLK_FREQ = 50_000_000,
			SPI_FREQ = 5_000_000,
			DATA_WIDTH = 8,
			CPOL = 0,	// 0: idle at 0; 1: idle at 1
			CPHA = 0;	// ^==0: sample@pos, shift@neg; ^==1: sample@neg, shift@pos

reg	clk, arstn;
reg	spi_m_start;
reg	[DATA_WIDTH-1:0]	data_m_send, data_s_send;
wire	spi_m_done, spi_s_done;
wire	[DATA_WIDTH-1:0]	data_m_recv, data_s_recv;

// reg	[1:0]	spi_done_reg;
// wire	spi_done_pos;
reg [DATA_WIDTH-1:0]	data_m_send_reg, data_s_send_reg;

// clk
initial begin
	clk = 1'b1;
end

always begin
	#10 clk = ~clk;
end

// arstn
initial begin
	arstn = 1'b0;
	#20 arstn = 1'b1;
end

// spi_m_start
task gen_spi_m_start;
begin
	spi_m_start = 1'b0;
	@(posedge arstn)
		#20	spi_m_start = 1'b1;
		#20	spi_m_start = 1'b0;
	@(negedge spi_m_done)
		#20	spi_m_start = 1'b1;
		#20	spi_m_start = 1'b0;
end
endtask

// data_m_send
task gen_data_m_send;
begin
	data_m_send = 'd0;
	@(posedge arstn)
		data_m_send = 8'hab;
	@(posedge spi_m_done)
		data_m_send = 8'hee;
end
endtask

// data_s_send
task gen_data_s_send;
begin
	data_s_send = 'd0;
	@(posedge arstn)
		data_s_send = 8'hcd;
	@(posedge spi_s_done)
		data_s_send = 8'hff;
	@(negedge spi_s_done);
	@(negedge spi_s_done)
		#20 $finish;
end
endtask

// monitor signals
// always@(posedge clk) begin
// 	spi_done_reg[0] <= spi_s_done;
// 	spi_done_reg[1] <= spi_done_reg[0];
// end
// assign spi_done_pos = spi_done_reg[0] & ~spi_done_reg[1];
always@(posedge clk) begin
	if(spi_m_start) begin
		data_m_send_reg <= data_m_send;
		data_s_send_reg <= data_s_send;
	end
end
// check mosi
always@(posedge clk) begin
	if(spi_m_done & spi_s_done) begin
		if(data_m_send_reg == data_s_recv)
			$display("PASS: master = %h, slave = %h", data_m_send_reg, data_s_recv);
		else
			$display("FAIL: master = %h, slave = %h", data_m_send_reg, data_s_recv);
	end
end
// check miso
always@(posedge clk) begin
	if(spi_m_done & spi_s_done) begin
		if(data_s_send_reg == data_m_recv)
			$display("PASS: slave = %h, master = %h", data_s_send_reg, data_m_recv);
		else
			$display("FAIL: slave = %h, master = %h", data_s_send_reg, data_m_recv);
	end
end

initial fork
	gen_data_m_send;
	gen_data_s_send;
	gen_spi_m_start;
join

spi_duplex
#(
	.CLK_FREQ(CLK_FREQ),
	.SPI_FREQ(SPI_FREQ),
	.DATA_WIDTH(DATA_WIDTH),
	.CPOL(CPOL),	// 0: idle at 0; 1: idle at 1
	.CPHA(CPHA)		// 0: sample@pos, shift@neg; 1: sample@neg, shift@pos 
)
DUT(
	.clk(clk),
	.arstn(arstn),
	.spi_m_start(spi_m_start),
	.data_m_send(data_m_send),
	.spi_m_done(spi_m_done),
	.data_m_recv(data_m_recv),
	.data_s_send(data_s_send),
	.spi_s_done(spi_s_done),
	.data_s_recv(data_s_recv)
);

endmodule
