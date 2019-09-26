`timescale 1ns/1ps

module i2c_master
#(
	parameter	CLK_FREQ = 50_000_000,
				I2C_FREQ = 500_000
)
(
	input	clk, arstn,
	input	i2c_start,
	input	[7-1:0]	addr,
	input	rw,
	input	[8-1:0]	data_send,
	output	reg	i2c_done,
	output	reg	[8-1:0]	data_recv,
	output	data_recv_done,

	inout	sda,
	output	scl
);

localparam	FREQ_COUNT = CLK_FREQ / I2C_FREQ / 4 - 1;
localparam	COUNT_WIDTH = log2(FREQ_COUNT);
reg	clk_count_en, scl_en, clk_sda_reg;
reg	[COUNT_WIDTH-1:0]	clk_count;
reg	clk_div, clk_sda, clk_scl;
wire	clk_sda_neg;

// FSM
localparam	IDLE = 4'd0, START = 4'd1, CMD = 4'd2, SACK1 = 4'd3,
			WR = 4'd4, RD = 4'd5, SACK2 = 4'd6, MACK = 4'd7, STOP = 4'd8;
reg [3:0]	current_state, next_state;

reg	[3:0]	bit_count;
reg	[8-1:0]	addr_rw, data_send_reg;
reg	sda_reg;

reg i2c_start_reg, i2c_start_reg0, i2c_start_reg1;
wire	i2c_start_sda;

// clk_count_en
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		clk_count_en <= 1'b0;
	else if(i2c_start)
		clk_count_en <= 1'b1;
	else if(current_state == IDLE && next_state == IDLE && clk_sda_neg)
		clk_count_en <= 1'b0;
end

// clk_count
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		clk_count <= 'd0;
	else begin
		if(clk_count_en) begin
			if(clk_count == FREQ_COUNT)
				clk_count <= 'd0;
			else
				clk_count <= clk_count + 1'b1;
		end
		else begin
			clk_count <= 'd0;
		end
	end
end

// clk_div
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		clk_div <= 1'b0;
	else begin
		if(clk_count_en) begin
			if(clk_count == 0)
				clk_div <= ~clk_div;
		end
		else begin
			clk_div <= 1'b0;
		end
	end
end

// clk_sda @posedge clk_div
always@(posedge clk_div or negedge arstn) begin
	if(~arstn)
		clk_sda <= 1'b0;
	else begin
		if(clk_count_en)
			clk_sda <= ~clk_sda;
		else
			clk_sda <= 1'b0;
	end
end

// clk_scl @negedge clk_div
always@(negedge clk_div or negedge arstn) begin
	if(~arstn)
		clk_scl <= 1'b0;
	else begin
		if(clk_count_en)
			clk_scl <= ~clk_scl;
		else
			clk_scl <= 1'b0;
	end
end

// i2c_start_sda (CDC)
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		i2c_start_reg <= 1'b0;
	else if(i2c_start)
		i2c_start_reg <= ~i2c_start_reg;
end

always@(posedge clk_sda or negedge arstn) begin
	if(~arstn) begin
		i2c_start_reg0 <= 1'b0;
		i2c_start_reg1 <= 1'b0;
	end
	else begin
		i2c_start_reg0 <= i2c_start_reg;
		i2c_start_reg1 <= i2c_start_reg0;
	end
end

assign i2c_start_sda = i2c_start_reg0 ^ i2c_start_reg1;

// FSM "combinational"
always@(negedge clk_div) begin
	case(current_state)
		IDLE:	next_state <= i2c_start_sda ? START : IDLE;
		START:	next_state <= CMD;
		CMD:	next_state <= (bit_count == 8) ? SACK1 : CMD;
		SACK1:	begin
			if(sda == 1'b0)
				next_state <= addr_rw[0] ? RD : WR;
			else
				next_state <= STOP;
		end			
		WR:	next_state <= (bit_count == 8) ? SACK2 : WR;
		RD:	next_state <= (bit_count == 8) ? MACK : RD;
		SACK2:	begin
			if(sda == 1'b0) begin
				if(i2c_start_sda)
					next_state <= addr_rw == {addr_rw} ? WR : START;
				else
					next_state <= STOP;
			end
			else begin
				next_state <= STOP;
			end
		end
		MACK:	begin
			if(i2c_start_sda)
				next_state <= addr_rw == {addr_rw} ? RD : START;
			else
				next_state <= STOP;
		end
		STOP:	next_state <= IDLE;
		default:	next_state <= IDLE;
	endcase
end

// FSM sequential
always@(posedge clk_sda or negedge arstn) begin
	if(~arstn)
		current_state <= IDLE;
	else
		current_state <= next_state;
end

// FSM output to ctrl signals
always@(posedge clk_sda or negedge arstn) begin
	if(~arstn) begin
		bit_count <= 'd0;
		sda_reg <= 1'b1;
		data_recv <= 'd0;
	end
	else begin
		case(next_state)
			IDLE:	begin
				bit_count <= 'd0;
				sda_reg <= 1'b1;
				data_recv <= 'd0;
			end
			START:	begin
				bit_count <= 'd0;
				sda_reg <= 1'b0;
				addr_rw <= {addr, rw};
				data_recv <= 'd0;
			end
			CMD:	begin
				bit_count <= bit_count + 1'b1;
				sda_reg <= addr_rw[7-bit_count];
			end
			SACK1:	begin
				bit_count <= 'd0;
				sda_reg <= 1'b1;
				data_send_reg <= data_send;
			end
			WR:	begin
				bit_count <= bit_count + 1'b1;
				sda_reg <= data_send_reg[7-bit_count];
			end
			RD:	begin
				bit_count <= bit_count + 1'b1;
				data_recv[7-bit_count] <= sda;
			end
			SACK2:	begin
				bit_count <= 'd0;
				sda_reg <= 1'b1;
			end
			MACK:	begin
				bit_count <= 'd0;
				sda_reg <= 1'b1;
			end
			STOP:	begin
				bit_count <= 'd0;
				sda_reg <= 1'b0;
			end
			default:	begin
				bit_count <= 'd0;
				sda_reg <= 1'b1;
				data_recv <= 'd0;
			end
		endcase
	end
end

// data_recv_done
assign data_recv_done = clk_sda_neg && (current_state == MACK);

// i2c_done
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		i2c_done <= 1'b0;
	else if(current_state == STOP && clk_sda == 1'b0 && clk_scl == 1'b0 && clk_count == FREQ_COUNT)
		i2c_done <= 1'b1;
	else
		i2c_done <= 1'b0;
end

// sda
assign sda = (current_state == SACK1 || current_state == SACK2 || current_state == RD) ? 1'bz : sda_reg;

// clk_sda_neg
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		clk_sda_reg <= 1'b0;
	else
		clk_sda_reg <= clk_sda;
end

assign clk_sda_neg = clk_sda_reg & ~clk_sda;

// scl_en
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		scl_en <= 1'b0;
	else if(clk_sda_neg) begin
		if(current_state == START)
			scl_en <= 1'b1;
		else if(current_state == STOP)
			scl_en <= 1'b0;
	end
end

// scl
assign scl = (scl_en) ? clk_scl : 1'b1;

function integer log2(input integer x);
begin
	log2 = 0;
	while(x >> log2)
		log2 = log2 + 1;
end
endfunction

endmodule
