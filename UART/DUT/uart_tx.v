`timescale 1ns/1ps

module uart_tx
#(
	parameter	CLK_FREQ = 50_000_000,
				BAUD_RATE = 9600,
				PARITY = "NONE",
				DATA_WIDTH = 8
)
(
	input	clk, arstn,
	input	tx_start,
	output	reg	tx_done,
	input	[DATA_WIDTH-1:0]	tx_data,
	output	reg	TXD
);

localparam	FREQ_COUNT = CLK_FREQ / BAUD_RATE - 1,
			CLK_WIDTH = log2(FREQ_COUNT),
			SHIFT_WIDTH = log2(DATA_WIDTH);
reg	[CLK_WIDTH-1:0]	clk_count;
reg	clk_count_en;
reg	[SHIFT_WIDTH-1:0]	bit_count;
reg	[DATA_WIDTH-1:0]	data_reg;
reg	shift_en;
reg	even_parity;

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

// shift_en
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		shift_en <= 1'b0;
	else if(clk_count == 'd1)
		shift_en <= 1'b1;
	else
		shift_en <= 1'b0;
end

// FSM
localparam	IDLE = 3'd0, READY = 3'd1, START = 3'd2, SHIFT = 3'd3, PARI = 3'd4, STOP = 3'd5, DONE = 3'd6;
reg	[2:0]	current_state, next_state;

// bit_count
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		bit_count <= 'd0;
	else if(current_state == SHIFT && shift_en) begin
		if(bit_count == DATA_WIDTH-1)
			bit_count <= 'd0;
		else
			bit_count <= bit_count + 1'b1;
	end
end

// FSM combinational
always@(*) begin
	case(current_state)
		IDLE:	next_state = tx_start ? READY : IDLE;
		READY:	next_state = shift_en ? START : READY;
		START:	next_state = shift_en ? SHIFT : START;
		SHIFT:	next_state = (shift_en && bit_count == DATA_WIDTH-1) ? PARI : SHIFT;
		PARI:	next_state = shift_en ? STOP : PARI;
		STOP:	next_state = shift_en ? DONE : STOP;
		DONE:	next_state = IDLE;
		default:	next_state = IDLE;
	endcase
end

// FSM sequential
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		current_state <= IDLE;
	else
		current_state <= next_state;
end

// FSM output to ctrl signals
always@(posedge clk or negedge arstn) begin
	if(~arstn) begin
		TXD <= 1'b1;
		data_reg <= 'd0;
		tx_done <= 1'b0;
		clk_count_en <= 1'b0;
		even_parity <= 1'b0;
	end
	else begin
		case(next_state)
			IDLE:	begin
				TXD <= 1'b1;
				data_reg <= 'd0;
				tx_done <= 1'b0;
				clk_count_en <= 1'b0;
			end
			READY:	begin
				TXD <= 1'b1;
				data_reg <= 'd0;
				tx_done <= 1'b0;
				clk_count_en <= 1'b1;
			end
			START:	begin
				TXD <= 1'b0;
				data_reg <= tx_data;
				tx_done <= 1'b0;
				clk_count_en <= 1'b1;
				even_parity <= ^tx_data;
			end
			SHIFT:	begin
				tx_done <= 1'b0;
				if(shift_en) begin
					data_reg <= {1'b0, data_reg[DATA_WIDTH-1:1]};
					TXD <= data_reg[0];
				end
			end
			PARI:	begin
				tx_done <= 1'b0;
				if(PARITY == "NONE")	TXD <= 1'b1;
				else if(PARITY == "ODD")	TXD <= ~even_parity;
				else if(PARITY == "EVEN")	TXD <= even_parity;
				else	TXD <= 1'b1;
			end
			STOP:	begin
				TXD <= 1'b1;
			end
			DONE:	begin
				TXD <= 1'b1;
				tx_done <= 1'b1;
				clk_count_en <= 1'b0;
			end
			default:	begin
				TXD <= 1'b1;
				data_reg <= 'd0;
				tx_done <= 1'b0;
				clk_count_en <= 1'b0;
				even_parity <= 1'b0;
			end
		endcase
	end
end

function integer log2(input integer v);
	begin
		log2=0;
		while(v>>log2) 
			log2=log2+1;
	end
endfunction

endmodule
