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
	output	i2c_done,
	output	reg	[8-1:0]	data_recv,

	inout	sda,
	output	scl
);

localparam	FREQ_COUNT = CLK_FREQ / I2C_FREQ / 4 - 1;
localparam	COUNT_WIDTH = log2(FREQ_COUNT);
reg	clk_count_en;
reg	[COUNT_WIDTH-1:0]	clk_count;
reg	clk_div, clk_sda, clk_scl;

// clk_count_en
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		clk_count_en <= 1'b0;
	else if(i2c_start)
		clk_count_en <= 1'b1;
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
	else
		clk_sda <= ~clk_sda;
end

// clk_scl @negedge clk_div
always@(negedge clk_div or negedge arstn) begin
	if(~arstn)
		clk_scl <= 1'b0;
	else
		clk_scl <= ~clk_scl;
end

// i2c_start_sda
reg i2c_start_reg, i2c_start_reg0, i2c_start_reg1;
wire	i2c_start_sda;
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		i2c_start_reg <= 1'b0;
	else if(i2c_start)
		i2c_start_reg <= 1'b1;
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

assign i2c_start_sda = i2c_start_reg0 & ~i2c_start_reg1;

// FSM
localparam	IDLE = 4'd0, START = 4'd1, CMD = 4'd2, SACK1 = 4'd3,
			WR = 4'd4, RD = 4'd5, SACK2 = 4'd6, MACK = 4'd7, STOP = 4'd8;
reg [3:0]	current_state, next_state;

reg	[3:0]	bit_count;
reg	[8-1:0]	addr_rw, data_send_reg;
reg	sda_reg, i2c_done_sda, i2c_done_sda_reg;

// FSM combinational
always@(*) begin
	case(current_state)
		IDLE:	next_state = i2c_start_sda ? START : IDLE;
		START:	next_state = CMD;
		CMD:	next_state = (bit_count == 8) ? SACK1 : CMD;
		SACK1:	begin
			if(sda == 1'b0) begin
				next_state = addr_rw[0] ? RD : WR;
			end
			else begin
				next_state = STOP;
			end
		end
		WR:	next_state = (bit_count == 8) ? SACK2 : WR;
		RD:	next_state = (bit_count == 8) ? MACK : RD;
		SACK2:	begin
			if(sda == 1'b0) begin
				if(i2c_start_sda)
					next_state = addr_rw == {addr_rw} ? WR : START;
				else
					next_state = STOP;
			end
			else begin
				next_state = STOP;
			end
		end
		MACK:	begin
			if(i2c_start_sda)
				next_state = addr_rw == {addr_rw} ? RD : START;
			else
				next_state = STOP;
		end
		STOP:	next_state = IDLE;
		default:	next_state = IDLE;
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
		i2c_done_sda <= 1'b0;
		bit_count <= 'd0;
		sda_reg <= 1'b1;
		data_recv <= 'd0;
	end
	else begin
		case(next_state)
			IDLE:	begin
				i2c_done_sda <= 1'b0;
				bit_count <= 'd0;
				sda_reg <= 1'b1;
			end
			START:	begin
				i2c_done_sda <= 1'b0;
				bit_count <= 'd0;
				sda_reg <= 1'b0;
				addr_rw <= {addr, rw};
				data_recv <= 'd0;
			end
			CMD:	begin
				i2c_done_sda <= 1'b0;
				bit_count <= bit_count + 1'b1;
				sda_reg <= addr_rw[7-bit_count];
			end
			SACK1:	begin
				i2c_done_sda <= 1'b0;
				bit_count <= 'd0;
				sda_reg <= 1'b1;
				data_send_reg <= data_send;
			end
			WR:	begin
				i2c_done_sda <= 1'b0;
				bit_count <= bit_count + 1'b1;
				sda_reg <= data_send_reg[7-bit_count];
			end
			RD:	begin
				i2c_done_sda <= 1'b0;
				bit_count <= bit_count + 1'b1;
				data_recv[7-bit_count] <= sda;
			end
			SACK2:	begin
				i2c_done_sda <= 1'b0;
				bit_count <= 'd0;
				sda_reg <= 1'b1;
			end
			MACK:	begin
				i2c_done_sda <= 1'b0;
				bit_count <= 'd0;
				sda_reg <= 1'b1;
			end
			STOP:	begin
				i2c_done_sda <= 1'b1;
				bit_count <= 'd0;
				sda_reg <= 1'b0;
			end
			default:	begin
				i2c_done_sda <= 1'b0;
				bit_count <= 'd0;
				sda_reg <= 1'b1;
				data_recv <= 'd0;
			end
		endcase
	end
end

// i2c_done
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		i2c_done_sda_reg <= 1'b0;
	else
		i2c_done_sda_reg <= i2c_done_sda;
end

assign i2c_done = ~i2c_done_sda & i2c_done_sda_reg; // negedge i2c_done

// sda
assign sda = (current_state == SACK1 || current_state == SACK2 || current_state == RD) ? 1'bz : sda_reg;

// scl
reg	scl_en, clk_sda_reg;
wire	clk_sda_neg;

always@(posedge clk or negedge arstn) begin
	if(~arstn)
		clk_sda_reg <= 1'b0;
	else
		clk_sda_reg <= clk_sda;
end

assign clk_sda_neg = clk_sda_reg & ~clk_sda;

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

assign scl = (scl_en) ? clk_scl : 1'b1;

function integer log2(input integer x);
begin
	log2 = 0;
	while(x >> log2)
		log2 = log2 + 1;
end
endfunction

endmodule
