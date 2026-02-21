`timescale 1ns / 1ns
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2024/11/02 21:08:27
// Design Name: 
// Module Name: lab7_tb
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


module lab7_tb();

reg clk;
reg reset_n;
reg [3:0] usr_btn;
wire [3:0] usr_led;

wire uart_rx;
wire uart_tx;

lab7 lab7_inst(
    .clk(clk),
    .reset_n(reset_n),
    .usr_btn(usr_btn),
    .usr_led(usr_led),
    
    .uart_rx(uart_rx),
    .uart_tx(uart_tx)
);

initial begin
    clk = 1'b1;
    forever #5 clk = ~clk;
end

initial begin
    usr_btn = 4'b0000;
    reset_n = 1'b0;
    #100;
    reset_n = 1'b1;
    #1000;
    usr_btn = 4'b0010;
    #200000000;
    usr_btn = 4'b0000;
end

endmodule
