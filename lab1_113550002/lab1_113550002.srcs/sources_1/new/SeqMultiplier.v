`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/07 23:58:45
// Design Name: 
// Module Name: SeqMultiplier
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module SeqMultiplier(
    input wire clk,
    input wire enable,
    input wire [7:0] A,
    input wire [7:0] B,
    output wire [15:0] C
    );
    
    reg [7:0] mul;
    reg [15:0] product;
    reg [2:0] cnt;
    wire shift;
    
    assign C = product;
    assign shift = | (cnt ^ 3'd7);
    
    always @(posedge clk) begin
        if (!enable) begin
            mul <= B;
            product <= 15'd0;
            cnt <= 3'd0;
        end
        else begin
            mul <= mul << 1;
            product <= (product + (A & {8{mul[7]}})) << shift;
            cnt <= cnt + shift; 
        end
    end
endmodule
