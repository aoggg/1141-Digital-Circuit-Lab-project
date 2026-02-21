`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of CS, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2018/10/10 16:10:38
// Design Name: UART I/O example for Arty
// Module Name: lab6
// Project Name: 
// Target Devices: Xilinx FPGA @ 100MHz
// Tool Versions: 
// Description: 
// 
// The parameters for the UART controller are 9600 baudrate, 8-N-1-N
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab6(
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,
  input  uart_rx,
  output uart_tx
);

    localparam [2:0] S_MAIN_INIT = 0, S_MAIN_PROMPT1 = 1,
                     S_MAIN_READ_NUM1 = 2, S_MAIN_PROMPT2 = 3,
                     S_MAIN_READ_NUM2 = 4, S_MAIN_REPLY = 5,
                     S_MAIN_ERR = 6;
    localparam [1:0] S_UART_IDLE = 0, S_UART_WAIT = 1,
                     S_UART_SEND = 2, S_UART_INCR = 3;
    localparam INIT_DELAY = 100_000; // 1 msec @ 100 MHz
    localparam PROMPT1_STR = 0;  // starting index of the prompt message
    localparam PROMPT1_LEN = 35; // length of the prompt message
    localparam PROMPT2_STR = 35;
    localparam PROMPT2_LEN = 36;
    localparam REPLY_STR  = PROMPT1_LEN + PROMPT2_LEN; // starting index of the hello message
    localparam REPLY_LEN  = 37; // length of the hello message
    localparam ERR_STR = PROMPT1_LEN + PROMPT2_LEN + REPLY_LEN;
    localparam ERR_LEN = 27;
    localparam MEM_SIZE   = PROMPT1_LEN+PROMPT2_LEN+REPLY_LEN+ERR_LEN;

// declare system variables
wire enter_pressed;
wire print_enable, print_done, cal_done;
reg [$clog2(MEM_SIZE):0] send_counter;
reg [2:0] P, P_next;
reg [1:0] Q, Q_next;
reg [$clog2(INIT_DELAY):0] init_counter;
reg [7:0] data[0:MEM_SIZE-1];
reg [0:PROMPT1_LEN*8-1] prompt1 = { "\015\012Enter the first decimal number: ", 8'h00 };
reg [0:PROMPT2_LEN * 8 - 1] prompt2 = { "\015\012Enter the second decimal number: ", 8'h00 };
reg [0:REPLY_LEN*8-1]  reply = { "\015\012The integer quotient is: 0x0000.\015\012", 8'h00 };
reg [0:ERR_LEN * 8 - 1] error = { "\015\012ERROR! DIVIDE BY ZERO!\015\012", 8'h00 };
reg [15:0] num_reg1, num_reg2, num_result = 0;  // The key-in number register
reg [2:0]  key_cnt;  // The key strokes counter

// declare UART signals
wire transmit;
wire received;
wire [7:0] rx_byte;
reg  [7:0] rx_temp;  // if recevied is true, rx_temp latches rx_byte for ONLY ONE CLOCK CYCLE!
wire [7:0] tx_byte;
wire [7:0] echo_key; // keystrokes to be echoed to the terminal
wire is_num_key;
wire is_receiving;
wire is_transmitting;
wire recv_error;
reg start_div = 0;

/* The UART device takes a 100MHz clock to handle I/O at 9600 baudrate */
uart uart(
  .clk(clk),
  .rst(~reset_n),
  .rx(uart_rx),
  .tx(uart_tx),
  .transmit(transmit),
  .tx_byte(tx_byte),
  .received(received),
  .rx_byte(rx_byte),
  .is_receiving(is_receiving),
  .is_transmitting(is_transmitting),
  .recv_error(recv_error)
);

// Initializes some strings.
// System Verilog has an easier way to initialize an array,
// but we are using Verilog 2001 :(
//
integer idx;

always @(posedge clk) begin
  if (~reset_n) begin
    for (idx = 0; idx < PROMPT1_LEN; idx = idx + 1) data[idx] = prompt1[idx*8 +: 8];
    for (idx = 0; idx < PROMPT2_LEN; idx = idx + 1) data[idx + PROMPT2_STR] = prompt2[idx * 8 +: 8];
    for (idx = 0; idx < REPLY_LEN; idx = idx + 1) data[idx + REPLY_STR] = reply[idx*8 +: 8];
    for (idx = 0; idx < ERR_LEN; idx = idx + 1) data[idx + ERR_STR] = error[idx * 8 +: 8];
  end
  else if (P == S_MAIN_REPLY && cal_done == 1) begin
    data[REPLY_STR+29] <= ((num_result[15:12] > 9)? "7" : "0") + num_result[15:12];
    data[REPLY_STR+30] <= ((num_result[11: 8] > 9)? "7" : "0") + num_result[11: 8];
    data[REPLY_STR+31] <= ((num_result[ 7: 4] > 9)? "7" : "0") + num_result[ 7: 4];
    data[REPLY_STR+32] <= ((num_result[ 3: 0] > 9)? "7" : "0") + num_result[ 3: 0];
  end
end

// Combinational I/O logics of the top-level system
assign usr_led = usr_btn;
assign enter_pressed = (rx_temp == 8'h0D); // don't use rx_byte here!

// ------------------------------------------------------------------------
// Main FSM that reads the UART input and triggers
// the output of the string "Hello, World!".
always @(posedge clk) begin
  if (~reset_n) P <= S_MAIN_INIT;
  else P <= P_next;
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT: // Wait for initial delay of the circuit.
	   if (init_counter < INIT_DELAY) P_next = S_MAIN_INIT;
		else P_next = S_MAIN_PROMPT1;
    S_MAIN_PROMPT1: // Print the prompt message.
      if (print_done) P_next = S_MAIN_READ_NUM1;
      else P_next = S_MAIN_PROMPT1;
    S_MAIN_READ_NUM1: // wait for <Enter> key.
      if (enter_pressed) P_next = S_MAIN_PROMPT2;
      else P_next = S_MAIN_READ_NUM1;
    S_MAIN_PROMPT2:
      if (print_done) P_next = S_MAIN_READ_NUM2;
      else P_next = S_MAIN_PROMPT2;
    S_MAIN_READ_NUM2:
      if (enter_pressed) begin
        if (num_reg2 == 0) P_next = S_MAIN_ERR;
        else P_next = S_MAIN_REPLY;
      end
      else P_next = S_MAIN_READ_NUM2;
    S_MAIN_REPLY: // Print the hello message.
      if (print_done && cal_done) P_next = S_MAIN_INIT;
      else P_next = S_MAIN_REPLY;
    S_MAIN_ERR:
      if (print_done) P_next = S_MAIN_INIT;
      else P_next = S_MAIN_ERR;
  endcase
end

// FSM output logics: print string control signals.
assign print_enable = (P != S_MAIN_PROMPT1 && P_next == S_MAIN_PROMPT1) ||
                  (P == S_MAIN_READ_NUM1 && P_next == S_MAIN_PROMPT2) ||
                  (P == S_MAIN_READ_NUM2 && P_next == S_MAIN_REPLY) || 
                  (P == S_MAIN_READ_NUM2 && P_next == S_MAIN_ERR);
assign print_done = (tx_byte == 8'h0);

// Initialization counter.
always @(posedge clk) begin
  if (P == S_MAIN_INIT) init_counter <= init_counter + 1;
  else init_counter <= 0;
end
// End of the FSM of the print string controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the controller that sends a string to the UART.

always @(posedge clk) begin
  if (~reset_n) Q <= S_UART_IDLE;
  else Q <= Q_next;
end

always @(*) begin // FSM next-state logic
  case (Q)
    S_UART_IDLE: // wait for the print_string flag
      if (print_enable) Q_next = S_UART_WAIT;
      else Q_next = S_UART_IDLE;
    S_UART_WAIT: // wait for the transmission of current data byte begins
      if (is_transmitting == 1) Q_next = S_UART_SEND;
      else Q_next = S_UART_WAIT;
    S_UART_SEND: // wait for the transmission of current data byte finishes
      if (is_transmitting == 0) Q_next = S_UART_INCR; // transmit next character
      else Q_next = S_UART_SEND;
    S_UART_INCR:
      if (tx_byte == 8'h0) Q_next = S_UART_IDLE; // string transmission ends
      else Q_next = S_UART_WAIT;
  endcase
end

// FSM output logics: UART transmission control signals
assign transmit = (Q_next == S_UART_WAIT ||
                  ((P == S_MAIN_READ_NUM1 || P == S_MAIN_READ_NUM2) && received) ||
                   print_enable);
assign is_num_key = (rx_byte > 8'h2F) && (rx_byte < 8'h3A) && (key_cnt < 5);
assign echo_key = (is_num_key || rx_byte == 8'h0D)? rx_byte : 0;
assign tx_byte  = ((P == S_MAIN_READ_NUM1 || P == S_MAIN_READ_NUM2) && received)? echo_key : data[send_counter];

// UART send_counter control circuit
always @(posedge clk) begin
  case (P_next)
    S_MAIN_INIT: send_counter <= PROMPT1_STR;
    S_MAIN_READ_NUM1: send_counter <= PROMPT2_STR;
    S_MAIN_READ_NUM2: begin
        if (num_reg2 == 0) send_counter <= ERR_STR;
        else send_counter <= REPLY_STR;
    end
    default: send_counter <= send_counter + (Q_next == S_UART_INCR);
  endcase
end
// End of the FSM of the print string controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// UART input logic
// Decimal number input will be saved in num1 or num2.
always @(posedge clk) begin
  if (~reset_n || (P == S_MAIN_INIT || P == S_MAIN_PROMPT1 || P == S_MAIN_PROMPT2)) key_cnt <= 0;
  else if (received && is_num_key) key_cnt <= key_cnt + 1;
end

always @(posedge clk)begin
  if (~reset_n) begin
    num_reg1 <= 0;
    num_reg2 <= 0;
  end
  else if (P == S_MAIN_INIT) begin
    num_reg1 <= 0;
    num_reg2 <= 0;
  end
  else if (received && is_num_key && P == S_MAIN_READ_NUM1) num_reg1 <= (num_reg1 * 10) + (rx_byte - 48);
  else if (received && is_num_key && P == S_MAIN_READ_NUM2) num_reg2 <= (num_reg2 * 10) + (rx_byte - 48);
end

// The following logic stores the UART input in a temporary buffer.
// The input character will stay in the buffer for one clock cycle.
always @(posedge clk) begin
  rx_temp <= (received)? rx_byte : 8'h0;
end
// End of the UART input logic
// ------------------------------------------------------------------------

// Start calculate the nand

reg [4:0] cnt = 16;
reg [15:0] R = 0;

assign cal_done = cnt == 0;

always @(posedge clk) begin
    if (!reset_n) begin
        cnt <= 16;
        R <= 0;
        num_result <= 0;
    end
    else if (P_next == S_MAIN_PROMPT1) begin
        cnt <= 16;
        R <= 0;
        num_result <= 0;
    end
    else if (P == S_MAIN_REPLY && !cal_done) begin
        R = R << 1;
        R[0] = num_reg1[cnt - 1];
        if (R >= num_reg2) begin
            R = R - num_reg2;
            num_result[cnt - 1] = 1;
        end
        else num_result[cnt - 1] = 0;
        cnt = cnt - 1;
    end
end

endmodule
