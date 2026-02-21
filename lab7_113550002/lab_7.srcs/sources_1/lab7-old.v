`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2018/11/01 11:16:50
// Design Name: 
// Module Name: lab7
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: This is a sample circuit to show you how to initialize an SRAM
//              with a pre-defined data file. Hit BTN0/BTN1 let you browse
//              through the data.
// 
// Dependencies: LCD_module, debounce
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab7(
  // General system I/O ports
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output reg [3:0] usr_led,

  // 1602 LCD Module Interface
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D,
  
  // UART
  input  uart_rx,
  output uart_tx
);

wire output_ready;
reg [17:0] result [0:24];

localparam [1:0] 
    S_MAIN_ADDR = 2'b00,
    S_MAIN_READ = 2'b01,
    S_MAIN_SHOW = 2'b10,
    S_MAIN_WAIT = 2'b11;

// declare system variables
wire [3:0]  btn_level, btn_pressed;
reg  [3:0]  prev_btn_level;
reg  [1:0]  P, P_next;
reg  [9:0]  user_addr;
reg  [7:0]  user_data;

wire [9:0]  proc_addr;

reg  [127:0] row_A, row_B;

// declare SRAM control signals
wire [9:0] sram_addr;
wire [7:0] data_in;
wire [7:0] data_out;
wire       sram_we, sram_en;

wire       proc_en;
wire       proc_write;
wire [7:0] proc_write_data;

LCD_module lcd0( 
  .clk(clk),
  .reset(~reset_n),
  .row_A(row_A),
  .row_B(row_B),
  .LCD_E(LCD_E),
  .LCD_RS(LCD_RS),
  .LCD_RW(LCD_RW),
  .LCD_D(LCD_D)
);
  
debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[0]),
  .btn_output(btn_level[0])
);

debounce btn_db1(
  .clk(clk),
  .btn_input(usr_btn[1]),
  .btn_output(btn_level[1])
);

debounce btn_db2(
  .clk(clk),
  .btn_input(usr_btn[2]),
  .btn_output(btn_level[2])
);

debounce btn_db3(
  .clk(clk),
  .btn_input(usr_btn[3]),
  .btn_output(btn_level[3])
);

//
// Enable one cycle of btn_pressed per each button hit
//
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 4'b0000;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level & ~prev_btn_level);

// ------------------------------------------------------------------------
// The following code creates an initialized SRAM memory block that
// stores an 1024x8-bit unsigned numbers.
sram ram0(.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));

//assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However,
//                             // if you set 'we' to 0, Vivado fails to synthesize
//                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_we = proc_write;
//assign sram_en = (
//    P == S_MAIN_ADDR || P == S_MAIN_READ ||
//    proc_en
//); // Enable the SRAM block.
assign sram_en = 1'b1;
assign sram_addr = (output_ready ? user_addr[9:0] : proc_addr[9:0]);
//assign data_in = 8'b0; // SRAM is read-only so we tie inputs to zeros.
assign data_in = proc_write_data;

// End of the SRAM memory block.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the main controller
always @(posedge clk) begin
  if (~reset_n) begin
    P <= S_MAIN_ADDR; // read samples at 000 first
  end else begin
    P <= P_next;
  end
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_ADDR: // send an address to the SRAM
      P_next <= S_MAIN_READ;
    S_MAIN_READ: // fetch the sample from the SRAM
      P_next <= S_MAIN_SHOW;
    S_MAIN_SHOW:
      P_next <= S_MAIN_WAIT;
    S_MAIN_WAIT: // wait for a button click
      if (| btn_pressed == 1) P_next <= S_MAIN_ADDR;
      else P_next <= S_MAIN_WAIT;
  endcase
end

// FSM ouput logic: Fetch the data bus of sram[] for display
always @(posedge clk) begin
  if (~reset_n) user_data <= 8'b0;
  else if (sram_en && !sram_we) user_data <= data_out;
end
// End of the main controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// The following code updates the 1602 LCD text messages.
always @(posedge clk) begin
  if (~reset_n) begin
    row_A <= "Data at [0x---] ";
  end else if (P == S_MAIN_SHOW) begin
    row_A[39:32] <= ((user_addr[9:8] > 9)? "7" : "0") + user_addr[9:8];
    row_A[31:24] <= ((user_addr[7:4] > 9)? "7" : "0") + user_addr[7:4];
    row_A[23:16] <= ((user_addr[3:0] > 9)? "7" : "0") + user_addr[3:0];
  end
end

always @(posedge clk) begin
  if (~reset_n) begin
    row_B <= "is equal to 0x--";
  end else if (P == S_MAIN_SHOW) begin
    row_B[15:08] <= ((user_data[7:4] > 9)? "7" : "0") + user_data[7:4];
    row_B[07:00] <= ((user_data[3:0] > 9)? "7" : "0") + user_data[3:0];
  end
end
// End of the 1602 LCD text-updating code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// The circuit block that processes the user's button event.
always @(posedge clk) begin
  if (~reset_n)
    user_addr <= 10'h000;
  else if (output_ready) begin
    if (btn_pressed[1])
      user_addr <= (user_addr < 1023)? user_addr + 1 : user_addr;
    else if (btn_pressed[0])
      user_addr <= (user_addr > 0)? user_addr - 1 : user_addr;
    else if (btn_pressed[2])
      user_addr <= 10'h062;
  end
end
// End of the user's button control.
// ------------------------------------------------------------------------

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

// TODO: Figure out the FSM and flow chart of different components.
//       Make sure to draw it out and save it on desktop.

localparam [1:0] S_UART_IDLE = 0, S_UART_WAIT = 1,
                 S_UART_SEND = 2, S_UART_INCR = 3;
localparam INIT_DELAY = 100_000; // 1 msec @ 100 MHz
localparam REPLY_STR  = 0; // starting index of the reply message
localparam REPLY_LEN  = 34; // length of the hello message
localparam MEM_SIZE   = REPLY_LEN;

wire print_done;
reg [$clog2(MEM_SIZE):0] send_counter;
reg [1:0] UART_WRITE_P, UART_WRITE_P_next;
wire [7:0] data[0:MEM_SIZE-1];
wire [0:REPLY_LEN*8-1] reply_msg = {"The matrix operation result is:\015\012", 8'h00};

generate
    genvar i;
    for (i = 0; i < REPLY_LEN; i = i + 1) begin
        assign data[i][7:0] = reply_msg[i*8+:8];
    end
endgenerate

// FSM output logics: print string control signals.
assign print_done = (tx_byte == 8'h0);

// End of the FSM of the print string controller
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the controller that sends a string to the UART.
always @(posedge clk) begin
  if (~reset_n) UART_WRITE_P <= S_UART_IDLE;
  else UART_WRITE_P <= UART_WRITE_P_next;
end

reg last_output_ready;
wire print_enable = (~last_output_ready && output_ready);

always @(posedge clk) begin
    if (~reset_n)
        last_output_ready <= 1;
    else
        last_output_ready <= output_ready;
end

always @(*) begin // FSM next-state logic
  case (UART_WRITE_P)
    S_UART_IDLE: // wait for the print_string flag
      if (print_enable) UART_WRITE_P_next <= S_UART_WAIT;
      else UART_WRITE_P_next <= S_UART_IDLE;
    S_UART_WAIT: // wait for the transmission of current data byte begins
      if (is_transmitting == 1) UART_WRITE_P_next <= S_UART_SEND;
      else UART_WRITE_P_next <= S_UART_WAIT;
    S_UART_SEND: // wait for the transmission of current data byte finishes
      if (is_transmitting == 0) UART_WRITE_P_next <= S_UART_INCR; // transmit next character
      else UART_WRITE_P_next <= S_UART_SEND;
    S_UART_INCR:
      if (tx_byte == 8'h0) UART_WRITE_P_next <= S_UART_IDLE; // string transmission ends
      else UART_WRITE_P_next <= S_UART_WAIT;
  endcase
end

// FSM output logics: UART transmission control signals
assign transmit = output_ready;
assign tx_byte  = data[send_counter];

// UART send_counter control circuit
always @(posedge clk) begin
  if (~reset_n)
    send_counter <= 0;
  else
    case (output_ready && send_counter < MEM_SIZE)
      1'b0: send_counter <= 0;
      1'b1: send_counter <= send_counter + (UART_WRITE_P_next == S_UART_INCR);
    endcase
end
// End of the FSM of the print string controller
// ------------------------------------------------------------------------

reg [1:0] state;
reg [1:0] next_state;
localparam [1:0]
    STATE_MAX_POOL_A = 0,
    STATE_MAX_POOL_B = 1,
    STATE_MATRIX_MUL = 2,
    STATE_OUTPUT     = 3;
reg max_pool_a_done;
reg max_pool_b_done;
reg matrix_mul_done;

always @(posedge clk) begin
    if (~reset_n) begin
        state <= STATE_MAX_POOL_A;
    end else begin
        state <= next_state;
    end
end

always @(posedge clk) begin
    case (state)
        STATE_MAX_POOL_A:
            if (max_pool_a_done) next_state <= STATE_MAX_POOL_B;
            else                 next_state <= STATE_MAX_POOL_A;
        STATE_MAX_POOL_B:
            if (max_pool_b_done) next_state <= STATE_MATRIX_MUL;
            else                 next_state <= STATE_MAX_POOL_B;
        STATE_MATRIX_MUL:
            if (matrix_mul_done) next_state <= STATE_OUTPUT;
            else                 next_state <= STATE_MATRIX_MUL;
        STATE_OUTPUT:
            next_state <= STATE_OUTPUT;
    endcase
end

assign output_ready = matrix_mul_done;
reg [2:0] r;
reg [2:0] c;

reg [7:0] mx;
reg [2:0] max_dr;
reg [2:0] max_dc;

localparam [2:0]
    MAX_STATE_IDLE       = 3'd0,
    MAX_STATE_READ       = 3'd1,
    MAX_STATE_READ_WAIT  = 3'd2,
    MAX_STATE_UPDATE     = 3'd3,
    MAX_STATE_WRITE      = 3'd4,
    MAX_STATE_WRITE_WAIT = 3'd5;

reg [2:0] max_state;
reg [2:0] next_max_state;
reg max_active;
wire max_finish = (max_dr == 2 && max_dc == 2);
wire max_write_finish = (max_state == MAX_STATE_WRITE_WAIT);
reg max_wait;

always @(posedge clk) begin
    if (~reset_n) begin
        max_state <= MAX_STATE_IDLE;
    end else begin
        max_state <= next_max_state;
    end
end

always @(posedge clk) begin
    case (max_state)
    MAX_STATE_IDLE:
        if (max_active)    next_max_state <= MAX_STATE_READ;
        else               next_max_state <= MAX_STATE_IDLE;
    MAX_STATE_READ:
        next_max_state <= MAX_STATE_READ_WAIT;
    MAX_STATE_READ_WAIT:
        if (max_wait)      next_max_state <= MAX_STATE_READ_WAIT;
        else               next_max_state <= MAX_STATE_UPDATE;
    MAX_STATE_UPDATE:
        if (max_finish)    next_max_state <= MAX_STATE_WRITE;
        else               next_max_state <= MAX_STATE_READ;
    MAX_STATE_WRITE:
        next_max_state <= MAX_STATE_WRITE_WAIT;
    MAX_STATE_WRITE_WAIT:
        next_max_state <= MAX_STATE_IDLE;
    endcase
end

wire [9:0] base_read_addr = (max_pool_a_done ? 10'd49 : 10'd00);
wire [9:0] base_write_addr = (max_pool_a_done ? 10'd123 : 10'd98);

reg [9:0] proc_addr_max;
wire [7:0] proc_write_data_max = mx;
reg [7:0] proc_read_data_max;

always @(posedge clk) begin
    if (max_state == MAX_STATE_IDLE) begin
        mx <= 0;
        max_dr <= 0;
        max_dc <= 0;
    end else if (max_state == MAX_STATE_READ) begin
        proc_addr_max <= base_read_addr + (r + max_dr) * 3'd7 + c + max_dc;
        max_wait <= 1'b1;
    end else if (max_state == MAX_STATE_READ_WAIT) begin
        if (sram_en && ~sram_we) proc_read_data_max <= data_out;
        max_wait <= 1'b0;
    end else if (max_state == MAX_STATE_UPDATE) begin
        mx <= (mx > proc_read_data_max ? mx : proc_read_data_max);
    end else if (max_state == MAX_STATE_WRITE) begin
        proc_addr_max <= base_write_addr + (max_pool_a_done ? (c * 3'd5 + r[2:0]) : (r * 3'd5 + c[2:0]));
    end
    
    if (max_state == MAX_STATE_UPDATE && next_max_state != MAX_STATE_UPDATE) begin
        if (max_dc == 2) begin
            max_dr <= max_dr + 1;
            max_dc <= 0;
        end else begin
            max_dr <= max_dr;
            max_dc <= max_dc + 1;
        end
    end
end


localparam [2:0]
    MUL5_STATE_IDLE       = 3'd0,
    MUL5_STATE_READ1      = 3'd1,
    MUL5_STATE_READ1_WAIT = 3'd2,
    MUL5_STATE_READ2      = 3'd3,
    MUL5_STATE_READ2_WAIT = 3'd4,
    MUL5_STATE_UPDATE     = 3'd5,
    MUL5_STATE_WRITE      = 3'd6,
    MUL5_STATE_WRITE_WAIT = 3'd7;
reg [2:0] mul5_state;
reg [2:0] next_mul5_state;
reg [2:0] mul5_k;
reg mul5_active;
wire mul5_finish;
reg [9:0] proc_addr_mul5;
reg [7:0] proc_write_data_mul5;
reg [18:0] mul5_sum;
reg [7:0] mul5_a;
reg [7:0] mul5_b;
reg [1:0] mul5_addr_i;
wire mul5_write_finish;
reg mul5_wait;

always @(posedge clk) begin
    if (~reset_n) begin
        mul5_state <= MUL5_STATE_IDLE;
    end else begin
        mul5_state <= next_mul5_state;
    end
end

always @(posedge clk) begin
    case (mul5_state)
    MUL5_STATE_IDLE:
        if (mul5_active)    next_mul5_state <= MUL5_STATE_READ1;
        else                next_mul5_state <= MUL5_STATE_IDLE;
    MUL5_STATE_READ1:
        next_mul5_state <= MUL5_STATE_READ1_WAIT;
    MUL5_STATE_READ1_WAIT:
        if (mul5_wait)      next_mul5_state <= MUL5_STATE_READ1_WAIT;
        else                next_mul5_state <= MUL5_STATE_READ2;
    MUL5_STATE_READ2:
        next_mul5_state <= MUL5_STATE_READ2_WAIT;
    MUL5_STATE_READ2_WAIT:
        if (mul5_wait)      next_mul5_state <= MUL5_STATE_READ2_WAIT;
        else                next_mul5_state <= MUL5_STATE_UPDATE;
    MUL5_STATE_UPDATE:
        if (mul5_finish)    next_mul5_state <= MUL5_STATE_WRITE;
        else                next_mul5_state <= MUL5_STATE_READ1;
    MUL5_STATE_WRITE:
        next_mul5_state <= MUL5_STATE_WRITE_WAIT;
    MUL5_STATE_WRITE_WAIT:
        if (mul5_addr_i == 3) next_mul5_state <= MUL5_STATE_IDLE;
        else                  next_mul5_state <= MUL5_STATE_WRITE;
    endcase
end

assign mul5_finish = (mul5_k == 4);
assign mul5_write_finish = (mul5_state == MUL5_STATE_WRITE_WAIT && mul5_addr_i == 3);

always @(posedge clk) begin
    if (mul5_state == MUL5_STATE_IDLE) begin
        mul5_k <= 0;
        mul5_sum <= 0;
        mul5_addr_i <= 0;
    end else if (mul5_state == MUL5_STATE_READ1) begin
        proc_addr_mul5 <= 10'd98 + r[2:0] * 3'd5 + mul5_k;
        mul5_wait <= 1'b1;
    end else if (mul5_state == MUL5_STATE_READ1_WAIT) begin
        if (sram_en && ~sram_we) mul5_a <= data_out;
        mul5_wait <= 1'b0;
    end else if (mul5_state == MUL5_STATE_READ2) begin
        proc_addr_mul5 <= 10'd123 + mul5_k * 3'd5 + c[2:0];
        mul5_wait <= 1'b1;
    end else if (mul5_state == MUL5_STATE_READ2_WAIT) begin
        if (sram_en && ~sram_we) mul5_b <= data_out;
        mul5_wait <= 1'b0;
    end else if (mul5_state == MUL5_STATE_WRITE) begin
        proc_addr_mul5 <= 10'd148 + (r[2:0] * 3'd5 + c[2:0]) * 2'd3 + mul5_addr_i;
        if (mul5_addr_i == 0)       proc_write_data_mul5 <= {5'd0, mul5_sum[16+:3]};
        else if (mul5_addr_i == 1)  proc_write_data_mul5 <= mul5_sum[8+:8];
        else if (mul5_addr_i == 2)  proc_write_data_mul5 <= mul5_sum[0+:8];
    end
    
    if (mul5_state == MUL5_STATE_UPDATE && next_mul5_state != MUL5_STATE_UPDATE) begin
        mul5_sum <= mul5_sum + mul5_a * mul5_b; // TODO: beware of WNS
        mul5_k <= mul5_k + 1;
    end
    
    if (mul5_state == MUL5_STATE_WRITE && next_mul5_state == MUL5_STATE_WRITE_WAIT) begin
        mul5_addr_i <= mul5_addr_i + 1;
    end
end

localparam [1:0]
    OUTPUT_STATE_IDLE      = 3'd0,
    OUTPUT_STATE_TITLE     = 3'd1,
    OUTPUT_STATE_SEPERATOR = 3'd2,
    OUTPUT_STATE_NUMBER    = 3'd3;
reg [1:0] output_state;
reg [1:0] next_output_state;

assign proc_addr = (state == STATE_MATRIX_MUL ? proc_addr_mul5 : proc_addr_max);
assign proc_write =
    (next_mul5_state == MUL5_STATE_WRITE_WAIT || mul5_state == MUL5_STATE_WRITE_WAIT) ||
    (next_max_state  == MAX_STATE_WRITE_WAIT  || max_state  == MAX_STATE_WRITE_WAIT);
assign proc_write_data = (state == STATE_MATRIX_MUL ? proc_write_data_mul5 : proc_write_data_max);

always @(posedge clk) begin
    if (~reset_n) begin
        max_pool_a_done <= 0;
        max_pool_b_done <= 0;
        matrix_mul_done <= 0;
        
        usr_led <= 4'b0000;
        
        // phase 1 initialization
        r <= 0;
        c <= 0;
    end else begin
        
        // phase 1: A max pooling
        if (state == STATE_MAX_POOL_A) begin
            if (~max_pool_a_done) begin
                if (max_write_finish && max_active) begin
                    max_active <= 0;
                    if (r < 4 || c < 4) begin
                        if (c == 4) begin
                            r <= r + 1;
                            c <= 0;
                        end else begin
                            r <= r;
                            c <= c + 1;
                        end
                    end else begin
                        max_pool_a_done <= 1;
                        r <= 0;
                        c <= 0;
                    end
                end else if (~max_write_finish) begin
                    max_active <= 1;
                end
            end else begin
                max_active <= 0;
            end
            usr_led <= 4'b1000;
        end
        
        // phase 2: B max pooling & transpose
        if (state == STATE_MAX_POOL_B)begin
            if (~max_pool_b_done) begin
                if (max_write_finish && max_active) begin
                    max_active <= 0;
                    if (r < 4 || c < 4) begin
                        if (c == 4) begin
                            r <= r + 1;
                            c <= 0;
                        end else begin
                            r <= r;
                            c <= c + 1;
                        end
                    end else begin
                        max_pool_b_done <= 1;
                        r <= 0;
                        c <= 0;
                    end
                end else if (~max_write_finish) begin
                    max_active <= 1;
                end
            end else begin
                max_active <= 0;
            end
            usr_led <= 4'b0100;
        end
        
        // phase 3: matrix multiplication
        if (state == STATE_MATRIX_MUL) begin
            if (~matrix_mul_done) begin
                if (mul5_write_finish && mul5_active) begin
                    mul5_active <= 0;
                    if (r < 4 || c < 4) begin
                        if (c == 4) begin
                            r <= r + 1;
                            c <= 0;
                        end else begin
                            r <= r;
                            c <= c + 1;
                        end
                    end else begin
                        matrix_mul_done <= 1;
                        r <= 0;
                        c <= 0;
                    end
                end else if (~mul5_write_finish) begin
                    mul5_active <= 1;
                end
            end else begin
                mul5_active <= 0;
            end
            usr_led <= 4'b0010;
        end
        
        // phase 4: UART output
        if (state == STATE_OUTPUT) begin
            usr_led <= 4'b0001;
        end
    end
end

endmodule