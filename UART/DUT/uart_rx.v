`timescale 1ns/1ps

module uart_rx
#(
	parameter	CLK_FREQ = 50_000_000,
				BAUD_RATE = 9600,
				PARITY = "NONE",
				DATA_WIDTH = 8
)
(
	input	clk, arstn,
	output	reg	rx_done,
	output	reg	[DATA_WIDTH-1:0]	rx_data,
	output	reg	rx_error,
	input	RXD
);

localparam	FREQ_COUNT = CLK_FREQ / BAUD_RATE / 9 - 1,
			CLK_WIDTH = log2(FREQ_COUNT),
			SHIFT_WIDTH = log2(DATA_WIDTH);
reg	[CLK_WIDTH-1:0]	clk_count, sample_count;
reg	clk_count_en;
reg	[SHIFT_WIDTH-1:0]	bit_count;
reg	sample_en;

// FSM
localparam	IDLE = 3'd0, START = 3'd1, DATA = 3'd2, PARI = 3'd3, STOP = 3'd4, DONE = 3'd5;
reg	[2:0]	current_state, next_state;
reg	RXD_r1, RXD_r2, RXD_r3;
reg	rx_start;
wire	br_clk;
reg	[1:0]	rx_sample;

// RXD negedge capture
always@(posedge clk or negedge arstn) begin
	if(~arstn) begin
		RXD_r1 <= 1'b0;
		RXD_r2 <= 1'b0;
		RXD_r3 <= 1'b0;
	end
	else begin
		RXD_r1 <= RXD;
		RXD_r2 <= RXD_r1;
		RXD_r3 <= RXD_r2;
	end
end

// rx_start @ negedge RXD
always@(*) begin
	if(current_state == IDLE || current_state == DONE)
		rx_start = ~RXD & ~RXD_r1 & RXD_r2 & RXD_r3;
	else
		rx_start = 1'b0;
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

// sample_en
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		sample_en <= 1'b0;
	else if(clk_count == 'd1)
		sample_en <= 1'b1;
	else
		sample_en <= 1'b0;
end

assign br_clk = sample_en && (sample_count == 'd8);

// sample_count
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		sample_count <= 'd0;
	else if(clk_count_en) begin
		if(br_clk)
			sample_count <= 'd0;
		else if(sample_en)
			sample_count <= sample_count + 1'b1;
	end
	else begin
		sample_count <= 'd0;
	end
end

// bit_count
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		bit_count <= 'd0;
	else if(current_state == IDLE)
		bit_count <= 'd0;
	else if(br_clk)
		bit_count <= bit_count + 1'b1;
end

// rx_sample
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		rx_sample <= 'd0;
	else if(sample_en) begin
		if(sample_count == 0)
			rx_sample <= 'd0;
		else if(sample_count == 3 || sample_count == 4 || sample_count == 5)
			rx_sample <= rx_sample + RXD;
	end
end

// FSM combinational
always@(*) begin
	case(current_state)
		IDLE:	next_state = rx_start ? START : IDLE;
		START:	next_state = (br_clk & ~rx_sample[1]) ? DATA : START;
		DATA:	begin
			if(PARITY == "ODD" || PARITY == "EVEN")
				next_state = (bit_count == DATA_WIDTH && br_clk) ? PARI : DATA;
			else
				next_state = (bit_count == DATA_WIDTH && br_clk) ? STOP : DATA;
		end
		PARI:	next_state = br_clk ? STOP : PARI;
		STOP:	next_state = br_clk ? DONE : STOP;
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
		rx_data <= 'd0;
		rx_done <= 1'b0;
		rx_error <= 1'b0;
		clk_count_en <= 1'b0;
	end
	else begin
		case(next_state)
			IDLE:	begin
				rx_data <= 'd0;
				rx_done <= 1'b0;
				rx_error <= 1'b0;
				clk_count_en <= 1'b0;
			end
			START:	begin
				rx_data <= 'd0;
				rx_done <= 1'b0;
				rx_error <= 1'b0;
				clk_count_en <= 1'b1;
			end
			DATA:	begin
				rx_done <= 1'b0;
				rx_error <= 1'b0;
				clk_count_en <= 1'b1;
				if(sample_en && sample_count == 'd6)
					rx_data <= {rx_sample[1], rx_data[DATA_WIDTH-1:1]};
			end
			PARI:	begin
				rx_done <= 1'b0;
				clk_count_en <= 1'b1;
				if(sample_count == 'd6) begin
					if(PARITY == "EVEN")
						rx_error <= (^{rx_data, rx_sample[1]} != 1'b0);
					else if(PARITY == "ODD")
						rx_error <= (^{rx_data, rx_sample[1]} != 1'b1);
					else
						rx_error <= 1'b0;
				end
				else begin
					rx_error <= 1'b0;
				end
			end
			STOP:	begin
				rx_done <= 1'b0;
				clk_count_en <= 1'b1;
				if(sample_count == 'd6) begin
					if(~rx_sample[1])	rx_error <= 1'b1;
				end
			end
			DONE:	begin
				rx_done <= 1'b1;
				clk_count_en <= 1'b0;
			end
			default:	begin
				rx_data <= 'd0;
				rx_done <= 1'b0;
				rx_error <= 1'b0;
				clk_count_en <= 1'b0;
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
