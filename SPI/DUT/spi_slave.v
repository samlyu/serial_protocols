`timescale 1ns/1ps

module spi_slave
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
	input	sclk, csn, mosi,
	output	miso,
	output	reg	spi_done,
	output	reg	[DATA_WIDTH-1:0]	data_recv
);

// FSM
localparam	IDLE = 2'd0, LOAD = 2'd1, PROC = 2'd2, DONE = 2'd3;
reg [1:0]	current_state, next_state;

// capture sclk
reg		sclk_reg, csn_reg;
wire	sclk_pos, sclk_neg, csn_neg;

// process data
localparam	SHIFT_WIDTH = log2(DATA_WIDTH);
reg [SHIFT_WIDTH-1:0]	shift_count, sample_count;
reg [DATA_WIDTH-1:0]	data_reg;
wire	shift_en, sample_en;



// sclk edge capture
always@(posedge clk or negedge arstn) begin
	if(~arstn) begin
		sclk_reg <= CPOL;
	end
	else begin
		sclk_reg <= sclk;
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

// csn edge capture: spi start signal
always@(posedge clk or negedge arstn) begin
	if(~arstn) begin
		csn_reg <= 1'b1;
	end
	else begin
		csn_reg <= csn;
	end
end

assign csn_neg = csn_reg & ~csn;

// FSM combinational
always@(*) begin
	case(current_state)
		IDLE:	next_state = csn_neg ? LOAD : IDLE;
		LOAD:	next_state = PROC;
		PROC:	next_state = (shift_count == DATA_WIDTH && sample_count == DATA_WIDTH) ? DONE : PROC;
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
		spi_done <= 1'b0;
		shift_count <= 'd0;
		sample_count <= 'd0;
		data_reg <= 'd0;
		data_recv <= 'd0;
	end
	else begin
		case(next_state)
			IDLE:	begin
				spi_done <= 1'b0;
				shift_count <= 'd0;
				sample_count <= 'd0;
				data_reg <= 'd0;
				data_recv <= 'd0;
			end
			LOAD:	begin
				spi_done <= 1'b0;
				shift_count <= 'd0;
				sample_count <= 'd0;
				data_reg <= data_send;
				data_recv <= 'd0;
			end
			PROC:	begin
				spi_done <= 1'b0;
				if(~csn) begin
					if(shift_en) begin
						shift_count <= shift_count + 1'b1;
						data_reg <= {data_reg[DATA_WIDTH-1-1:0], 1'b0};
					end
					if(sample_en) begin
						sample_count <= sample_count + 1'b1;
						data_recv <= {data_recv[DATA_WIDTH-1-1:0], mosi};
					end
				end
			end
			DONE:	begin
				spi_done <= 1'b1;
				shift_count <= 'd0;
				sample_count <= 'd0;
				data_reg <= 'd0;
				// data_recv <= 'd0;
			end
			default:	begin
				spi_done <= 1'b0;
				shift_count <= 'd0;
				sample_count <= 'd0;
				data_reg <= 'd0;
				data_recv <= 'd0;
			end
		endcase
	end
end

// miso output
assign miso = data_reg[DATA_WIDTH-1];

function integer log2(input integer x);
begin
	log2 = 0;
	while(x >> log2)
		log2 = log2 + 1;
end
endfunction

endmodule























// miso output
// always@(posedge clk) begin
// 	if(~arstn)
// 		data_reg <= 'd0;
// 	else if(csn_neg)
// 		data_reg <= data_send;
// 	else if(~csn & shift_en)
// 		data_reg <= {data_reg[DATA_WIDTH-1-1:0], 1'b0};
// end

// assign miso = (~csn) ? data_reg[DATA_WIDTH-1] : 1'b0;

// mosi input
// always@(posedge clk) begin
// 	if(~arstn)
// 		data_recv <= 'd0;
// 	else if(~csn & sample_en)
// 		data_recv <= {data_recv[DATA_WIDTH-1-1:0], mosi};
// end

// always@(posedge clk) begin
// 	if(~arstn)
// 		sample_count <= 'd0;
// 	else if(csn)
// 		sample_count <= 'd0;
// 	else if(~csn & sample_en) begin
// 		if(sample_count == DATA_WIDTH)
// 			sample_count <= 'd1;
// 		else
// 			sample_count <= sample_count + 1'b1;
// 	end
// end

// assign spi_done = (sample_count == DATA_WIDTH);


