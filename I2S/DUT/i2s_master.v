`timescale 1ns/1ps

module i2s_master
#(
	parameter	CLK_DIV = 256,
				WS_DIV = 64,
				DATA_WIDTH = 24
)
(
	input	clk, arstn,
	output	reg	sck, ws,
	input	sdi,
	output	reg	sdo,
	input	[DATA_WIDTH-1:0]	data_send_left, data_send_right,
	output	reg	[DATA_WIDTH-1:0]	data_recv_left, data_recv_right
);

localparam	CLK_WIDTH = log2(CLK_DIV), WS_WIDTH = log2(WS_DIV);
reg	[CLK_WIDTH-1:0]	clk_count;
reg	[WS_WIDTH-1:0]	ws_count;
reg	[DATA_WIDTH-1:0]	data_send_left_reg, data_send_right_reg;
reg	[DATA_WIDTH-1:0]	data_recv_left_reg, data_recv_right_reg;

// generate clks
always@(posedge clk or negedge arstn) begin
	if(~arstn) begin
		clk_count <= 'd0;
		ws_count <= 'd0;
		sck <= 1'b0;
		ws <= 1'b0;
	end
	else begin
		if(clk_count < CLK_DIV/2) begin
			clk_count <= clk_count + 1'b1;
		end
		else begin
			clk_count <= 'd1;
			sck <= ~sck;
			if(ws_count < WS_DIV-1) begin
				ws_count <= ws_count + 1'b1;
			end
			else begin
				ws_count <= 'd0;
				ws <= ~ws;
			end
		end
	end
end

// generate data_recv
always@(posedge clk or negedge arstn) begin
	if(~arstn) begin
		data_recv_left_reg <= 'd0;
		data_recv_right_reg <= 'd0;
		data_recv_left <= 'd0;
		data_recv_right <= 'd0;
	end
	else begin
		if(clk_count == CLK_DIV/2) begin
			if(ws_count < WS_DIV-1) begin
				if(sck == 1'b0 && ws_count >= 2 && ws_count <= DATA_WIDTH*2+1) begin
					if(ws == 1'b1)
						data_recv_right_reg <= {data_recv_right_reg[DATA_WIDTH-2:0], sdi};
					else
						data_recv_left_reg <= {data_recv_left_reg[DATA_WIDTH-2:0], sdi};
				end
			end
			else begin
				data_recv_left <= data_recv_left_reg;
				data_recv_right <= data_recv_right_reg;
			end
		end
	end
end

// generate data_send
always@(posedge clk or negedge arstn) begin
	if(~arstn) begin
		data_send_left_reg <= data_send_left;
		data_send_right_reg <= data_send_right;
		sdo <= 1'b0;
	end
	else begin
		if(clk_count == CLK_DIV/2) begin
			if(ws_count < WS_DIV-1) begin
				if(sck == 1'b1 && ws_count <= DATA_WIDTH*2+1) begin
					if(ws == 1'b1) begin
						sdo <= data_send_right_reg[DATA_WIDTH-1];
						data_send_right_reg <= {data_send_right_reg[DATA_WIDTH-2:0], 1'b0};
					end
					else begin
						sdo <= data_send_left_reg[DATA_WIDTH-1];
						data_send_left_reg <= {data_send_left_reg[DATA_WIDTH-2:0], 1'b0};
					end
				end
			end
			else begin
				data_send_left_reg <= data_send_left;
				data_send_right_reg <= data_send_right;
			end
		end
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
