`timescale 1ns/1ps

module spi_master
#(
	parameter	CLK_FREQ = 50_000_000,
				SPI_FREQ = 5_000_000,
				DATA_WIDTH = 8,
				CPOL = 0,	// 0: idle at 0; 1: idle at 1
				CPHA = 0	// ^==0: sample@pos, shift@neg; ^==1: sample@neg, shift@pos
)
(
	input	clk, arstn,
	input	[DATA_WIDTH-1:0]	data_send,
	input	spi_start,
	output	reg	sclk, csn,
	output	mosi,
	input	miso,
	output	reg	spi_done,
	output	reg	[DATA_WIDTH-1:0]	data_recv
);

// FSM
localparam	IDLE = 2'd0, LOAD = 2'd1, PROC = 2'd2, DONE = 2'd3;
reg [1:0]	current_state, next_state;

// generate sclk
localparam	FREQ_COUNT = CLK_FREQ / SPI_FREQ / 2 - 1;
localparam	COUNT_WIDTH = log2(FREQ_COUNT);
reg	clk_count_en;
reg [COUNT_WIDTH-1:0]	clk_count;
reg	sclk_reg;
wire	sclk_pos, sclk_neg;

// process data
localparam	SHIFT_WIDTH = log2(DATA_WIDTH);
reg [SHIFT_WIDTH-1:0]	shift_count, sample_count;
reg [DATA_WIDTH-1:0]	data_reg;
wire	shift_en, sample_en;

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

// sclk
always@(posedge clk or negedge arstn) begin
	if(~arstn)
		sclk <= CPOL;
	else if(CPHA == 1 && spi_start)
		sclk <= ~CPOL;
	else if(clk_count_en && clk_count == FREQ_COUNT)
		sclk <= ~sclk;
	else if(next_state == IDLE)
		sclk <= CPOL;
end

// sclk edge capture
always@(posedge clk or negedge arstn) begin
	if(~arstn) begin
		sclk_reg <= CPOL;
	end
	else begin
		if(clk_count_en) begin
			sclk_reg <= sclk;
		end
		else begin
			sclk_reg <= CPOL;
		end
	end
end

assign sclk_pos = sclk & ~sclk_reg;
assign sclk_neg = ~sclk & sclk_reg;

// data timing
generate
	case(CPHA ^ CPOL)
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
		LOAD:	next_state = PROC;
		PROC:	begin
			if(CPHA == 0)
				next_state = (shift_count == DATA_WIDTH-1 && sample_count == DATA_WIDTH && clk_count == FREQ_COUNT) ? DONE : PROC;
			else
				next_state = (shift_count == DATA_WIDTH && sample_count == DATA_WIDTH && clk_count == FREQ_COUNT) ? DONE : PROC;
		end
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
		clk_count_en <= 1'b0;
		spi_done <= 1'b0;
		csn <= 1'b1;
		shift_count <= 'd0;
		sample_count <= 'd0;
		data_reg <= 'd0;
		data_recv <= 'd0;
	end
	else begin
		case(next_state)
			IDLE:	begin
				clk_count_en <= 1'b0;
				spi_done <= 1'b0;
				csn <= 1'b1;
				shift_count <= 'd0;
				sample_count <= 'd0;
				data_reg <= 'd0;
				data_recv <= 'd0;
			end
			LOAD:	begin
				clk_count_en <= 1'b1;
				spi_done <= 1'b0;
				shift_count <= 'd0;
				sample_count <= 'd0;
				data_reg <= data_send;
				data_recv <= 'd0;
				csn <= 1'b0;
			end
			PROC:	begin
				clk_count_en <= 1'b1;
				spi_done <= 1'b0;
				if(shift_en) begin
					shift_count <= shift_count + 1'b1;
					if(CPHA == 0 || (CPHA == 1 && shift_count != 0))
						data_reg <= {data_reg[DATA_WIDTH-1-1:0], 1'b0};
				end
				if(sample_en) begin
					sample_count <= sample_count + 1'b1;
					data_recv <= {data_recv[DATA_WIDTH-1-1:0], miso};
				end
			end
			DONE:	begin
				clk_count_en <= 1'b0;
				spi_done <= 1'b1;
				csn <= 1'b1;
				shift_count <= 'd0;
				sample_count <= 'd0;
				data_reg <= 'd0;
			end
			default:	begin
				clk_count_en <= 1'b0;
				spi_done <= 1'b0;
				csn <= 1'b1;
				shift_count <= 'd0;
				sample_count <= 'd0;
				data_reg <= 'd0;
				data_recv <= 'd0;
			end
		endcase
	end
end

// mosi output
assign mosi = data_reg[DATA_WIDTH-1];

function integer log2(input integer x);
begin
	log2 = 0;
	while(x >> log2)
		log2 = log2 + 1;
end
endfunction

endmodule
