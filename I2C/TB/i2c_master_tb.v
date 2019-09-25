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
wire	sda, scl;

reg	sda_in;

// clk
initial begin
	clk = 0;
	forever	#(CLK_CYCLE/2)	clk = ~clk;
end

// arstn
initial begin
	arstn = 1'b0;
	#(CLK_CYCLE*70)	arstn = 1'b1;
end

task gen_i2c_start;
begin
	i2c_start = 1'b0;
	@(posedge arstn)
		#(CLK_CYCLE*3/2) i2c_start = 1'b1;
		#(CLK_CYCLE) i2c_start = 1'b0;
end
endtask

task gen_data_send;
begin
	addr = 'd0;
	rw = 1'b0;
	data_send = 'd0;
	@(posedge arstn)
		addr = 7'b1100101;
		rw = 1'b0;
		data_send = 8'b01100011;
	@(negedge i2c_done)
		#(CLK_CYCLE*70) $finish;
end
endtask

task gen_sack1;
begin
	sda_in = 1'b1;
	@(negedge i2c_start)
		#(CLK_CYCLE*DIV*10-CLK_CYCLE)	sda_in = 1'b0;
		#(CLK_CYCLE*DIV+CLK_CYCLE)	sda_in = 1'b1;
		#(CLK_CYCLE*DIV*8)	sda_in = 1'b0;
		#(CLK_CYCLE*DIV)	sda_in = 1'b1;

end
endtask

assign sda = ~sda_in ? sda_in : 1'bz;

initial fork
	gen_data_send;
	gen_i2c_start;
	gen_sack1;
join

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
	.sda(sda),
	.scl(scl)
);

endmodule
