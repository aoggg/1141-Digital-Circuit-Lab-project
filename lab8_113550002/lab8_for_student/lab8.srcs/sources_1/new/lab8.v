`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai
// 
// Create Date: 2017/05/08 15:29:41
// Design Name: 
// Module Name: lab6
// Project Name: 
// Target Devices: 
// Tool Versions:
// Description: The sample top module of lab 6: sd card reader. The behavior of
//              this module is as follows
//              1. When the SD card is initialized, display a message on the LCD.
//                 If the initialization fails, an error message will be shown.
//              2. The user can then press usr_btn[2] to trigger the sd card
//                 controller to read the super block of the sd card (located at
//                 block # 8192) into the SRAM memory.
//              3. During SD card reading time, the four LED lights will be turned on.
//                 They will be turned off when the reading is done.
//              4. The LCD will then displayer the sector just been read, and the
//                 first byte of the sector.
//              5. Everytime you press usr_btn[2], the next byte will be displayed.
// 
// Dependencies: clk_divider, LCD_module, debounce, sd_card
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab8(
  // General system I/O ports
  input  clk,
  input  reset_n,
  input  [3:0] usr_btn,
  output [3:0] usr_led,

  // SD card specific I/O ports
  output spi_ss,
  output spi_sck,
  output spi_mosi,
  input  spi_miso,

  // 1602 LCD Module Interface
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D,
  
  // tri-state LED
  output [3:0] rgb_led_r,
  output [3:0] rgb_led_g,
  output [3:0] rgb_led_b
);

localparam [3:0] S_MAIN_INIT = 4'd0, S_MAIN_IDLE = 4'd1,
                 S_MAIN_WAIT = 4'd2, S_MAIN_READ = 4'd3,
                 S_MAIN_WAIT2 = 4'd4, S_MAIN_SHOW = 4'd5,
                 S_MAIN_FIND = 4'd6, S_MAIN_LIGHT = 4'd7;

// Declare system variables
wire btn_level, btn_pressed;
reg  prev_btn_level;
reg  [5:0] send_counter;
reg  [3:0] P, P_next;
reg  [9:0] sd_counter;
reg  [7:0] data_byte;
reg  [31:0] blk_addr;
reg  [71:0] find_start;
reg  [55:0] find_end;
reg  [3:0] r = 0, g = 0, b = 0, p = 0, y = 0, x = 0;
reg  [7:0] color[0:65];
reg  [31:0] led_rgb;
reg  [6:0] total = 0;

reg  [127:0] row_A = "SD card cannot  ";
reg  [127:0] row_B = "be initialized! ";
reg  done_flag;
wire  flag; // Signals the completion of reading one SD sector.

// Declare SD card interface signals
wire clk_sel;
wire clk_500k;
reg  rd_req;
reg  [31:0] rd_addr;
wire init_finished;
wire [7:0] sd_dout;
wire sd_valid;

// Declare the control/data signals of an SRAM memory block
wire [7:0] data_in;
wire [7:0] data_out;
wire [8:0] sram_addr;
wire       sram_we, sram_en;

assign clk_sel = (init_finished)? clk : clk_500k; // clock for the SD controller
assign usr_led = 0;

clk_divider#(200) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(clk_500k)
);

debounce btn_db0(
  .clk(clk),
  .btn_input(usr_btn[2]),
  .btn_output(btn_level)
);

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

sd_card sd_card0(
  .cs(spi_ss),
  .sclk(spi_sck),
  .mosi(spi_mosi),
  .miso(spi_miso),

  .clk(clk_sel),
  .rst(~reset_n),
  .rd_req(rd_req),
  .block_addr(rd_addr),
  .init_finished(init_finished),
  .dout(sd_dout),
  .sd_valid(sd_valid)
);

sram ram0(
  .clk(clk),
  .we(sram_we),
  .en(sram_en),
  .addr(sram_addr),
  .data_i(data_in),
  .data_o(data_out)
);

//
// Enable one cycle of btn_pressed per each button hit
//
always @(posedge clk) begin
  if (~reset_n)
    prev_btn_level <= 0;
  else
    prev_btn_level <= btn_level;
end

assign btn_pressed = (btn_level == 1 && prev_btn_level == 0)? 1 : 0;


reg [9:0] duty_cycle = 5, pwm_cnt = 0;
wire light = pwm_cnt < duty_cycle;

always @(posedge clk) begin
    if (pwm_cnt == 10'd99) pwm_cnt = 0;
    else pwm_cnt = pwm_cnt + 1;
end

reg[3:0] led_r = 0, led_g = 0, led_b = 0;

assign rgb_led_r = led_r & {4{light}}, rgb_led_g = led_g & {4{light}}, rgb_led_b = led_b & {4{light}};

reg [31:0] cnt = 0;
reg change;
reg [9:0] idx = 0;
reg start_flag = 0;

always @(posedge clk) begin
    if (P == S_MAIN_LIGHT) begin
        if (cnt + 1 == 32'd200_000_000) begin
            cnt <= 0;
            idx <= idx + 1;
            change <= 1;
        end else begin 
            cnt <= cnt + 1;
            change <= 0;
        end
    end else begin
        cnt <= 0;
        idx <= 3;
    end
end

// ------------------------------------------------------------------------
// The following code sets the control signals of an SRAM memory block
// that is connected to the data output port of the SD controller.
// Once the read request is made to the SD controller, 512 bytes of data
// will be sequentially read into the SRAM memory block, one byte per
// clock cycle (as long as the sd_valid signal is high).
assign sram_we = sd_valid;          // Write data into SRAM when sd_valid is high.
assign sram_en = 1;                 // Always enable the SRAM block.
assign data_in = sd_dout;           // Input data always comes from the SD controller.
assign sram_addr = sd_counter[8:0]; // Set the driver of the SRAM address signal.
// End of the SRAM memory block
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// FSM of the SD card reader that reads the super block (512 bytes)
always @(posedge clk) begin
  if (~reset_n) begin
    P <= S_MAIN_INIT;
  end
  else begin
    P <= P_next;
  end
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT: // wait for SD card initialization
      if (init_finished == 1) P_next = S_MAIN_IDLE;
      else P_next = S_MAIN_INIT;
    S_MAIN_IDLE: // wait for button click
      if (btn_pressed == 1) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_IDLE;
    S_MAIN_WAIT: // issue a rd_req to the SD controller until it's ready
      P_next = S_MAIN_FIND;
    S_MAIN_FIND:
      if (find_start == "DCL_START") begin
        P_next = S_MAIN_READ;
      end else if (sd_counter == 512) P_next = S_MAIN_WAIT;
      else P_next = S_MAIN_FIND;
    S_MAIN_WAIT2:
      P_next = S_MAIN_READ;
    S_MAIN_READ:
      if (find_end == "DCL_END") P_next = S_MAIN_LIGHT;
      else if (sd_counter == 512) P_next = S_MAIN_WAIT2;
      else P_next = S_MAIN_READ;
    S_MAIN_LIGHT:
      if (idx >= total - 4) P_next = S_MAIN_SHOW;
      else P_next = S_MAIN_LIGHT;
    S_MAIN_SHOW:
      P_next = S_MAIN_SHOW;
    default:
      P_next = S_MAIN_IDLE;
  endcase
end

// FSM output logic: controls the 'rd_req' and 'rd_addr' signals.
always @(*) begin
  rd_req = (P == S_MAIN_WAIT || P == S_MAIN_WAIT2);
  rd_addr = blk_addr;
end

always @(posedge clk) begin
  if (~reset_n) blk_addr <= 32'h2000;
  else if (P == S_MAIN_WAIT || P == S_MAIN_WAIT2) blk_addr <= blk_addr + 1;
  else blk_addr <= blk_addr; // In lab 6, change this line to scan all blocks
end

// FSM output logic: controls the 'sd_counter' signal.
// SD card read address incrementer

always @(posedge clk) begin
  if (~reset_n || (P == S_MAIN_READ && P_next == S_MAIN_SHOW) || (P_next == S_MAIN_WAIT) || (P_next == S_MAIN_WAIT2))
    sd_counter <= 0;
  else if ((P == S_MAIN_FIND || P == S_MAIN_READ) && sd_valid)
    sd_counter <= sd_counter + 1;
end

// FSM ouput logic: Retrieves the content of sram[] for display
always @(posedge clk) begin
  if (~reset_n) data_byte <= 8'b0;
  else if ((P == S_MAIN_FIND || P == S_MAIN_READ) && sd_valid) data_byte <= data_out;
end

always @(posedge clk) begin
    if (~reset_n) begin
        find_start <= 0;
        find_end <= 0;
        total <= 0;
    end else if ((P == S_MAIN_FIND) && sd_valid) begin
        find_start <= {find_start[63:0], data_byte};
    end else if (P == S_MAIN_READ && sd_valid) begin
        find_end <= {find_end[47:0], data_byte};
        color[total] <= data_byte;
        total <= total + 1;
    end
end


// End of the FSM of the SD card reader
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// LCD Display function.

always @(posedge clk) begin
    if (~reset_n) begin
        row_A <= "SD card cannot  ";
        row_B <= "be initialized! ";
    end else if (P == S_MAIN_IDLE) begin
        row_A <= "Hit BTN2 to read";
        row_B <= "the SD card ... ";
    end else if (P == S_MAIN_FIND) begin
        row_A <= "searching for   ";
        row_B <= "title           ";
    end else if (P == S_MAIN_READ) begin
        row_A <= "calculating...  ";
        row_B <= "                ";
    end else if (P == S_MAIN_LIGHT) begin
        row_A <= "calculating...  ";
        row_B <= "                ";
    end else if (P == S_MAIN_SHOW) begin
        row_A <= "RGBPYX          ";
        row_B <= {"0" + r, "0" + g, "0" + b, "0" + p, "0" + y, "0" + x, "          "};
    end
end

always @(posedge clk) begin
    if (~reset_n) led_rgb <= 0;
    else if (P == S_MAIN_READ && P_next == S_MAIN_LIGHT) begin
        led_rgb <= {color[3], color[2], color[1], color[0]};
    end else if (P == S_MAIN_LIGHT) begin
        if (change) led_rgb <= {color[idx], led_rgb[31:8]};
    end
end

always @(posedge clk) begin
    if (~reset_n) begin
        led_r[0] <= 0;
        led_g[0] <= 0;
        led_b[0] <= 0;
        r <= 0;
        g <= 0;
        b <= 0;
        p <= 0;
        y <= 0;
        x <= 0;
    end else if (P == S_MAIN_LIGHT) begin
        if (led_rgb[7:0] == "r" || led_rgb[7:0] == "R") begin
            led_r[0] <= 1; led_g[0] <= 0; led_b[0] <= 0;
            if (change) r <= r + 1;
        end else if (led_rgb[7:0] == "G" || led_rgb[7:0] == "g") begin
            led_r[0] <= 0; led_g[0] <= 1; led_b[0] <= 0;    
            if (change) g <= g + 1;
        end else if (led_rgb[7:0] == "B" || led_rgb[7:0] == "b") begin
            led_r[0] <= 0; led_g[0] <= 0; led_b[0] <= 1;    
            if (change) b <= b + 1;
        end else if (led_rgb[7:0] == "P" || led_rgb[7:0] == "p") begin
            led_r[0] <= 1; led_g[0] <= 0; led_b[0] <= 1;  
            if (change) p <= p + 1;  
        end else if (led_rgb[7:0] == "Y" || led_rgb[7:0] == "y") begin
            led_r[0] <= 1; led_g[0] <= 1; led_b[0] <= 0;
            if (change) y <= y + 1;
        end else begin
            led_r[0] <= 0; led_g[0] <= 0; led_b[0] <= 0;
            if (change) x <= x + 1;
        end
    end else begin
            led_r[0] <= 0; led_g[0] <= 0; led_b[0] <= 0;    
    end
end

always @(posedge clk) begin
    if (~reset_n) begin
        led_r[1] <= 0;
        led_g[1] <= 0;
        led_b[1] <= 0;
    end else if (P == S_MAIN_LIGHT) begin
        if (led_rgb[15:8] == "r" || led_rgb[15:8] == "R") begin
            led_r[1] <= 1; led_g[1] <= 0; led_b[1] <= 0;
        end else if (led_rgb[15:8] == "G" || led_rgb[15:8] == "g") begin
            led_r[1] <= 0; led_g[1] <= 1; led_b[1] <= 0;    
        end else if (led_rgb[15:8] == "B" || led_rgb[15:8] == "b") begin
            led_r[1] <= 0; led_g[1] <= 0; led_b[1] <= 1;    
        end else if (led_rgb[15:8] == "P" || led_rgb[15:8] == "p") begin
            led_r[1] <= 1; led_g[1] <= 0; led_b[1] <= 1;    
        end else if (led_rgb[15:8] == "Y" || led_rgb[15:8] == "y") begin
            led_r[1] <= 1; led_g[1] <= 1; led_b[1] <= 0;
        end else begin
            led_r[1] <= 0; led_g[1] <= 0; led_b[1] <= 0;
        end
    end else begin
            led_r[1] <= 0; led_g[1] <= 0; led_b[1] <= 0;
    end
end

always @(posedge clk) begin
    if (~reset_n) begin
        led_r[2] <= 0;
        led_g[2] <= 0;
        led_b[2] <= 0;
    end else if (P == S_MAIN_LIGHT) begin
        if (led_rgb[23:16] == "r" || led_rgb[23:16] == "R") begin
            led_r[2] <= 1; led_g[2] <= 0; led_b[2] <= 0;
        end else if (led_rgb[23:16] == "G" || led_rgb[23:16] == "g") begin
            led_r[2] <= 0; led_g[2] <= 1; led_b[2] <= 0;    
        end else if (led_rgb[23:16] == "B" || led_rgb[23:16] == "b") begin
            led_r[2] <= 0; led_g[2] <= 0; led_b[2] <= 1;    
        end else if (led_rgb[23:16] == "P" || led_rgb[23:16] == "p") begin
            led_r[2] <= 1; led_g[2] <= 0; led_b[2] <= 1;    
        end else if (led_rgb[23:16] == "Y" || led_rgb[23:16] == "y") begin
            led_r[2] <= 1; led_g[2] <= 1; led_b[2] <= 0;
        end else begin
            led_r[2] <= 0; led_g[2] <= 0; led_b[2] <= 0;
        end
    end else begin
            led_r[2] <= 0; led_g[2] <= 0; led_b[2] <= 0;
    end
end

always @(posedge clk) begin
    if (~reset_n) begin
        led_r[3] <= 0;
        led_g[3] <= 0;
        led_b[3] <= 0;
    end else if (P == S_MAIN_LIGHT) begin
        if (led_rgb[31:24] == "r" || led_rgb[31:24] == "R") begin
            led_r[3] <= 1; led_g[3] <= 0; led_b[3] <= 0;
        end else if (led_rgb[31:24] == "G" || led_rgb[31:24] == "g") begin
            led_r[3] <= 0; led_g[3] <= 1; led_b[3] <= 0;
        end else if (led_rgb[31:24] == "B" || led_rgb[31:24] == "b") begin
            led_r[3] <= 0; led_g[3] <= 0; led_b[3] <= 1;
        end else if (led_rgb[31:24] == "P" || led_rgb[31:24] == "p") begin
            led_r[3] <= 1; led_g[3] <= 0; led_b[3] <= 1;
        end else if (led_rgb[31:24] == "Y" || led_rgb[31:24] == "y") begin
            led_r[3] <= 1; led_g[3] <= 1; led_b[3] <= 0;
        end else begin
            led_r[3] <= 0; led_g[3] <= 0; led_b[3] <= 0;
        end
    end else begin
            led_r[3] <= 0; led_g[3] <= 0; led_b[3] <= 0;
    end
end
// End of the LCD display function
// ------------------------------------------------------------------------

endmodule
