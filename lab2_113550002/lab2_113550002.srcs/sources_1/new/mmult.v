`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/09/14 22:18:42
// Design Name: 
// Module Name: mmult
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


module mmult(
    input clk,
    input reset_n,
    input enable,
    
    input [0:9*8-1] A_mat,
    input [0:9*8-1] B_mat,
    
    output valid,
    
    output reg [0:9*18-1] C_mat
    );
    reg [2:0] cnt;
    integer i;
    assign valid = (cnt == 3);
    always @(posedge clk) begin
        if (!reset_n || !enable) begin
            C_mat <= 0;
            cnt <= 0;
        end
        else if (enable && cnt < 3) begin
            for (i = 0; i < 3; i = i + 1) begin
                C_mat[(cnt*3+i)*18+:18] <= A_mat[(cnt*3+0)*8+:8] * B_mat[(0*3+i)*8+:8] + A_mat[(cnt*3+1)*8+:8] * B_mat[(1*3+i)*8+:8] + A_mat[(cnt*3+2)*8+:8] * B_mat[(2*3+i)*8+:8];
            end
            if (cnt != 3) cnt <= cnt + 1;
        end
    end
endmodule
