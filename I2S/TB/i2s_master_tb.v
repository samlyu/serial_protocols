`timescale 1ns/1ps

module i2s_master_tb();

parameter	CLK_DIV = 256,
			WS_DIV = 64,
			DATA_WIDTH = 24,
			CLK_CYCLE = 20;

reg	clk, arstn;
wire	sck, ws;
reg	sdi;
wire	sdo;
reg	[DATA_WIDTH-1:0]	data_send_left, data_send_right;
wire	[DATA_WIDTH-1:0]	data_recv_left, data_recv_right;

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

// finish
initial begin
	@(negedge ws);
	@(negedge ws)
		#(CLK_CYCLE*50)	$finish;
end

// data_send
initial begin
	data_send_left = 24'h123456;
	data_send_right = 24'habcdef;
end

// sdi
initial begin
	sdi = 1'b0;
end
always@(negedge sck) begin
	sdi = $random;
end

i2s_master
#(
	.CLK_DIV(CLK_DIV),
	.WS_DIV(WS_DIV),
	.DATA_WIDTH(DATA_WIDTH)
)
DUT(
	.clk(clk),
	.arstn(arstn),
	.sck(sck),
	.ws(ws),
	.sdi(sdi),
	.sdo(sdo),
	.data_send_left(data_send_left),
	.data_send_right(data_send_right),
	.data_recv_left(data_recv_left),
	.data_recv_right(data_recv_right)
);

endmodule
