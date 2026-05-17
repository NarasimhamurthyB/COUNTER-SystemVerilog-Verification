module s2c_counter (
    input  wire        enable,
    input  wire        clock,
    input  wire        reset,
    input  wire        power_in,
    input  wire [31:0] max_counter,

    output reg  [31:0] count,
	output wire        clock_req,
	output wire        power_req,
    output reg         overflow_int
);

assign clock_req = power_in;
assign power_req = enable;

parameter MAX_DAYS = 50;
localparam [31:0] DEFAULT_MAX = MAX_DAYS * 86400;

wire [31:0] max_value;
assign max_value = (max_counter != 0) ? max_counter : DEFAULT_MAX;
always @(posedge clock or posedge reset) begin
    if (reset) begin
        count        <= 32'd0;
        overflow_int <= 1'b0;
    end
    else if (!enable || !power_in) begin
        count        <= 32'd0;
        overflow_int <= 1'b0;
    end
    else begin
        if (count >= max_value) begin
            count        <= 32'd0;
            overflow_int <= 1'b1;
        end
        else begin
            count        <= count + 1'b1;
            overflow_int <= 1'b0;
        end
    end
end
endmodule





