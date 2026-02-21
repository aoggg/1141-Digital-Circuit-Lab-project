module Converter (
    input  [23:0] bin_in,
    output reg [3:0] bcd6,
    output reg [3:0] bcd5,
    output reg [3:0] bcd4,
    output reg [3:0] bcd3,
    output reg [3:0] bcd2,
    output reg [3:0] bcd1,
    output reg [3:0] bcd0
);

    integer i;
    reg [51:0] shift_reg;

    always @(*) begin
        shift_reg = {28'd0, bin_in};
        
        for (i = 0; i < 24; i = i + 1) begin
            
            if (shift_reg[27:24] >= 5) shift_reg[27:24] = shift_reg[27:24] + 3;
            
            if (shift_reg[31:28] >= 5) shift_reg[31:28] = shift_reg[31:28] + 3;
            
            if (shift_reg[35:32] >= 5) shift_reg[35:32] = shift_reg[35:32] + 3;
            
            if (shift_reg[39:36] >= 5) shift_reg[39:36] = shift_reg[39:36] + 3;
            
            if (shift_reg[43:40] >= 5) shift_reg[43:40] = shift_reg[43:40] + 3;

            if (shift_reg[47:44] >= 5) shift_reg[47:44] = shift_reg[47:44] + 3;

            if (shift_reg[51:48] >= 5) shift_reg[51:48] = shift_reg[51:48] + 3;

            shift_reg = shift_reg << 1;
        end
        
        bcd6 = shift_reg[51:48];
        bcd5 = shift_reg[47:44];
        bcd4 = shift_reg[43:40];
        bcd3 = shift_reg[39:36];
        bcd2 = shift_reg[35:32];
        bcd1 = shift_reg[31:28];
        bcd0 = shift_reg[27:24];
    end

endmodule