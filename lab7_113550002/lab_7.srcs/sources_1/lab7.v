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
//  output LCD_RS,
//  output LCD_RW,
//  output LCD_E,
//  output [3:0] LCD_D,
  
  // UART
  input  uart_rx,
  output uart_tx
);

// declare system variables
wire btn_level_1;

wire [9:0]  proc_addr;

//reg  [127:0] row_A, row_B;

// declare SRAM control signals
wire [9:0] sram_addr;
wire [7:0] data_in;
wire [7:0] data_out;
wire       sram_we, sram_en;

wire       proc_en;
wire       proc_write;
wire [7:0] proc_write_data;

debounce btn_db1(
  .clk(clk),
  .btn_input(usr_btn[1]),
  .btn_output(btn_level_1)
);

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
assign sram_addr = proc_addr[9:0];
//assign data_in = 8'b0; // SRAM is read-only so we tie inputs to zeros.
assign data_in = proc_write_data;

// End of the SRAM memory block.
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

localparam [1:0] S_UART_IDLE = 0, S_UART_WAIT = 1,
                 S_UART_SEND = 2, S_UART_INCR = 3;
localparam REPLY_STR  = 0; // starting index of the reply message
localparam REPLY_LEN  = 34; // length of the hello message
localparam MEM_SIZE   = REPLY_LEN;

wire print_done;
reg [$clog2(MEM_SIZE):0] send_counter;
reg [1:0] UART_WRITE_P, UART_WRITE_P_next;
reg [7:0] data[0:MEM_SIZE-1];
wire [0:REPLY_LEN*8-1] reply_title = {"The matrix operation result is:\015\012", 8'h00};

reg prev_print_done;
always @(posedge clk) begin
    prev_print_done <= print_done;
end

reg [2:0] r;
reg [2:0] c;

localparam [2:0]
    STATE_IDLE       = 0,
    STATE_INIT       = 1,
    STATE_MAX_POOL_A = 2,
    STATE_MAX_POOL_B = 3,
    STATE_MATRIX_MUL = 4;
reg [2:0] state;
reg [2:0] next_state;

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

wire data_init_finish = (state == STATE_INIT) || (c == 4 && mul5_state == MUL5_STATE_WRITE);
reg prev_data_init_finish;

always @(posedge clk) begin
    prev_data_init_finish <= data_init_finish;
end

wire [18:0] result;

generate
    genvar i;
    for (i = 0; i < MEM_SIZE; i = i + 1) begin
        always @(posedge clk) begin
            if (~reset_n) begin
                data[i][7:0] <= reply_title[i*8+:8];
            end else if (state == STATE_MATRIX_MUL) begin
                if (i % 6 == 0) begin
                    data[i][7:0] <=
                        (i / 6 == 0) ? "[" :
                        (i / 6 == 5) ? "]" : ",";
                end else if (i == 31) begin
                    data[i][7:0] <= "\015";
                end else if (i == 32) begin
                    data[i][7:0] <= "\012";
                end else if (i == 33) begin
                    data[i][7:0] <= 8'd0;
                end else if (i / 6 == c) begin
                    case (i % 6)
                    1: data[i][7:0] <= "0" + {1'd0, result[16+:3]};
                    2: data[i][7:0] <= (result[12+:4] > 9 ? "7" : "0") + result[12+:4];
                    3: data[i][7:0] <= (result[ 8+:4] > 9 ? "7" : "0") + result[ 8+:4];
                    4: data[i][7:0] <= (result[ 4+:4] > 9 ? "7" : "0") + result[ 4+:4];
                    5: data[i][7:0] <= (result[ 0+:4] > 9 ? "7" : "0") + result[ 0+:4];
                    endcase
                end
            end
        end
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

wire print_enable = (~prev_data_init_finish && data_init_finish);

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
assign transmit = (UART_WRITE_P_next == S_UART_WAIT) || print_enable;
assign tx_byte  = data[send_counter];

// UART send_counter control circuit
always @(posedge clk) begin
  if (state == STATE_IDLE || mul5_state == MUL5_STATE_UPDATE)
    send_counter <= 0;
  else
    send_counter <= send_counter + (UART_WRITE_P_next == S_UART_INCR);
end
// End of the FSM of the print string controller
// ------------------------------------------------------------------------

reg [3:0] print_num;

reg max_pool_a_done;
reg max_pool_b_done;
reg matrix_mul_done;

always @(posedge clk) begin
    if (~reset_n) begin
        state <= STATE_IDLE;
    end else begin
        state <= next_state;
    end
end

always @(posedge clk) begin
    case (state)
        STATE_IDLE:
            if (btn_level_1) next_state <= STATE_INIT;
            else next_state <= STATE_IDLE;
        STATE_INIT:
            if (~prev_print_done && print_done) next_state <= STATE_MAX_POOL_A;
        STATE_MAX_POOL_A:
            if (max_pool_a_done) next_state <= STATE_MAX_POOL_B;
        STATE_MAX_POOL_B:
            if (max_pool_b_done) next_state <= STATE_MATRIX_MUL;
        STATE_MATRIX_MUL:
            next_state <= STATE_MATRIX_MUL;
        default
            next_state <= state;
    endcase
end

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
        if (max_active) next_max_state <= MAX_STATE_READ;
        else next_max_state <= MAX_STATE_IDLE;
    MAX_STATE_READ:
        next_max_state <= MAX_STATE_READ_WAIT;
    MAX_STATE_READ_WAIT:
        next_max_state <= MAX_STATE_UPDATE;
    MAX_STATE_UPDATE:
        if (max_finish) next_max_state <= MAX_STATE_WRITE;
        else next_max_state <= MAX_STATE_READ;
    MAX_STATE_WRITE:
        next_max_state <= MAX_STATE_WRITE_WAIT;
    MAX_STATE_WRITE_WAIT:
        next_max_state <= MAX_STATE_IDLE;
    default
        next_max_state <= max_state;
    endcase
end

wire [9:0] base_read_addr = (max_pool_a_done ? 10'd49 : 10'd00);
wire [9:0] base_write_addr = (max_pool_a_done ? 10'd123 : 10'd98);

reg [9:0] proc_addr_max;
wire [7:0] proc_write_data_max = mx;
wire [7:0] proc_read_data_max;

assign proc_read_data_max = data_out;

always @(posedge clk) begin
    if (~reset_n) begin
        proc_addr_max <= 0;
    end else begin
        if (max_state == MAX_STATE_IDLE) begin
            mx <= 0;
            max_dr <= 0;
            max_dc <= 0;
        end else if (max_state == MAX_STATE_READ) begin
            proc_addr_max <= base_read_addr + (r + max_dr) * 3'd7 + c + max_dc;
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
end

reg [2:0] mul5_k;
reg mul5_active;
wire mul5_finish;
reg [9:0] proc_addr_mul5;
reg [18:0] mul5_sum;
reg [7:0] mul5_a;
wire [7:0] mul5_b;
wire mul5_write_finish;

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
        if (mul5_active) next_mul5_state <= MUL5_STATE_READ1;
        else next_mul5_state <= MUL5_STATE_IDLE;
    MUL5_STATE_READ1:
        next_mul5_state <= MUL5_STATE_READ1_WAIT;
    MUL5_STATE_READ1_WAIT:
        next_mul5_state <= MUL5_STATE_READ2;
    MUL5_STATE_READ2:
        next_mul5_state <= MUL5_STATE_READ2_WAIT;
    MUL5_STATE_READ2_WAIT:
        next_mul5_state <= MUL5_STATE_UPDATE;
    MUL5_STATE_UPDATE:
        if (mul5_finish) next_mul5_state <= MUL5_STATE_WRITE;
        else next_mul5_state <= MUL5_STATE_READ1;
    MUL5_STATE_WRITE:
        if (c < 4 || print_done) next_mul5_state <= MUL5_STATE_IDLE;
        else next_mul5_state <= MUL5_STATE_WRITE;
    default
        next_mul5_state <= mul5_state;
    endcase
end

assign mul5_finish = (mul5_k == 5);
assign mul5_write_finish = (mul5_state == MUL5_STATE_WRITE);

assign mul5_b = data_out;
assign result = mul5_sum;

always @(posedge clk) begin
    if (~reset_n) begin
        proc_addr_mul5 <= 0;
    end else begin
        if (mul5_state == MUL5_STATE_IDLE) begin
            mul5_k <= 0;
            mul5_sum <= 0;
        end else if (mul5_state == MUL5_STATE_READ1) begin
            proc_addr_mul5 <= 10'd98 + r[2:0] * 3'd5 + mul5_k;
        end else if (mul5_state == MUL5_STATE_READ1_WAIT) begin
            mul5_a <= data_out;
        end else if (mul5_state == MUL5_STATE_READ2) begin
            proc_addr_mul5 <= 10'd123 + mul5_k * 3'd5 + c[2:0];
        end
        
        if (mul5_state != MUL5_STATE_UPDATE && next_mul5_state == MUL5_STATE_UPDATE) begin
            mul5_sum <= mul5_sum + mul5_a * mul5_b;
            mul5_k <= mul5_k + 1;
        end
    end
end

assign proc_addr = (state == STATE_MATRIX_MUL ? proc_addr_mul5 : proc_addr_max);
assign proc_write =
    (next_mul5_state == MUL5_STATE_WRITE_WAIT || mul5_state == MUL5_STATE_WRITE_WAIT) ||
    (next_max_state  == MAX_STATE_WRITE_WAIT  || max_state  == MAX_STATE_WRITE_WAIT);
assign proc_write_data = proc_write_data_max;

always @(posedge clk) begin
    if (~reset_n) begin
        max_pool_a_done <= 0;
        max_pool_b_done <= 0;
        matrix_mul_done <= 0;
        
        usr_led <= 4'b0000;
        
    end else begin
    
        // wait for UART title transmission
        if (state == STATE_INIT) begin
            r <= 0;
            c <= 0;
            usr_led <= 4'b1000;
        end
        
        // A max pooling
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
            usr_led <= 4'b0100;
        end
        
        // B max pooling & transpose
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
            usr_led <= 4'b0010;
        end
        
        // phase 3: matrix multiplication
        if (state == STATE_MATRIX_MUL) begin
            if (~matrix_mul_done) begin
                if (mul5_write_finish && mul5_active && (c < 4 || print_done)) begin
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
            usr_led <= 4'b0001;
        end
    end
end

endmodule