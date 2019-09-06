`timescale 1ns/1ps

module spi_master
#(
	parameter	CLK_FREQ = 50_000_000,
				SPI_FREQ = 5_000_000,
				DATA_WIDTH = 8,
				CPOL = 0,	// 0: idle at 0; 1: idle at 1
				CPHA = 0	// 0: sample@pos, shift@neg; 1: sample@neg, shift@pos 
)
(
	input	clk, rstn,
	input	[DATA_WIDTH-1:0]	data_send,
	input	spi_start,
	output	reg	sclk, csn,
	output	mosi,
	input	miso,
	output	reg	spi_done,
	output	reg	[DATA_WIDTH-1:0]	data_recv
);

// FSM
localparam	IDLE = 2'd0, LOAD = 2'd1, SHIFT = 2'd2, DONE = 2'd3;
reg [1:0]	current_state, next_state;

// Generate sclk
localparam	FREQ_COUNT = CLK_FREQ / SPI_FREQ - 1;
localparam	COUNT_WIDTH = log2(FREQ_COUNT);
reg	clk_count_en;
reg [COUNT_WIDTH-1:0]	clk_count;
reg	[1:0]	sclk_reg;
wire	sclk_pos, sclk_neg;

// Process data
localparam	SHIFT_WIDTH = log2(DATA_WIDTH);
reg [SHIFT_WIDTH-1:0]	shift_count;
reg [DATA_WIDTH-1:0]	data_reg;
wire	shift_en, sample_en;

// clk_count
always@(posedge clk) begin
	if(~rstn)
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

// sclk
always@(posedge clk) begin
	if(~rstn)
		sclk <= CPOL;
	else begin
		if(clk_count_en) begin
			if(clk_count == FREQ_COUNT)
				sclk <= ~sclk;
		end
		else begin
			sclk <= CPOL;
		end
	end
end

// sclk edge capture
always@(posedge clk) begin
	if(~rstn) begin
		sclk_reg[0] <= CPOL;
		sclk_reg[1] <= CPOL;
	end
	else if(clk_count_en) begin
		sclk_reg[0] <= sclk;
		sclk_reg[1] <= sclk_reg[0];
	end
end

assign sclk_pos = sclk_reg[0] & ~sclk_reg[1];
assign sclk_neg = ~sclk_reg[0] & sclk_reg[1];

// data timing
generate
	case(CPHA)
		0:	begin
			assign sample_en = sclk_pos;
			assign shift_en = sclk_neg;
		end
		1:	begin
			assign sample_en = sclk_neg;
			assign shift_en = sclk_pos;
		end
		default:	begin // mode 0 
			assign sample_en = sclk_pos;
			assign shift_en = sclk_neg;
		end
	endcase
endgenerate

// FSM combinational
always@(*) begin
	case(current_state)
		IDLE:	next_state = spi_start ? LOAD : IDLE;
		LOAD:	next_state = SHIFT;
		SHIFT:	next_state = (shift_count == DATA_WIDTH) ? DONE : SHIFT;
		DONE:	next_state = IDLE;
		default:	next_state = IDLE;
	endcase
end
// FSM sequential
always@(posedge clk) begin
	if(~rstn)
		current_state <= IDLE;
	else
		current_state <= next_state;
end
// FSM output to ctrl signals
always@(posedge clk) begin
	if(~rstn) begin
		clk_count_en <= 1'b0;
		spi_done <= 1'b0;
		csn <= 1'b1;
		shift_count <= 'd0;
		data_reg <= 'd0;
	end
	else begin
		case(next_state)
			IDLE:	begin
				clk_count_en <= 1'b0;
				spi_done <= 1'b0;
				csn <= 1'b1;
				shift_count <= 'd0;
				data_reg <= 'd0;
			end
			LOAD:	begin
				clk_count_en <= 1'b1;
				spi_done <= 1'b0;
				csn <= 1'b0;
				shift_count <= 'd0;
				data_reg <= data_send;
			end
			SHIFT:	begin
				clk_count_en <= 1'b1;
				spi_done <= 1'b0;
				csn <= 1'b0;
				if(shift_en) begin
					shift_count <= shift_count + 1'b1;
					data_reg <= {data_reg[DATA_WIDTH-1-1:0], 1'b0};
				end
			end
			DONE:	begin
				clk_count_en <= 1'b0;
				spi_done <= 1'b1;
				csn <= 1'b1;
				shift_count <= 'd0;
				data_reg <= 'd0;
			end
			default:	begin
				clk_count_en <= 1'b0;
				spi_done <= 1'b0;
				csn <= 1'b1;
				shift_count <= 'd0;
				data_reg <= 'd0;
			end
		endcase
	end
end

// mosi output
assign mosi = data_reg[DATA_WIDTH-1];

// miso input
always@(posedge clk) begin
	if(~rstn)
		data_recv <= 'd0;
	else begin
		if(sample_en)
			data_recv <= {data_recv[DATA_WIDTH-1:0],miso};
	end
end

function integer log2(input integer x);
begin
	log2 = 0;
	while(x >> log2)
		log2 = log2 + 1;
end
endfunction

endmodule