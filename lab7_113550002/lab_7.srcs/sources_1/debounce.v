`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date:    09:43:16 10/20/2015 
// Design Name: 
// Module Name:    debounce
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module debounce(input clk, input btn_input, output btn_output);

//parameter DEBOUNCE_PERIOD = 2_000_000; /* 20 msec = (100,000,000*0.02) ticks @100MHz */
parameter DEBOUNCE_PERIOD = 20_000; /* 0.2 msec = (100,000,000*0.0002) ticks @100MHz */

reg [20:0] counter;

initial counter = 0;

//assign btn_output = (counter == DEBOUNCE_PERIOD); // wrong
reg sample_output;
assign btn_output = sample_output;

initial sample_output = 0;

always@(posedge clk) begin
  if (counter == DEBOUNCE_PERIOD) begin
    sample_output <= btn_input;
    counter <= 0;
  end else begin
    sample_output <= sample_output;
    counter <= counter + 1;
  end
end

endmodule
