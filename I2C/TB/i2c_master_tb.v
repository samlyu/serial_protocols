`timescale 1ns/1ps

module i2c_master_tb();

parameter	CLK_FREQ = 50_000_000,
			I2C_FREQ = 500_000,
			CLK_CYCLE = 20,
			DIV = CLK_FREQ / I2C_FREQ;

reg	clk, arstn;
reg	i2c_start;
reg	[7-1:0]	addr;
reg	rw;
reg	[8-1:0]	data_send;
wire	i2c_done;
wire	[8-1:0]	data_recv;
wire	data_recv_done;
reg	sda_in, sda_in_en;

wire	sda, scl;

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

/*
task test_WR_2_same;

task test_WR_2_diff;

task test_RD_2_same;

task test_RD_2_diff;

task test_WR_DR;
*/

task gen_i2c_start_1;
begin
	i2c_start = 1'b0;
	@(posedge arstn)
	@(posedge clk)
		#(CLK_CYCLE*10)	i2c_start = 1'b1;
		#(CLK_CYCLE)	i2c_start = 1'b0;
end
endtask

task gen_addr_WR;
begin
	@(posedge i2c_start)
		addr = 7'b1100101;
		rw = 1'b0;
end
endtask

task gen_addr_RD;
begin
	@(posedge i2c_start)
		addr = 7'b1100101;
		rw = 1'b1;
end
endtask

task gen_data_send_1;
begin
	@(posedge i2c_start)
		data_send = 8'b01100011;
end
endtask

task gen_data_recv_1;
begin
	@(negedge i2c_start)
		#(CLK_CYCLE*DIV*11)
		sda_in_en = 1'b1;	sda_in = 1'b1;
		#(CLK_CYCLE*DIV)	sda_in = 1'b1;
		#(CLK_CYCLE*DIV)	sda_in = 1'b1;
		#(CLK_CYCLE*DIV)	sda_in = 1'b0;
		#(CLK_CYCLE*DIV)	sda_in = 1'b0;
		#(CLK_CYCLE*DIV)	sda_in = 1'b0;
		#(CLK_CYCLE*DIV)	sda_in = 1'b1;
		#(CLK_CYCLE*DIV)	sda_in = 1'b1;
		#(CLK_CYCLE*DIV)	sda_in_en = 1'b0;
end
endtask

task gen_ACK_WR_1;
begin
	sda_in_en = 1'b0;
	//sda_in = 1'b1;
	@(negedge i2c_start)
		#(CLK_CYCLE*DIV*10)	// SACK1
			sda_in_en = 1'b1;
			sda_in = 1'b0;
		#(CLK_CYCLE*DIV)
			sda_in_en = 1'b0;
			//sda_in = 1'b1;
		#(CLK_CYCLE*DIV*8)	// SACK2
			sda_in_en = 1'b1;
			sda_in = 1'b0;
		#(CLK_CYCLE*DIV)
			sda_in_en = 1'b0;
			//sda_in = 1'b1;
end
endtask

task gen_ACK_RD_1;
begin
	sda_in_en = 1'b0;
	//sda_in = 1'b1;
	@(negedge i2c_start)
		#(CLK_CYCLE*DIV*10)	// SACK1
			sda_in_en = 1'b1;
			sda_in = 1'b0;
		//#(CLK_CYCLE*DIV)
			//sda_in_en = 1'b0;
			//sda_in = 1'b1;
end
endtask

task gen_finish;
begin
	@(negedge i2c_done)
		#(CLK_CYCLE*75)	$finish;
end
endtask

task test_WR_1;
fork
	gen_i2c_start_1;
	gen_addr_WR;
	gen_data_send_1;
	gen_ACK_WR_1;
join
endtask

task test_RD_1;
fork
	gen_i2c_start_1;
	gen_addr_RD;
	gen_data_recv_1;
	gen_ACK_RD_1;
join
endtask

initial begin
	//test_WR_1;
	test_RD_1;
	gen_finish;
end

i2c_master
#(
	.CLK_FREQ(CLK_FREQ),
	.I2C_FREQ(I2C_FREQ)
)
DUT(
	.clk(clk),
	.arstn(arstn),
	.i2c_start(i2c_start),
	.addr(addr),
	.rw(rw),
	.data_send(data_send),
	.i2c_done(i2c_done),
	.data_recv(data_recv),
	.data_recv_done(data_recv_done),
	.sda(sda),
	.scl(scl)
);

endmodule
