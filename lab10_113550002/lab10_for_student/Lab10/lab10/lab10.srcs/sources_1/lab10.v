`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Dept. of Computer Science, National Chiao Tung University
// Engineer: Chun-Jen Tsai 
// 
// Create Date: 2018/12/11 16:04:41
// Design Name: 
// Module Name: lab9
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A circuit that show the animation of a fish swimming in a seabed
//              scene on a screen through the VGA interface of the Arty I/O card.
// 
// Dependencies: vga_sync, clk_divider, sram 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module lab10(
    input  clk,
    input  reset_n,
    input  [3:0] usr_btn,
    output [3:0] usr_led,
    
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE
    );

// Declare system variables
reg  [31:0] fish_clock[0:3];
wire [9:0]  pos[0:2];
wire [2:0] frame_idx;
wire        fish_region[0:2];

// declare SRAM control signals
wire [16:0] sram_addr[0:3];
wire [11:0] data_in;
wire [11:0] data_out[0:3];
wire        sram_we, sram_en;

// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
                      // synchronization signals to the display device.
  
wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
  
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
  
reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel

reg  [2:0] horizontal_flip = 4;
  
// Application-specific VGA signals
reg  [17:0] pixel_addr[0:3];

// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height

// Set parameters for the fish images
localparam FISH1_VPOS   = 64; // Vertical location of the fish in the sea image.
localparam FISH1_W      = 64; // Width of the fish.
localparam FISH1_H      = 32; // Height of the fish.
localparam FISH2_VPOS   = 128;
localparam FISH2_W      = 64;
localparam FISH2_H      = 44;
localparam FISH3_VPOS   = 64;
localparam FISH3_W      = 64;
localparam FISH3_H      = 72;
reg [17:0] fish_addr[0:2][0:7];   // Address array for up to 8 fish images.
////
// Initializes the fish images starting addresses.
// Note: System Verilog has an easier way to initialize an array,
//       but we are using Verilog 2001 :(

initial begin
  fish_addr[0][0] = 18'd0;         /* Addr for fish image #1 */
  fish_addr[0][1] = FISH1_W * FISH1_H;
  fish_addr[0][2] = FISH1_W * FISH1_H * 2;
  fish_addr[0][3] = FISH1_W * FISH1_H * 3;
  fish_addr[0][4] = FISH1_W * FISH1_H * 4;
  fish_addr[0][5] = FISH1_W * FISH1_H * 5;
  fish_addr[0][6] = FISH1_W * FISH1_H * 6;
  fish_addr[0][7] = FISH1_W * FISH1_H * 7;
  
  fish_addr[1][0] = 18'd0;         /* Addr for fish image #1 */
  fish_addr[1][1] = FISH2_W * FISH2_H;
  fish_addr[1][2] = FISH2_W * FISH2_H * 2;
  fish_addr[1][3] = FISH2_W * FISH2_H * 3;
  fish_addr[1][4] = FISH2_W * FISH2_H * 4;
  fish_addr[1][5] = FISH2_W * FISH2_H * 5;
  fish_addr[1][6] = FISH2_W * FISH2_H * 6;
  fish_addr[1][7] = FISH2_W * FISH2_H * 7;
  
  fish_addr[2][0] = 18'd0;         /* Addr for fish image #1 */
  fish_addr[2][1] = FISH3_W * FISH3_H;
  fish_addr[2][2] = FISH3_W * FISH3_H * 2;
  fish_addr[2][3] = FISH3_W * FISH3_H * 3;
  fish_addr[2][4] = 18'd0;         /* Addr for fish image #1 */
  fish_addr[2][5] = FISH3_W * FISH3_H;
  fish_addr[2][6] = FISH3_W * FISH3_H * 2;
  fish_addr[2][7] = FISH3_W * FISH3_H * 3;
end

// Instiantiate the VGA sync signal generator
vga_sync vs0(
  .clk(vga_clk), .reset(~reset_n), .oHS(VGA_HSYNC), .oVS(VGA_VSYNC),
  .visible(video_on), .p_tick(pixel_tick),
  .pixel_x(pixel_x), .pixel_y(pixel_y)
);

clk_divider#(2) clk_divider0(
  .clk(clk),
  .reset(~reset_n),
  .clk_out(vga_clk)
);

// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(VBUF_W*VBUF_H), .MEM_FILE("images.mem"))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr[0]), .data_i(data_in), .data_o(data_out[0]));

sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH1_W*FISH1_H*8), .MEM_FILE("fish1.mem"))
  ram1 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr[1]), .data_i(data_in), .data_o(data_out[1]));

sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH2_W*FISH2_H*8), .MEM_FILE("fish2.mem"))
  ram2 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr[2]), .data_i(data_in), .data_o(data_out[2]));

sram #(.DATA_WIDTH(12), .ADDR_WIDTH(18), .RAM_SIZE(FISH3_W*FISH3_H*4), .MEM_FILE("fish3.mem"))
  ram3 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr[3]), .data_i(data_in), .data_o(data_out[3]));

assign sram_we = usr_btn[3]; // In this demo, we do not write the SRAM. However, if
                             // you set 'sram_we' to 0, Vivado fails to synthesize
                             // ram0 as a BRAM -- this is a bug in Vivado.
assign sram_en = 1;          // Here, we always enable the SRAM block.
assign sram_addr[0] = pixel_addr[0];
assign sram_addr[1] = pixel_addr[1];
assign sram_addr[2] = pixel_addr[2];
assign sram_addr[3] = pixel_addr[3];
assign frame_idx = fish_clock[0][25:23];
assign data_in = 12'h000; // SRAM is read-only so we tie inputs to zeros.
// End of the SRAM memory block.
// ------------------------------------------------------------------------

// VGA color pixel generator
assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

// ------------------------------------------------------------------------
// An animation clock for the motion of the fish, upper bits of the
// fish clock is the x position of the fish on the VGA screen.
// Note that the fish will move one screen pixel every 2^20 clock cycles,
// or 10.49 msec

always @(posedge clk) begin
  if (~reset_n) begin
    fish_clock[0] <= 0;
    fish_clock[1] <= 0;
    fish_clock[2] <= 0;
    fish_clock[3] <= 0; 
  end else begin
    fish_clock[0] <= fish_clock[0] + 1;
    if (~horizontal_flip[0]) fish_clock[1] <= fish_clock[1] + 1;
    else fish_clock[1] <= fish_clock[1] - 1;
    if (~horizontal_flip[1]) fish_clock[2] <= fish_clock[2] + 1;
    else fish_clock[2] <= fish_clock[2] - 1;
    if (~horizontal_flip[2]) fish_clock[3] <= fish_clock[3] - 1;
    else fish_clock[3] <= fish_clock[3] + 1;
  end
end

assign pos[0] = fish_clock[1][31:20];
assign pos[1] = fish_clock[2][30:19];
assign pos[2] = fish_clock[3][29:18];

always @(posedge clk) begin
    if (~horizontal_flip[0] && pos[0] >= 640) horizontal_flip[0] <= 1;
    else if (horizontal_flip[0] && pos[0] <= 128) horizontal_flip[0] <= 0;
    
    if (~horizontal_flip[1] && pos[1] >= 640) horizontal_flip[1] <= 1;
    else if (horizontal_flip[1] && pos[1] <= 128) horizontal_flip[1] <= 0;
    
    if (horizontal_flip[2] && pos[2] >= 640) horizontal_flip[2] <= 0;
    else if (~horizontal_flip[2] && pos[2] <= 128) horizontal_flip[2] <= 1;
end

// End of the animation clock code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Video frame buffer address generation unit (AGU) with scaling control
// Note that the width x height of the fish image is 64x32, when scaled-up
// on the screen, it becomes 128x64. 'pos' specifies the right edge of the
// fish image.
assign fish_region[0] =  pixel_y >= (FISH1_VPOS<<1) && pixel_y < (FISH1_VPOS+FISH1_H)<<1 &&
           (horizontal_flip[0] ? (pixel_x + 127) >= pos[0] && pixel_x < pos[0] + 1 : (pixel_x + 127) >= pos[0] && pixel_x < pos[0] + 1);

assign fish_region[1] = pixel_y >= (FISH2_VPOS<<1) && pixel_y < (FISH2_VPOS+FISH2_H)<<1 &&
           (pixel_x + 127) >= pos[1] && pixel_x < pos[1] + 1;

assign fish_region[2] = pixel_y >= (FISH3_VPOS<<1) && pixel_y < (FISH3_VPOS+FISH3_H)<<1 &&
           (pixel_x + 127) >= pos[2] && pixel_x < pos[2] + 1;

always @ (posedge clk) begin
  if (~reset_n) begin
    pixel_addr[0] <= 0;
    pixel_addr[1] <= 0;
    pixel_addr[2] <= 0;
    pixel_addr[3] <= 0;
  end else begin
      if (fish_region[0]) begin
        if (horizontal_flip[0])
            pixel_addr[1] <= fish_addr[0][frame_idx] +
                             ((pixel_y>>1)-FISH1_VPOS)*FISH1_W +
                             (FISH1_W - 1) - ((pixel_x +(FISH1_W*2-1)-pos[0])>>1);       
        else
            pixel_addr[1] <= fish_addr[0][frame_idx] +
                              ((pixel_y>>1)-FISH1_VPOS)*FISH1_W +
                              ((pixel_x +(FISH1_W*2-1)-pos[0])>>1);
      end
      if (fish_region[1]) begin
        if (horizontal_flip[1])
            pixel_addr[2] <= fish_addr[1][frame_idx] +
                             ((pixel_y>>1)-FISH2_VPOS)*FISH2_W +
                             (FISH2_W - 1) - ((pixel_x +(FISH2_W*2-1)-pos[1])>>1);       
        else 
            pixel_addr[2] <= fish_addr[1][frame_idx] +
                          ((pixel_y>>1)-FISH2_VPOS)*FISH2_W +
                          ((pixel_x +(FISH2_W*2-1)-pos[1])>>1);
      end
      if (fish_region[2]) begin
        if (horizontal_flip[2])
            pixel_addr[3] <= fish_addr[2][frame_idx] +
                             ((pixel_y>>1)-FISH3_VPOS)*FISH3_W +
                             (FISH3_W - 1) - ((pixel_x +(FISH3_W*2-1)-pos[2])>>1);       
        else 
            pixel_addr[3] <= fish_addr[2][frame_idx] +
                          ((pixel_y>>1)-FISH3_VPOS)*FISH3_W +
                          ((pixel_x +(FISH3_W*2-1)-pos[2])>>1);
      end
        // Scale up a 320x240 image for the 640x480 display.
        // (pixel_x, pixel_y) ranges from (0,0) to (639, 479)
        pixel_addr[0] <= (pixel_y >> 1) * VBUF_W + (pixel_x >> 1);
   end
end
// End of the AGU code.
// ------------------------------------------------------------------------

// ------------------------------------------------------------------------
// Send the video data in the sram to the VGA controller
always @(posedge clk) begin
  if (pixel_tick) rgb_reg <= rgb_next;
end

always @(*) begin
  if (~video_on)
    rgb_next = 12'h000; // Synchronization period, must set RGB values to zero.
  else if (fish_region[0] && data_out[1] != 12'h0f0) rgb_next = data_out[1];
  else if (fish_region[1] && data_out[2] != 12'h0f0) rgb_next = data_out[2];
  else if (fish_region[2] && data_out[3] != 12'h0f0) rgb_next = data_out[3];
  else rgb_next = data_out[0]; // RGB value at (pixel_x, pixel_y)
end
// End of the video data display code.
// ------------------------------------------------------------------------

endmodule
