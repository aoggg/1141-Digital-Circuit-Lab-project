`timescale 1ns / 1ps
module lab4(
  input  clk,            // System clock at 100 MHz
  input  reset_n,        // System reset signal, in negative logic
  input  [3:0] usr_btn,  // Four user pushbuttons
  output [3:0] usr_led   // Four yellow LEDs
);

reg [3:0] counter;

reg [7:0] reset_btn, btn0, btn1, btn2, btn3;
wire reset_status, btn0_status, btn1_status, btn2_status, btn3_status;
reg prev_reset_status, prev_btn0_status, prev_btn1_status, prev_btn2_status, prev_btn3_status;
wire reset_press, btn0_press, btn1_press, btn2_press, btn3_press;
reg [6:0] duty_cycle[0:4], pwm_cnt;
reg [2:0] pwm;
wire light = pwm_cnt < duty_cycle[pwm];

assign usr_led = {4{light}} & (counter ^ (counter >> 1));

initial begin
    duty_cycle[0] = 7'd5;
    duty_cycle[1] = 7'd25;
    duty_cycle[2] = 7'd50;
    duty_cycle[3] = 7'd75;
    duty_cycle[4] = 7'd100;
    pwm_cnt = 0;
end

assign reset_status = | reset_btn;
assign btn0_status = & btn0;
assign btn1_status = & btn1;
assign btn2_status = & btn2;
assign btn3_status = & btn3;

assign reset_press = prev_reset_status & ~reset_status;
assign btn0_press = ~prev_btn0_status & btn0_status;
assign btn1_press = ~prev_btn1_status & btn1_status;
assign btn2_press = ~prev_btn2_status & btn2_status;
assign btn3_press = ~prev_btn3_status & btn3_status;

always @(posedge clk) begin
    reset_btn <= {reset_btn[6:0], reset_n};
    btn0 <= {btn0[6:0], usr_btn[0]};
    btn1 <= {btn1[6:0], usr_btn[1]};
    btn2 <= {btn2[6:0], usr_btn[2]};
    btn3 <= {btn3[6:0], usr_btn[3]};
    prev_reset_status <= reset_status;
    prev_btn0_status <= btn0_status;
    prev_btn1_status <= btn1_status;
    prev_btn2_status <= btn2_status;
    prev_btn3_status <= btn3_status;
end

always @(posedge clk or posedge reset_press) begin
    if (reset_press) begin
        counter <= 0;
        pwm <= 0;
    end
    else if (btn0_press) counter <= counter == 0 ? 0 : counter - 1;
    else if (btn1_press) counter <= counter == 15 ? 15 : counter + 1;
    else if (btn2_press) pwm <= pwm == 4 ? 4 : pwm + 1;
    else if (btn3_press) pwm <= pwm == 0 ? 0 : pwm - 1;
end

always @(posedge clk) begin
    if (pwm_cnt == 7'd99) pwm_cnt = 0;
    else pwm_cnt = pwm_cnt + 1;
end

endmodule