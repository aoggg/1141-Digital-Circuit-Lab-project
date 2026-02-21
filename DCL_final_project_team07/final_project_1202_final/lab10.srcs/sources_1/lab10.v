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
    input  [3:0] usr_sw,
    output [3:0] usr_led,
    
    // VGA specific I/O ports
    output VGA_HSYNC,
    output VGA_VSYNC,
    output [3:0] VGA_RED,
    output [3:0] VGA_GREEN,
    output [3:0] VGA_BLUE,
    //UART
    input  uart_rx,
    output uart_tx
    );

localparam [2-1:0] S_MAIN_INIT = 2'b00, S_GAME = 2'b01, S_GG = 2'b10;
localparam [3-1:0] T_IDLE = 3'b000, T_BLOCK = 3'b001, T_OP = 3'b010, T_CHECK = 3'b011, T_CLEAR = 3'b100, T_GG = 3'b101, T_HOLD = 3'b110;
localparam SEC = 100000000;
//localparam SEC_d2 = 20000000;//50000000
wire [32-1:0] SEC_d2;
wire [32-1:0] SEC_run;


localparam MSEC2 = 10000000;//0.2s
localparam DELAY_CLEAR = 25000000;//0.25s

localparam NX_COL = 1; 
localparam N1_ROW = 1;
localparam N2_ROW = 4;
localparam N3_ROW = 7;

localparam HOLD_COL = 1; 
localparam HOLD_ROW = 1;

localparam LEVELUP = 1;//should be 10 after debug

wire [3:0] btn_level, btn_pressed;
reg  [3:0] prev_btn_level;
reg [2-1:0] P, P_next;
reg [3-1:0] Q, Q_next;

// declare SRAM control signals
wire [16:0] sram_addr;
reg [9-1:0] block_addr;
reg [8-1:0] digit_addr;
reg [9-1:0] preview_addr;
reg [14-1:0] start_addr, gg_addr;
wire [11:0] data_in;
wire [11:0] data_out, data_out2, data_out3, data_out4, data_out5, data_out6;
wire        sram_we, sram_en;

// General VGA control signals
wire vga_clk;         // 50MHz clock for VGA control
wire video_on;        // when video_on is 0, the VGA controller is sending
                      // synchronization signals to the display device.
  
wire pixel_tick;      // when pixel tick is 1, we must update the RGB value
                      // based for the new coordinate (pixel_x, pixel_y)
  
wire [9:0] pixel_x;   // x coordinate of the next pixel (between 0 ~ 639) 
wire [9:0] pixel_y;   // y coordinate of the next pixel (between 0 ~ 479)
wire [9:0] pixel_x_d2;
wire [9:0] pixel_y_d2;
  
reg  [11:0] rgb_reg;  // RGB value for the current pixel
reg  [11:0] rgb_next; // RGB value for the next pixel
  
// Application-specific VGA signals
reg  [17:0] pixel_addr;

reg [5-1:0] x, y;
reg [3-1:0] bc, bc_n1, bc_n2, bc_n3, bc_hold;//block_color
reg [4-1:0] mp[0:20][0:9];
reg [9:0] mp01[0:19];

reg signed [1:0] wallkick_test1x[0:4-1];
reg signed [1:0] wallkick_test2x[0:4-1];
reg signed [1:0] wallkick_test3x[0:4-1];
reg signed [1:0] wallkick_test4x[0:4-1];
reg signed [2:0] wallkick_test1y[0:4-1];
reg signed [2:0] wallkick_test2y[0:4-1];
reg signed [2:0] wallkick_test3y[0:4-1];
reg signed [2:0] wallkick_test4y[0:4-1];

reg signed [1:0] wallkick2_test1x[0:4-1];
reg signed [1:0] wallkick2_test2x[0:4-1];
reg signed [1:0] wallkick2_test3x[0:4-1];
reg signed [1:0] wallkick2_test4x[0:4-1];
reg signed [2:0] wallkick2_test1y[0:4-1];
reg signed [2:0] wallkick2_test2y[0:4-1];
reg signed [2:0] wallkick2_test3y[0:4-1];
reg signed [2:0] wallkick2_test4y[0:4-1];

//reg [4-1:0] SCORE_NUM_1, SCORE_NUM_2, SCORE_NUM_3, SCORE_NUM_4,
//            SCORE_NUM_5, SCORE_NUM_6, SCORE_NUM_7;
reg [24-1:0] score;
reg [10-1:0] level;
wire [4-1:0] SCORE_NUM[0:7-1];
wire [4-1:0] LVL_NUM[0:3-1];

wire [5-1:0] nowx, nowy;
wire [5-1:0] nextx, nexty;
wire [5-1:0] holdx, holdy;
wire bk_region;

reg key_left = 0;
reg key_right = 0;
reg key_up = 0;
reg key_down = 0;
reg key_z = 0;
reg key_h = 0;
reg key_space = 0;
reg key_left_delay = 0;
reg key_right_delay = 0;
reg key_up_delay = 0;
reg key_down_delay = 0;
reg key_z_delay = 0;
reg key_h_delay = 0;
reg key_space_delay = 0;

reg  [5-1:0] dead_line;

wire [19:0] line_full;
wire any_full;
reg line_full_reg[0:19];
reg [3:0]line_full_cnt;

reg [1:0] current_rot;
wire [1:0] next_rot_val;
assign next_rot_val = current_rot + 1;
wire [1:0] prev_rot_val;
assign prev_rot_val = current_rot - 1;

reg last_action_rotate;
reg is_t_spin;    
integer corners; 
wire t_block_check;

assign t_block_check = (bc == 3'd6);

assign SEC_d2 = (usr_sw[0] || key_down || key_down_delay) ? 50000000 : 5000000;
assign SEC_run = level < 32 ? (SEC_d2 >> 5) * (32-level) : (SEC_d2 >> 7);

always @(*) begin
    corners = 0;
    if (t_block_check) begin
        if (y == 0 || (x > 0 && mp[x-1][y-1] != 0)) corners = corners + 1;
        if (y == 9 || (x > 0 && mp[x-1][y+1] != 0)) corners = corners + 1;
        if (y == 0 || x == 19 || mp[x+1][y-1] != 0) corners = corners + 1;
        if (y == 9 || x == 19 || mp[x+1][y+1] != 0) corners = corners + 1;
    end
end

wire signed [3:0] dx0, dy0, dx1, dy1, dx2, dy2, dx3, dy3;
wire signed [3:0] rdx0, rdy0, rdx1, rdy1, rdx2, rdy2, rdx3, rdy3;
wire signed [3:0] r2dx0, r2dy0, r2dx1, r2dy1, r2dx2, r2dy2, r2dx3, r2dy3;

block_def blk_def (
    .type_in(bc),
    .rot_in(current_rot),
    .dx0(dx0), .dy0(dy0), .dx1(dx1), .dy1(dy1), 
    .dx2(dx2), .dy2(dy2), .dx3(dx3), .dy3(dy3)
);

wire signed [3:0] n1_dx0, n1_dy0, n1_dx1, n1_dy1, n1_dx2, n1_dy2, n1_dx3, n1_dy3;

block_def blk_next1 (
    .type_in(bc_n1),
    .rot_in(2'd0),
    .dx0(n1_dx0), .dy0(n1_dy0), .dx1(n1_dx1), .dy1(n1_dy1), 
    .dx2(n1_dx2), .dy2(n1_dy2), .dx3(n1_dx3), .dy3(n1_dy3)
);

wire signed [3:0] n2_dx0, n2_dy0, n2_dx1, n2_dy1, n2_dx2, n2_dy2, n2_dx3, n2_dy3;

block_def blk_next2 (
    .type_in(bc_n2),
    .rot_in(2'd0),
    .dx0(n2_dx0), .dy0(n2_dy0), .dx1(n2_dx1), .dy1(n2_dy1), 
    .dx2(n2_dx2), .dy2(n2_dy2), .dx3(n2_dx3), .dy3(n2_dy3)
);

wire signed [3:0] n3_dx0, n3_dy0, n3_dx1, n3_dy1, n3_dx2, n3_dy2, n3_dx3, n3_dy3;

block_def blk_next3 (
    .type_in(bc_n3),
    .rot_in(2'd0),
    .dx0(n3_dx0), .dy0(n3_dy0), .dx1(n3_dx1), .dy1(n3_dy1), 
    .dx2(n3_dx2), .dy2(n3_dy2), .dx3(n3_dx3), .dy3(n3_dy3)
);

wire signed [3:0] hold_dx0, hold_dy0, hold_dx1, hold_dy1, hold_dx2, hold_dy2, hold_dx3, hold_dy3;

block_def blk_hold (
    .type_in(bc_hold),
    .rot_in(2'd0),
    .dx0(hold_dx0), .dy0(hold_dy0), .dx1(hold_dx1), .dy1(hold_dy1), 
    .dx2(hold_dx2), .dy2(hold_dy2), .dx3(hold_dx3), .dy3(hold_dy3)
);

block_def blk_check (
    .type_in(bc),
    .rot_in(next_rot_val),
    .dx0(rdx0), .dy0(rdy0), .dx1(rdx1), .dy1(rdy1), 
    .dx2(rdx2), .dy2(rdy2), .dx3(rdx3), .dy3(rdy3)
);

block_def blk_check2 (
    .type_in(bc),
    .rot_in(prev_rot_val),
    .dx0(r2dx0), .dy0(r2dy0), .dx1(r2dx1), .dy1(r2dy1), 
    .dx2(r2dx2), .dy2(r2dy2), .dx3(r2dx3), .dy3(r2dy3)
);

// 用來計算 4 個點的絕對座標 (Absolute Coordinates)
// x, y 是方塊中心點
wire signed [5:0] ax0, ay0, ax1, ay1, ax2, ay2, ax3, ay3;
assign ax0 = $signed({1'b0, x}) + dx0; 
assign ay0 = $signed({1'b0, y}) + dy0;
assign ax1 = $signed({1'b0, x}) + dx1; 
assign ay1 = $signed({1'b0, y}) + dy1;
assign ax2 = $signed({1'b0, x}) + dx2; 
assign ay2 = $signed({1'b0, y}) + dy2;
assign ax3 = $signed({1'b0, x}) + dx3; 
assign ay3 = $signed({1'b0, y}) + dy3;

wire signed [5:0] rx0, ry0, rx1, ry1, rx2, ry2, rx3, ry3;
assign rx0 = $signed({1'b0, x}) + rdx0; 
assign ry0 = $signed({1'b0, y}) + rdy0;
assign rx1 = $signed({1'b0, x}) + rdx1; 
assign ry1 = $signed({1'b0, y}) + rdy1;
assign rx2 = $signed({1'b0, x}) + rdx2; 
assign ry2 = $signed({1'b0, y}) + rdy2;
assign rx3 = $signed({1'b0, x}) + rdx3; 
assign ry3 = $signed({1'b0, y}) + rdy3;

wire signed [5:0] r2x0, r2y0, r2x1, r2y1, r2x2, r2y2, r2x3, r2y3;
assign r2x0 = $signed({1'b0, x}) + r2dx0; 
assign r2y0 = $signed({1'b0, y}) + r2dy0;
assign r2x1 = $signed({1'b0, x}) + r2dx1; 
assign r2y1 = $signed({1'b0, y}) + r2dy1;
assign r2x2 = $signed({1'b0, x}) + r2dx2; 
assign r2y2 = $signed({1'b0, y}) + r2dy2;
assign r2x3 = $signed({1'b0, x}) + r2dx3; 
assign r2y3 = $signed({1'b0, y}) + r2dy3;

reg [4:0] ghost_dist;
integer g_i;
reg collision_flag;

always @(*) begin
    ghost_dist = 0;
    collision_flag = 0;
    for (g_i = 1; g_i <= 17; g_i = g_i + 1) begin
        if (!collision_flag) begin
            if ((ax0 + g_i < 20 && !mp01[ax0 + g_i][ay0]) &&
                (ax1 + g_i < 20 && !mp01[ax1 + g_i][ay1]) &&
                (ax2 + g_i < 20 && !mp01[ax2 + g_i][ay2]) &&
                (ax3 + g_i < 20 && !mp01[ax3 + g_i][ay3])) begin
                ghost_dist = g_i;
            end else begin
                collision_flag = 1;
            end
        end
    end
end

wire signed [5:0] gx0, gy0, gx1, gy1, gx2, gy2, gx3, gy3;
    
assign gx0 = ax0 + ghost_dist; assign gy0 = ay0;
assign gx1 = ax1 + ghost_dist; assign gy1 = ay1;
assign gx2 = ax2 + ghost_dist; assign gy2 = ay2;
assign gx3 = ax3 + ghost_dist; assign gy3 = ay3;

// Next 1 的 4 個點絕對座標
wire signed [5:0] n1_ax0, n1_ay0, n1_ax1, n1_ay1, n1_ax2, n1_ay2, n1_ax3, n1_ay3;
assign n1_ax0 = N1_ROW + n1_dx0; assign n1_ay0 = NX_COL + n1_dy0;
assign n1_ax1 = N1_ROW + n1_dx1; assign n1_ay1 = NX_COL + n1_dy1;
assign n1_ax2 = N1_ROW + n1_dx2; assign n1_ay2 = NX_COL + n1_dy2;
assign n1_ax3 = N1_ROW + n1_dx3; assign n1_ay3 = NX_COL + n1_dy3;

// Next 2 的 4 個點絕對座標
wire signed [5:0] n2_ax0, n2_ay0, n2_ax1, n2_ay1, n2_ax2, n2_ay2, n2_ax3, n2_ay3;
assign n2_ax0 = N2_ROW + n2_dx0; assign n2_ay0 = NX_COL + n2_dy0;
assign n2_ax1 = N2_ROW + n2_dx1; assign n2_ay1 = NX_COL + n2_dy1;
assign n2_ax2 = N2_ROW + n2_dx2; assign n2_ay2 = NX_COL + n2_dy2;
assign n2_ax3 = N2_ROW + n2_dx3; assign n2_ay3 = NX_COL + n2_dy3;

// Next 3 的 4 個點絕對座標
wire signed [5:0] n3_ax0, n3_ay0, n3_ax1, n3_ay1, n3_ax2, n3_ay2, n3_ax3, n3_ay3;
assign n3_ax0 = N3_ROW + n3_dx0; assign n3_ay0 = NX_COL + n3_dy0;
assign n3_ax1 = N3_ROW + n3_dx1; assign n3_ay1 = NX_COL + n3_dy1;
assign n3_ax2 = N3_ROW + n3_dx2; assign n3_ay2 = NX_COL + n3_dy2;
assign n3_ax3 = N3_ROW + n3_dx3; assign n3_ay3 = NX_COL + n3_dy3;

// hold 的 4 個點絕對座標
wire signed [5:0] hold_ax0, hold_ay0, hold_ax1, hold_ay1, hold_ax2, hold_ay2, hold_ax3, hold_ay3;
assign hold_ax0 = HOLD_ROW + hold_dx0; assign hold_ay0 = HOLD_COL + hold_dy0;
assign hold_ax1 = HOLD_ROW + hold_dx1; assign hold_ay1 = HOLD_COL + hold_dy1;
assign hold_ax2 = HOLD_ROW + hold_dx2; assign hold_ay2 = HOLD_COL + hold_dy2;
assign hold_ax3 = HOLD_ROW + hold_dx3; assign hold_ay3 = HOLD_COL + hold_dy3;

wire move_down_ok;
assign move_down_ok = 
    (mp[ax0+1][ay0] == 0 && (ax0+1) <= 19) &&
    (mp[ax1+1][ay1] == 0 && (ax1+1) <= 19) &&
    (mp[ax2+1][ay2] == 0 && (ax2+1) <= 19) &&
    (mp[ax3+1][ay3] == 0 && (ax3+1) <= 19);

wire move_right_ok; 
assign move_right_ok = 
    (ay0 < 9 && mp[ax0][ay0+1] == 0) &&
    (ay1 < 9 && mp[ax1][ay1+1] == 0) &&
    (ay2 < 9 && mp[ax2][ay2+1] == 0) &&
    (ay3 < 9 && mp[ax3][ay3+1] == 0);

wire move_left_ok;
assign move_left_ok = 
    (ay0 > 0 && mp[ax0][ay0-1] == 0) &&
    (ay1 > 0 && mp[ax1][ay1-1] == 0) &&
    (ay2 > 0 && mp[ax2][ay2-1] == 0) &&
    (ay3 > 0 && mp[ax3][ay3-1] == 0);

wire rotate_ok;
assign rotate_ok = 
    (ry0 >= 0 && ry0 <= 9 && rx0 <= 19 && mp[rx0][ry0] == 0) &&
    (ry1 >= 0 && ry1 <= 9 && rx1 <= 19 && mp[rx1][ry1] == 0) &&
    (ry2 >= 0 && ry2 <= 9 && rx2 <= 19 && mp[rx2][ry2] == 0) &&
    (ry3 >= 0 && ry3 <= 9 && rx3 <= 19 && mp[rx3][ry3] == 0);

wire rotate_ok2;
assign rotate_ok2 = 
    (r2y0 >= 0 && r2y0 <= 9 && r2x0 <= 19 && mp[r2x0][r2y0] == 0) &&
    (r2y1 >= 0 && r2y1 <= 9 && r2x1 <= 19 && mp[r2x1][r2y1] == 0) &&
    (r2y2 >= 0 && r2y2 <= 9 && r2x2 <= 19 && mp[r2x2][r2y2] == 0) &&
    (r2y3 >= 0 && r2y3 <= 9 && r2x3 <= 19 && mp[r2x3][r2y3] == 0);

wire wallkick_1_ok;
assign wallkick_1_ok = 
    (ry0+wallkick_test1x[current_rot] >= 0 && ry0+wallkick_test1x[current_rot] <= 9 && rx0+wallkick_test1y[current_rot] <= 19 && mp[rx0+wallkick_test1y[current_rot]][ry0+wallkick_test1x[current_rot]] == 0) &&
    (ry1+wallkick_test1x[current_rot] >= 0 && ry1+wallkick_test1x[current_rot] <= 9 && rx1+wallkick_test1y[current_rot] <= 19 && mp[rx1+wallkick_test1y[current_rot]][ry1+wallkick_test1x[current_rot]] == 0) &&
    (ry2+wallkick_test1x[current_rot] >= 0 && ry2+wallkick_test1x[current_rot] <= 9 && rx2+wallkick_test1y[current_rot] <= 19 && mp[rx2+wallkick_test1y[current_rot]][ry2+wallkick_test1x[current_rot]] == 0) &&
    (ry3+wallkick_test1x[current_rot] >= 0 && ry3+wallkick_test1x[current_rot] <= 9 && rx3+wallkick_test1y[current_rot] <= 19 && mp[rx3+wallkick_test1y[current_rot]][ry3+wallkick_test1x[current_rot]] == 0);
wire wallkick_2_ok;
assign wallkick_2_ok = 
    (ry0+wallkick_test2x[current_rot] >= 0 && ry0+wallkick_test2x[current_rot] <= 9 && rx0+wallkick_test2y[current_rot] <= 19 && mp[rx0+wallkick_test2y[current_rot]][ry0+wallkick_test2x[current_rot]] == 0) &&
    (ry1+wallkick_test2x[current_rot] >= 0 && ry1+wallkick_test2x[current_rot] <= 9 && rx1+wallkick_test2y[current_rot] <= 19 && mp[rx1+wallkick_test2y[current_rot]][ry1+wallkick_test2x[current_rot]] == 0) &&
    (ry2+wallkick_test2x[current_rot] >= 0 && ry2+wallkick_test2x[current_rot] <= 9 && rx2+wallkick_test2y[current_rot] <= 19 && mp[rx2+wallkick_test2y[current_rot]][ry2+wallkick_test2x[current_rot]] == 0) &&
    (ry3+wallkick_test2x[current_rot] >= 0 && ry3+wallkick_test2x[current_rot] <= 9 && rx3+wallkick_test2y[current_rot] <= 19 && mp[rx3+wallkick_test2y[current_rot]][ry3+wallkick_test2x[current_rot]] == 0);
wire wallkick_3_ok;
assign wallkick_3_ok = 
    (ry0+wallkick_test3x[current_rot] >= 0 && ry0+wallkick_test3x[current_rot] <= 9 && rx0+wallkick_test3y[current_rot] <= 19 && mp[rx0+wallkick_test3y[current_rot]][ry0+wallkick_test3x[current_rot]] == 0) &&
    (ry1+wallkick_test3x[current_rot] >= 0 && ry1+wallkick_test3x[current_rot] <= 9 && rx1+wallkick_test3y[current_rot] <= 19 && mp[rx1+wallkick_test3y[current_rot]][ry1+wallkick_test3x[current_rot]] == 0) &&
    (ry2+wallkick_test3x[current_rot] >= 0 && ry2+wallkick_test3x[current_rot] <= 9 && rx2+wallkick_test3y[current_rot] <= 19 && mp[rx2+wallkick_test3y[current_rot]][ry2+wallkick_test3x[current_rot]] == 0) &&
    (ry3+wallkick_test3x[current_rot] >= 0 && ry3+wallkick_test3x[current_rot] <= 9 && rx3+wallkick_test3y[current_rot] <= 19 && mp[rx3+wallkick_test3y[current_rot]][ry3+wallkick_test3x[current_rot]] == 0);
wire wallkick_4_ok;
assign wallkick_4_ok = 
    (ry0+wallkick_test4x[current_rot] >= 0 && ry0+wallkick_test4x[current_rot] <= 9 && rx0+wallkick_test4y[current_rot] <= 19 && mp[rx0+wallkick_test4y[current_rot]][ry0+wallkick_test4x[current_rot]] == 0) &&
    (ry1+wallkick_test4x[current_rot] >= 0 && ry1+wallkick_test4x[current_rot] <= 9 && rx1+wallkick_test4y[current_rot] <= 19 && mp[rx1+wallkick_test4y[current_rot]][ry1+wallkick_test4x[current_rot]] == 0) &&
    (ry2+wallkick_test4x[current_rot] >= 0 && ry2+wallkick_test4x[current_rot] <= 9 && rx2+wallkick_test4y[current_rot] <= 19 && mp[rx2+wallkick_test4y[current_rot]][ry2+wallkick_test4x[current_rot]] == 0) &&
    (ry3+wallkick_test4x[current_rot] >= 0 && ry3+wallkick_test4x[current_rot] <= 9 && rx3+wallkick_test4y[current_rot] <= 19 && mp[rx3+wallkick_test4y[current_rot]][ry3+wallkick_test4x[current_rot]] == 0);

wire wallkick_1_ok2;
assign wallkick_1_ok2 = 
    (r2y0+wallkick2_test1x[current_rot] >= 0 && r2y0+wallkick2_test1x[current_rot] <= 9 && r2x0+wallkick2_test1y[current_rot] <= 19 && mp[r2x0+wallkick2_test1y[current_rot]][r2y0+wallkick2_test1x[current_rot]] == 0) &&
    (r2y1+wallkick2_test1x[current_rot] >= 0 && r2y1+wallkick2_test1x[current_rot] <= 9 && r2x1+wallkick2_test1y[current_rot] <= 19 && mp[r2x1+wallkick2_test1y[current_rot]][r2y1+wallkick2_test1x[current_rot]] == 0) &&
    (r2y2+wallkick2_test1x[current_rot] >= 0 && r2y2+wallkick2_test1x[current_rot] <= 9 && r2x2+wallkick2_test1y[current_rot] <= 19 && mp[r2x2+wallkick2_test1y[current_rot]][r2y2+wallkick2_test1x[current_rot]] == 0) &&
    (r2y3+wallkick2_test1x[current_rot] >= 0 && r2y3+wallkick2_test1x[current_rot] <= 9 && r2x3+wallkick2_test1y[current_rot] <= 19 && mp[r2x3+wallkick2_test1y[current_rot]][r2y3+wallkick2_test1x[current_rot]] == 0);
wire wallkick_2_ok2;
assign wallkick_2_ok2 = 
    (r2y0+wallkick2_test2x[current_rot] >= 0 && r2y0+wallkick2_test2x[current_rot] <= 9 && r2x0+wallkick2_test2y[current_rot] <= 19 && mp[r2x0+wallkick2_test2y[current_rot]][r2y0+wallkick2_test2x[current_rot]] == 0) &&
    (r2y1+wallkick2_test2x[current_rot] >= 0 && r2y1+wallkick2_test2x[current_rot] <= 9 && r2x1+wallkick2_test2y[current_rot] <= 19 && mp[r2x1+wallkick2_test2y[current_rot]][r2y1+wallkick2_test2x[current_rot]] == 0) &&
    (r2y2+wallkick2_test2x[current_rot] >= 0 && r2y2+wallkick2_test2x[current_rot] <= 9 && r2x2+wallkick2_test2y[current_rot] <= 19 && mp[r2x2+wallkick2_test2y[current_rot]][r2y2+wallkick2_test2x[current_rot]] == 0) &&
    (r2y3+wallkick2_test2x[current_rot] >= 0 && r2y3+wallkick2_test2x[current_rot] <= 9 && r2x3+wallkick2_test2y[current_rot] <= 19 && mp[r2x3+wallkick2_test2y[current_rot]][r2y3+wallkick2_test2x[current_rot]] == 0);
wire wallkick_3_ok2;
assign wallkick_3_ok2 = 
    (r2y0+wallkick2_test3x[current_rot] >= 0 && r2y0+wallkick2_test3x[current_rot] <= 9 && r2x0+wallkick2_test3y[current_rot] <= 19 && mp[r2x0+wallkick2_test3y[current_rot]][r2y0+wallkick2_test3x[current_rot]] == 0) &&
    (r2y1+wallkick2_test3x[current_rot] >= 0 && r2y1+wallkick2_test3x[current_rot] <= 9 && r2x1+wallkick2_test3y[current_rot] <= 19 && mp[r2x1+wallkick2_test3y[current_rot]][r2y1+wallkick2_test3x[current_rot]] == 0) &&
    (r2y2+wallkick2_test3x[current_rot] >= 0 && r2y2+wallkick2_test3x[current_rot] <= 9 && r2x2+wallkick2_test3y[current_rot] <= 19 && mp[r2x2+wallkick2_test3y[current_rot]][r2y2+wallkick2_test3x[current_rot]] == 0) &&
    (r2y3+wallkick2_test3x[current_rot] >= 0 && r2y3+wallkick2_test3x[current_rot] <= 9 && r2x3+wallkick2_test3y[current_rot] <= 19 && mp[r2x3+wallkick2_test3y[current_rot]][r2y3+wallkick2_test3x[current_rot]] == 0);
wire wallkick_4_ok2;
assign wallkick_4_ok2 = 
    (r2y0+wallkick2_test4x[current_rot] >= 0 && r2y0+wallkick2_test4x[current_rot] <= 9 && r2x0+wallkick2_test4y[current_rot] <= 19 && mp[r2x0+wallkick2_test4y[current_rot]][r2y0+wallkick2_test4x[current_rot]] == 0) &&
    (r2y1+wallkick2_test4x[current_rot] >= 0 && r2y1+wallkick2_test4x[current_rot] <= 9 && r2x1+wallkick2_test4y[current_rot] <= 19 && mp[r2x1+wallkick2_test4y[current_rot]][r2y1+wallkick2_test4x[current_rot]] == 0) &&
    (r2y2+wallkick2_test4x[current_rot] >= 0 && r2y2+wallkick2_test4x[current_rot] <= 9 && r2x2+wallkick2_test4y[current_rot] <= 19 && mp[r2x2+wallkick2_test4y[current_rot]][r2y2+wallkick2_test4x[current_rot]] == 0) &&
    (r2y3+wallkick2_test4x[current_rot] >= 0 && r2y3+wallkick2_test4x[current_rot] <= 9 && r2x3+wallkick2_test4y[current_rot] <= 19 && mp[r2x3+wallkick2_test4y[current_rot]][r2y3+wallkick2_test4x[current_rot]] == 0);


wire [3:0] w_bcd6, w_bcd5, w_bcd4, w_bcd3, w_bcd2, w_bcd1, w_bcd0;
wire [3:0] x_bcd2, x_bcd1, x_bcd0;

Converter score_converter (
    .bin_in (score),
    .bcd6   (w_bcd6),
    .bcd5   (w_bcd5),
    .bcd4   (w_bcd4),
    .bcd3   (w_bcd3),
    .bcd2   (w_bcd2),
    .bcd1   (w_bcd1),
    .bcd0   (w_bcd0)
);

Converter lvl_converter (
    .bin_in (level),
    .bcd6   (),
    .bcd5   (),
    .bcd4   (),
    .bcd3   (),
    .bcd2   (x_bcd2),
    .bcd1   (x_bcd1),
    .bcd0   (x_bcd0)
);

assign SCORE_NUM[0] = w_bcd6;
assign SCORE_NUM[1] = w_bcd5;
assign SCORE_NUM[2] = w_bcd4;
assign SCORE_NUM[3] = w_bcd3;
assign SCORE_NUM[4] = w_bcd2;
assign SCORE_NUM[5] = w_bcd1;
assign SCORE_NUM[6] = w_bcd0;

assign LVL_NUM[0] = x_bcd2;
assign LVL_NUM[1] = x_bcd1;
assign LVL_NUM[2] = x_bcd0;

assign line_full[0] = &mp01[0];
assign line_full[1] = &mp01[1];
assign line_full[2] = &mp01[2];
assign line_full[3] = &mp01[3];
assign line_full[4] = &mp01[4];
assign line_full[5] = &mp01[5];
assign line_full[6] = &mp01[6];
assign line_full[7] = &mp01[7];
assign line_full[8] = &mp01[8];
assign line_full[9] = &mp01[9];
assign line_full[10] = &mp01[10];
assign line_full[11] = &mp01[11];
assign line_full[12] = &mp01[12];
assign line_full[13] = &mp01[13];
assign line_full[14] = &mp01[14];
assign line_full[15] = &mp01[15];
assign line_full[16] = &mp01[16];
assign line_full[17] = &mp01[17];
assign line_full[18] = &mp01[18];
assign line_full[19] = &mp01[19];
assign any_full = |line_full;

integer lf_i;

always @(posedge vga_clk) begin
    if(~reset_n) begin
        for(lf_i = 0;lf_i <= 19;lf_i = lf_i + 1) begin
            line_full_reg[lf_i] <= 0;
        end
    end else begin
        for(lf_i = 0;lf_i <= 19;lf_i = lf_i + 1) begin
            line_full_reg[lf_i] <= line_full[lf_i];
        end
    end
end

// Declare the video buffer size
localparam VBUF_W = 320; // video buffer width
localparam VBUF_H = 240; // video buffer height

// Set parameters for the fish images
localparam FISH_VPOS   = 64; // Vertical location of the fish in the sea image.
localparam BG_X        = 250;
localparam BG_Y        = 32;
localparam BG_W        = 181; // Width of the bg.
localparam BG_H        = 201; // Height of the bg.

localparam NEXT_X      = 213;
localparam NEXT_Y      = 64;

localparam HOLD_X      = 75;
localparam HOLD_Y      = 72;

localparam BK_X        = 120;
localparam BK_Y        = 50;
localparam BK_W        = 8;
localparam BK_H        = 8;

localparam LVL_X       = 93;
localparam LVL_Y       = 182;

localparam NUM_W     = 4;
localparam NUM_H     = 6;

localparam SCORE_Y     = 205;

localparam START_X = 0;
localparam START_Y = 100;

assign nowx = (pixel_x_d2 - BK_X) >> 3;//div 8
assign nowy = (pixel_y_d2 - BK_Y) >> 3;//div 8

assign nextx = (pixel_x_d2 - NEXT_X) >> 3;//div 8
assign nexty = (pixel_y_d2 - NEXT_Y) >> 3;//div 8

assign holdx = (pixel_x_d2 - HOLD_X) >> 3;//div 8
assign holdy = (pixel_y_d2 - HOLD_Y) >> 3;//div 8

reg [6:0] SCORE_X_POS [0:7-1]; 
reg [6:0] LVL_X_POS [0:3-1]; 

initial begin
    mp[20][0] = 1;
    mp[20][1] = 1;    
    mp[20][2] = 1;
    mp[20][3] = 1;
    mp[20][4] = 1;
    mp[20][5] = 1;
    mp[20][6] = 1;
    mp[20][7] = 1;
    mp[20][8] = 1;
    mp[20][9] = 1;
    SCORE_X_POS[0] = 7'd73;
    SCORE_X_POS[1] = 7'd78;
    SCORE_X_POS[2] = 7'd83;
    SCORE_X_POS[3] = 7'd88;
    SCORE_X_POS[4] = 7'd93;
    SCORE_X_POS[5] = 7'd98;
    SCORE_X_POS[6] = 7'd103;
    LVL_X_POS[0] = 7'd93;
    LVL_X_POS[1] = 7'd98;
    LVL_X_POS[2] = 7'd103;
    
    mp[19][1] = 1;
    mp[19][2] = 1;
    mp[19][3] = 1;
    mp[19][4] = 1;
    
    mp[18][1] = 3;
    mp[18][2] = 3;
    mp[18][3] = 3;
    mp[17][3] = 3;
    
    mp[17][1] = 4;
    mp[17][2] = 4;
    mp[16][1] = 4;
    mp[16][2] = 4;
    
    mp[19][5] = 5;
    mp[18][4] = 5;
    mp[18][5] = 5;
    mp[17][4] = 5;
    
    mp[19][6] = 6;
    mp[18][6] = 6;
    mp[18][7] = 6;
    mp[17][6] = 6;
    
    mp[19][7] = 2;
    mp[19][8] = 2;
    mp[18][8] = 2;
    mp[17][8] = 2;
    
    mp[16][5] = 7;
    mp[15][5] = 7;
    mp[15][6] = 7;
    mp[14][6] = 7;

    wallkick_test1x[0] = -1;
    wallkick_test1x[1] = 1;
    wallkick_test1x[2] = 1;
    wallkick_test1x[3] = -1;
    
    wallkick_test2x[0] = -1;
    wallkick_test2x[1] = 1;
    wallkick_test2x[2] = 1;
    wallkick_test2x[3] = -1;
    
    wallkick_test3x[0] = 0;
    wallkick_test3x[1] = 0;
    wallkick_test3x[2] = 0;
    wallkick_test3x[3] = 0;
    
    wallkick_test4x[0] = -1;
    wallkick_test4x[1] = 1;
    wallkick_test4x[2] = 1;
    wallkick_test4x[3] = -1;
    
    wallkick_test1y[0] = 0;
    wallkick_test1y[1] = 0;
    wallkick_test1y[2] = 0;
    wallkick_test1y[3] = 0;
    
    wallkick_test2y[0] = -1;
    wallkick_test2y[1] = 1;
    wallkick_test2y[2] = -1;
    wallkick_test2y[3] = 1;
    
    wallkick_test3y[0] = 2;
    wallkick_test3y[1] = -2;
    wallkick_test3y[2] = 2;
    wallkick_test3y[3] = -2;
    
    wallkick_test4y[0] = 2;
    wallkick_test4y[1] = -2;
    wallkick_test4y[2] = 2;
    wallkick_test4y[3] = -2;

    wallkick2_test1x[0] = 1;
    wallkick2_test1x[1] = 1;
    wallkick2_test1x[2] = -1;
    wallkick2_test1x[3] = -1;
    
    wallkick2_test2x[0] = 1;
    wallkick2_test2x[1] = 1;
    wallkick2_test2x[2] = -1;
    wallkick2_test2x[3] = -1;
    
    wallkick2_test3x[0] = 0;
    wallkick2_test3x[1] = 0;
    wallkick2_test3x[2] = 0;
    wallkick2_test3x[3] = 0;
    
    wallkick2_test4x[0] = 1;
    wallkick2_test4x[1] = 1;
    wallkick2_test4x[2] = -1;
    wallkick2_test4x[3] = -1;
    
    wallkick2_test1y[0] = 0;
    wallkick2_test1y[1] = 0;
    wallkick2_test1y[2] = 0;
    wallkick2_test1y[3] = 0;
    
    wallkick2_test2y[0] = -1;
    wallkick2_test2y[1] = 1;
    wallkick2_test2y[2] = -1;
    wallkick2_test2y[3] = 1;
    
    wallkick2_test3y[0] = 2;
    wallkick2_test3y[1] = -2;
    wallkick2_test3y[2] = 2;
    wallkick2_test3y[3] = -2;
    
    wallkick2_test4y[0] = 2;
    wallkick2_test4y[1] = -2;
    wallkick2_test4y[2] = 2;
    wallkick2_test4y[3] = -2;
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

debounce btn_db0(
  .clk(vga_clk),
  .btn_input(usr_btn[0]),
  .btn_output(btn_level[0])
);
debounce btn_db1(
  .clk(vga_clk),
  .btn_input(usr_btn[1]),
  .btn_output(btn_level[1])
);
debounce btn_db2(
  .clk(vga_clk),
  .btn_input(usr_btn[2]),
  .btn_output(btn_level[2])
);
debounce btn_db3(
  .clk(vga_clk),
  .btn_input(usr_btn[3]),
  .btn_output(btn_level[3])
);

// ------------------------------------------------------------------------
// The following code describes an initialized SRAM memory block that
// stores a 320x240 12-bit seabed image, plus two 64x32 fish images.
sram #(.DATA_WIDTH(12), .ADDR_WIDTH(17), .RAM_SIZE(VBUF_W*VBUF_H), .fn("new_bg.mem"))
  ram0 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(sram_addr), .data_i(data_in), .data_o(data_out));

sram #(.DATA_WIDTH(12), .ADDR_WIDTH(9), .RAM_SIZE(BK_W*BK_H*8), .fn("block.mem"))
  ram1 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(block_addr), .data_i(data_in), .data_o(data_out2));

sram #(.DATA_WIDTH(12), .ADDR_WIDTH(9), .RAM_SIZE(NUM_W*NUM_H*10), .fn("number2.mem"))
  ram2 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(digit_addr), .data_i(data_in), .data_o(data_out3));

sram #(.DATA_WIDTH(12), .ADDR_WIDTH(9), .RAM_SIZE(BK_W*BK_H*7), .fn("preview.mem"))
  ram3 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(preview_addr), .data_i(data_in), .data_o(data_out4));

sram #(.DATA_WIDTH(12), .ADDR_WIDTH(14), .RAM_SIZE(50*320), .fn("tetris.mem"))
  ram4 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(start_addr), .data_i(data_in), .data_o(data_out5));

sram #(.DATA_WIDTH(12), .ADDR_WIDTH(14), .RAM_SIZE(50*320), .fn("gg.mem"))
  ram5 (.clk(clk), .we(sram_we), .en(sram_en),
          .addr(gg_addr), .data_i(data_in), .data_o(data_out6));
          
          

assign sram_we = &usr_btn;
assign sram_en = 1;
assign sram_addr = pixel_addr;
assign data_in = 12'h000;

assign {VGA_RED, VGA_GREEN, VGA_BLUE} = rgb_reg;

assign btn_pressed = (btn_level & ~prev_btn_level);

assign pixel_x_d2 = pixel_x >> 1;
assign pixel_y_d2 = pixel_y >> 1;

assign bk_region = (120 <= pixel_x_d2) && (pixel_x_d2 < 200) && (50 <= pixel_y_d2) && (pixel_y_d2 < 210);

wire start_bk_region;
assign start_bk_region = (0 <= pixel_x_d2) && (pixel_x_d2 < 320) && (100 <= pixel_y_d2) && (pixel_y_d2 < 150);

reg bk_reg_delay, num_reg_delay, all_white, preview, start_bg, gg_bg;

always @(posedge vga_clk) begin
  if (~reset_n)
    prev_btn_level <= 0;
  else
    prev_btn_level <= btn_level;
end

reg [32-1:0] counter_gg;

//handle GG
always @(posedge clk) begin
    if(~reset_n) begin
        dead_line <= 0;
        counter_gg <= 0;
    end else begin
        case(P)
            S_MAIN_INIT: begin
                dead_line <= 0;
                counter_gg <= 0;
            end
            S_GG: begin
                counter_gg <= counter_gg + 1;
                if(counter_gg == MSEC2) begin
                    if(dead_line < 30)
                        dead_line <= dead_line + 1;
                    counter_gg <= 0;
                end
            end
            default: begin
            end
        endcase
    end
end

integer ii0;

//handle PIXEL
always @ (posedge clk) begin
    if (~reset_n) begin
        pixel_addr <= 0;
        bk_reg_delay <= 0;
        num_reg_delay <= 0;
        all_white <= 0;
        preview <= 0;
        start_bg <= 0;
        gg_bg <= 0;
    end else begin
        case(P)
            S_MAIN_INIT: begin
                pixel_addr <= pixel_y_d2 * VBUF_W + pixel_x_d2;
                all_white <= 0;
                bk_reg_delay <= 0;
                num_reg_delay <= 0;
                preview <= 0;
                start_bg <= 0;
                gg_bg <= 0;
                if (start_bk_region) begin
                    start_addr <= (pixel_y_d2-START_Y)*320+pixel_x_d2;
                    start_bg <= 1;
                end else if (bk_region) begin
                    if(mp[nowy][nowx] != 0) begin
                         block_addr <= (((pixel_y_d2-BK_Y) & 3'd7)<<3)+((pixel_x_d2-BK_X) & 3'd7)+((mp[nowy][nowx]-1)<<6);
                         bk_reg_delay <= 1;
                    end
                end
            end
            S_GAME: begin
                pixel_addr <= pixel_y_d2 * VBUF_W + pixel_x_d2;
                all_white <= 0;
                bk_reg_delay <= 0;
                num_reg_delay <= 0;
                preview <= 0;
                start_bg <= 0;
                gg_bg <= 0;
                if(bk_region) begin
                    if(mp[nowy][nowx] == 4'd15) begin
                        all_white <= 1;
                    end else if(mp[nowy][nowx] != 0) begin
                         block_addr <= (((pixel_y_d2-BK_Y) & 3'd7)<<3)+((pixel_x_d2-BK_X) & 3'd7)+((mp[nowy][nowx]-1)<<6);
                         bk_reg_delay <= 1;
                    end else if (!mp01[nowy][nowx] && ((nowy == ax0 && nowx == ay0) || (nowy == ax1 && nowx == ay1) || (nowy == ax2 && nowx == ay2) || (nowy == ax3 && nowx == ay3))) begin
                         block_addr <= (((pixel_y_d2-BK_Y) & 3'd7)<<3)+((pixel_x_d2-BK_X) & 3'd7)+((bc-1)<<6);
                         bk_reg_delay <= 1;
                    end else if (!mp01[nowy][nowx] && ((nowy == gx0 && nowx == gy0) || (nowy == gx1 && nowx == gy1) || (nowy == gx2 && nowx == gy2) || (nowy == gx3 && nowx == gy3))) begin
//                         block_addr <= (((pixel_y_d2-BK_Y) & 3'd7)<<3)+((pixel_x_d2-BK_X) & 3'd7)+((bc-1)<<6);
//                         bk_reg_delay <= 1;
                         preview_addr <= (((pixel_y_d2-BK_Y) & 3'd7)<<3)+((pixel_x_d2-BK_X) & 3'd7)+((bc-1)<<6);
                         preview <= 1;
                    end
                end
                else if ( (nexty == n1_ax0 && nextx == n1_ay0) || (nexty == n1_ax1 && nextx == n1_ay1) || 
                          (nexty == n1_ax2 && nextx == n1_ay2) || (nexty == n1_ax3 && nextx == n1_ay3) ) begin
                     block_addr <= (((pixel_y_d2-NEXT_Y) & 3'd7)<<3)+((pixel_x_d2-NEXT_X) & 3'd7)+((bc_n1-1)<<6);
                     bk_reg_delay <= 1;
                end
                else if ( (nexty == n2_ax0 && nextx == n2_ay0) || (nexty == n2_ax1 && nextx == n2_ay1) || 
                          (nexty == n2_ax2 && nextx == n2_ay2) || (nexty == n2_ax3 && nextx == n2_ay3) ) begin
                     block_addr <= (((pixel_y_d2-NEXT_Y) & 3'd7)<<3)+((pixel_x_d2-NEXT_X) & 3'd7)+((bc_n2-1)<<6);
                     bk_reg_delay <= 1;
                end
                else if ( (nexty == n3_ax0 && nextx == n3_ay0) || (nexty == n3_ax1 && nextx == n3_ay1) || 
                          (nexty == n3_ax2 && nextx == n3_ay2) || (nexty == n3_ax3 && nextx == n3_ay3) ) begin
                     block_addr <= (((pixel_y_d2-NEXT_Y) & 3'd7)<<3)+((pixel_x_d2-NEXT_X) & 3'd7)+((bc_n3-1)<<6);
                     bk_reg_delay <= 1;
                end
                else if (( (holdy == hold_ax0 && holdx == hold_ay0) || (holdy == hold_ax1 && holdx == hold_ay1) || 
                          (holdy == hold_ax2 && holdx == hold_ay2) || (holdy == hold_ax3 && holdx == hold_ay3) ) && bc_hold != 0) begin
                     block_addr <= (((pixel_y_d2-HOLD_Y) & 3'd7)<<3)+((pixel_x_d2-HOLD_X) & 3'd7)+((bc_hold-1)<<6);
                     bk_reg_delay <= 1;
                end
                else if (SCORE_Y <= pixel_y_d2 && pixel_y_d2 < SCORE_Y+NUM_H) begin
                    for(ii0 = 0;ii0 < 7;ii0 = ii0 + 1) begin
                        if(SCORE_X_POS[ii0] <= pixel_x_d2 && pixel_x_d2 < SCORE_X_POS[ii0] + NUM_W) begin
                            digit_addr <= (((pixel_y_d2 - SCORE_Y) << 2) + (pixel_x_d2 - SCORE_X_POS[ii0]) + NUM_H*NUM_W*SCORE_NUM[ii0]);
                            num_reg_delay <= 1;
                        end 
                    end
                end
                else if (LVL_Y <= pixel_y_d2 && pixel_y_d2 < LVL_Y+NUM_H) begin
                    for(ii0 = 0;ii0 < 3;ii0 = ii0 + 1) begin
                        if(LVL_X_POS[ii0] <= pixel_x_d2 && pixel_x_d2 < LVL_X_POS[ii0] + NUM_W) begin
                            digit_addr <= (((pixel_y_d2 - LVL_Y) << 2) + (pixel_x_d2 - LVL_X_POS[ii0]) + NUM_H*NUM_W*LVL_NUM[ii0]);
                            num_reg_delay <= 1;
                        end 
                    end
                end
            end
            S_GG: begin
                pixel_addr <= pixel_y_d2 * VBUF_W + pixel_x_d2;
                all_white <= 0;
                bk_reg_delay <= 0;
                num_reg_delay <= 0;
                preview <= 0;
                start_bg <= 0;
                gg_bg <= 0;
                if(dead_line == 30 && start_bk_region) begin
                    gg_addr <= (pixel_y_d2-START_Y)*320+pixel_x_d2;
                    gg_bg <= 1;
                end 
                if(bk_region) begin
                    if(mp[nowy][nowx] != 0) begin
                        if(nowy < dead_line) begin
                            block_addr <= (((pixel_y_d2-BK_Y) & 3'd7)<<3)+((pixel_x_d2-BK_X) & 3'd7)+((7)<<6);
                            bk_reg_delay <= 1;
                        end else begin
                            block_addr <= (((pixel_y_d2-BK_Y) & 3'd7)<<3)+((pixel_x_d2-BK_X) & 3'd7)+((mp[nowy][nowx]-1)<<6);
                            bk_reg_delay <= 1;
                        end
                    end else begin
                        bk_reg_delay <= 0;
                    end
                end
                else if (pixel_y_d2 >= SCORE_Y && pixel_y_d2 < SCORE_Y+NUM_H) begin
                    for(ii0 = 0;ii0 < 7;ii0 = ii0 + 1) begin
                        if(SCORE_X_POS[ii0] <= pixel_x_d2 && pixel_x_d2 < SCORE_X_POS[ii0] + NUM_W) begin
                            digit_addr <= (((pixel_y_d2 - SCORE_Y) << 2) + (pixel_x_d2 - SCORE_X_POS[ii0]) + NUM_H*NUM_W*SCORE_NUM[ii0]);
                            num_reg_delay <= 1;
                        end 
                    end
                end
                else if (LVL_Y <= pixel_y_d2 && pixel_y_d2 < LVL_Y+NUM_H) begin
                    for(ii0 = 0;ii0 < 3;ii0 = ii0 + 1) begin
                        if(LVL_X_POS[ii0] <= pixel_x_d2 && pixel_x_d2 < LVL_X_POS[ii0] + NUM_W) begin
                            digit_addr <= (((pixel_y_d2 - LVL_Y) << 2) + (pixel_x_d2 - LVL_X_POS[ii0]) + NUM_H*NUM_W*LVL_NUM[ii0]);
                            num_reg_delay <= 1;
                        end 
                    end
                end
            end
            default: begin
            
            end
        endcase
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
  else if(all_white)
    rgb_next = 12'hfff;
  else if(gg_bg) begin
    if(data_out6 == 12'h0f0) begin
        if(bk_reg_delay)
            rgb_next = { data_out2[11:8] >> 1, data_out2[7:4] >> 1, data_out2[3:0] >> 1 };
        else
            rgb_next = { data_out[11:8] >> 1, data_out[7:4] >> 1, data_out[3:0] >> 1 };
    end else
        rgb_next = data_out6;
  end else if(bk_reg_delay)
    rgb_next = data_out2;
  else if(num_reg_delay)
    rgb_next = data_out3;
  else if(preview)
    rgb_next = data_out4;
  else if(start_bg)
    if(data_out5 == 12'h0f0) begin
        rgb_next = { data_out[11:8] >> 1, data_out[7:4] >> 1, data_out[3:0] >> 1 };
    end else begin
        rgb_next = data_out5;
    end
  else
    rgb_next = usr_sw[3] ? data_out : { data_out[11:8] >> 1, data_out[7:4] >> 1, data_out[3:0] >> 1 }; // RGB value at (pixel_x, pixel_y)
end
// End of the video data display code.
// ------------------------------------------------------------------------

//RANDOM lfsr
reg [31:0] lfsr = 8'h1;

always @(posedge vga_clk) begin
    if (~reset_n)
        lfsr <= 32'hACE1_2345;
    else begin
        lfsr <= {lfsr[30:0], lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0]};
    end
end

wire [2:0] rnd;//1~7

assign rnd = (lfsr[3:0] % 7) + 3'd1;

reg [29-1:0] clock;//5e8

wire clkSEC;

assign clkSEC = (clock >= SEC_run);

always @(posedge vga_clk) begin
    if(~reset_n) begin
        clock <= 0;
    end else begin
        clock <= clock + 1;
        if(clock >= SEC_run)
            clock <= 0;
    end
end

reg [5-1:0] wp, chrow;
reg [4-1:0] tmpy;
reg         do_clear;
reg         hold;

reg [4-1:0] clear_cu;


reg [32-1:0] delay;

integer i, j;

//handle INGAME
always @(posedge vga_clk) begin
    case(Q)
        T_IDLE: begin
            x <= 1;
            y <= 4;
            bc <= bc_n1;
            bc_n1 <= bc_n2;
            bc_n2 <= bc_n3;
            bc_n3 <= rnd;
            current_rot <= 0;
            delay <= 0;
            last_action_rotate <= 0;
            if (P_next == S_MAIN_INIT) begin
                for(i = 0;i <= 20;i = i + 1) begin
                    mp01[i] <= 0;
                    for(j = 0;j <= 9;j = j + 1) begin
                        mp[i][j] <= 0;
                    end
                end
                mp[19][1] <= 1;
                mp[19][2] <= 1;
                mp[19][3] <= 1;
                mp[19][4] <= 1;
                
                mp[18][1] <= 3;
                mp[18][2] <= 3;
                mp[18][3] <= 3;
                mp[17][3] <= 3;
                
                mp[17][1] <= 4;
                mp[17][2] <= 4;
                mp[16][1] <= 4;
                mp[16][2] <= 4;
                
                mp[19][5] <= 5;
                mp[18][4] <= 5;
                mp[18][5] <= 5;
                mp[17][4] <= 5;
                
                mp[19][6] <= 6;
                mp[18][6] <= 6;
                mp[18][7] <= 6;
                mp[17][6] <= 6;
                
                mp[19][7] <= 2;
                mp[19][8] <= 2;
                mp[18][8] <= 2;
                mp[17][8] <= 2;
                
                mp[16][5] <= 7;
                mp[15][5] <= 7;
                mp[15][6] <= 7;
                mp[14][6] <= 7;
            end else begin
                for(i = 0;i <= 20;i = i + 1) begin
                    mp01[i] <= 0;
                    for(j = 0;j <= 9;j = j + 1) begin
                        mp[i][j] <= 0;
                    end
                end
            end
            bc_hold <= 0;
            hold <= 0;
            score <= 0;
            level <= 1;
            clear_cu <= 0;
        end
        T_BLOCK: begin
            x <= 1;
            y <= 4;
            bc <= bc_n1;
            bc_n1 <= bc_n2;
            bc_n2 <= bc_n3;
            bc_n3 <= rnd;
            current_rot <= 0;
            last_action_rotate <= 0;
            if (is_t_spin) begin
                case(line_full_cnt)
                    4'd0: score <= score + 400;
                    4'd1: score <= score + 800;
                    4'd2: score <= score + 1200;
                    4'd3: score <= score + 1600;
                    default: score <= score;
                endcase
            end else begin
                case(line_full_cnt)
                    4'd1: score <= score + 100;
                    4'd2: score <= score + 300;
                    4'd3: score <= score + 500;
                    4'd4: score <= score + 800;
                    default: score <= score;
                endcase
            end
            clear_cu = clear_cu + line_full_cnt;
            if(clear_cu >= LEVELUP) begin
                clear_cu = 0;
                level <= level + 1;
            end
        end
        T_OP: begin
            if(clkSEC) begin
                if (move_down_ok) begin
                    x <= x + 1;
                end else begin
                    mp[ax0][ay0] <= bc; mp01[ax0][ay0] <= 1;
                    mp[ax1][ay1] <= bc; mp01[ax1][ay1] <= 1;
                    mp[ax2][ay2] <= bc; mp01[ax2][ay2] <= 1;
                    mp[ax3][ay3] <= bc; mp01[ax3][ay3] <= 1;
                    if (t_block_check && last_action_rotate && corners >= 3) begin
                        is_t_spin <= 1;
                    end else begin
                        is_t_spin <= 0;
                    end
                end
                last_action_rotate <= 0;
            end else if (btn_pressed[0] || key_right || key_right_delay) begin
                if(move_right_ok) begin
                    y <= y + 1;
                    last_action_rotate <= 0;
                end
            end else if (btn_pressed[1] || key_left || key_left_delay) begin
                if(move_left_ok) begin
                    y <= y - 1;
                    last_action_rotate <= 0;
                end
            end else if (btn_pressed[2] || key_up || key_up_delay) begin
                if(rotate_ok) begin
                    current_rot <= next_rot_val;
                    last_action_rotate <= 1;
                end else if(bc != 1 && bc != 4)begin
                    if(wallkick_1_ok) begin
                        current_rot <= next_rot_val;
                        last_action_rotate <= 1;
                        x <= x + wallkick_test1y[current_rot];
                        y <= y + wallkick_test1x[current_rot];
                    end
                    else if(wallkick_2_ok) begin
                        current_rot <= next_rot_val;
                        last_action_rotate <= 1;
                        x <= x + wallkick_test2y[current_rot];
                        y <= y + wallkick_test2x[current_rot];
                    end
                    else if(wallkick_3_ok) begin
                        current_rot <= next_rot_val;
                        last_action_rotate <= 1;
                        x <= x + wallkick_test3y[current_rot];
                        y <= y + wallkick_test3x[current_rot];
                    end
                    else if(wallkick_4_ok) begin
                        current_rot <= next_rot_val;
                        last_action_rotate <= 1;
                        x <= x + wallkick_test4y[current_rot];
                        y <= y + wallkick_test4x[current_rot];
                    end
                end
            end else if (key_z || key_z_delay) begin
                if(rotate_ok2) begin
                    current_rot <= prev_rot_val;
                    last_action_rotate <= 1;
                end else if(bc != 1 && bc != 4)begin
                    if(wallkick_1_ok2) begin
                        current_rot <= prev_rot_val;
                        last_action_rotate <= 1;
                        x <= x + wallkick2_test1y[current_rot];
                        y <= y + wallkick2_test1x[current_rot];
                    end
                    else if(wallkick_2_ok2) begin
                        current_rot <= prev_rot_val;
                        last_action_rotate <= 1;
                        x <= x + wallkick2_test2y[current_rot];
                        y <= y + wallkick2_test2x[current_rot];
                    end
                    else if(wallkick_3_ok2) begin
                        current_rot <= prev_rot_val;
                        last_action_rotate <= 1;
                        x <= x + wallkick2_test3y[current_rot];
                        y <= y + wallkick2_test3x[current_rot];
                    end
                    else if(wallkick_4_ok2) begin
                        current_rot <= prev_rot_val;
                        last_action_rotate <= 1;
                        x <= x + wallkick2_test4y[current_rot];
                        y <= y + wallkick2_test4x[current_rot];
                    end
                end
            end else if (btn_pressed[3] || key_h || key_h_delay) begin
                last_action_rotate <= 0;
                if(!hold) begin
                    hold <= 1;
                end
            end else if (key_down || key_down_delay) begin
            end else if (key_space || key_space_delay) begin
                last_action_rotate <= 0;
                x <= x + ghost_dist;
            end
        end
        T_HOLD: begin
            if (bc_hold != 0) begin
                bc <= bc_hold;
                x <= 1;
                y <= 4;
                current_rot <= 0;
                bc_hold <= bc;
                last_action_rotate <= 0;
            end else begin
                bc_hold <= bc;
            end
        end
        T_CLEAR: begin
            delay <= delay + 1;
            if(!any_full)
                delay <= DELAY_CLEAR;
            hold <= 0;
            case(delay)
                32'd1: begin
                    for(chrow = 20;chrow >= 1;chrow = chrow - 1) begin
                        if(line_full_reg[chrow-1]) begin
                            mp[chrow-1][0] <= 0;
                            mp[chrow-1][9] <= 0;
                            mp[chrow-1][1] <= 4'd15;
                            mp[chrow-1][8] <= 4'd15;
                        end
                    end
                end
                32'd5000000: begin
                    for(chrow = 20;chrow >= 1;chrow = chrow - 1) begin
                        if(line_full_reg[chrow-1]) begin
                            mp[chrow-1][1] <= 0;
                            mp[chrow-1][8] <= 0;
                            mp[chrow-1][2] <= 4'd15;
                            mp[chrow-1][7] <= 4'd15;
                        end
                    end
                end
                32'd10000000: begin
                    for(chrow = 20;chrow >= 1;chrow = chrow - 1) begin
                        if(line_full_reg[chrow-1]) begin
                            mp[chrow-1][2] <= 0;
                            mp[chrow-1][7] <= 0;
                            mp[chrow-1][3] <= 4'd15;
                            mp[chrow-1][6] <= 4'd15;
                        end
                    end
                end
                32'd15000000: begin
                    for(chrow = 20;chrow >= 1;chrow = chrow - 1) begin
                        if(line_full_reg[chrow-1]) begin
                            mp[chrow-1][3] <= 0;
                            mp[chrow-1][6] <= 0;
                            mp[chrow-1][4] <= 4'd15;
                            mp[chrow-1][5] <= 4'd15;
                        end
                    end
                end
                32'd20000000: begin
                    for(chrow = 20;chrow >= 1;chrow = chrow - 1) begin
                        if(line_full_reg[chrow-1]) begin
                            mp[chrow-1][4] <= 0;
                            mp[chrow-1][5] <= 0;
                        end
                    end
                end
                DELAY_CLEAR: begin
                    delay <= 0;
                    line_full_cnt = 0;
                    wp = 19;
                    for(chrow = 20;chrow >= 1;chrow = chrow - 1) begin
                        if (!line_full_reg[chrow-1]) begin
                            for(tmpy = 0;tmpy <= 9;tmpy = tmpy + 1) begin
                                mp[chrow-1][tmpy] <= 0;
                                mp01[chrow-1][tmpy] <= 0;
                                
                                mp[wp][tmpy] <= mp[chrow-1][tmpy];
                                mp01[wp][tmpy] <= mp01[chrow-1][tmpy];
                            end
                            wp = wp - 1;
                        end
                        else line_full_cnt = line_full_cnt + 1;
                    end
                end
                default: begin
                    
                end
            endcase
        end
        default: begin
            
        end
    endcase
end

always @(posedge vga_clk) begin
  if (~reset_n) begin
    P <= S_MAIN_INIT;
  end else begin
    P <= P_next;
  end
end

always @(posedge vga_clk) begin
  if (~reset_n) begin
    Q <= T_IDLE;
  end else begin
    Q <= Q_next;
  end
end

always @(*) begin // FSM next-state logic
  case (P)
    S_MAIN_INIT: begin
        if(btn_pressed[3])
            P_next = S_GAME;
        else
            P_next = S_MAIN_INIT;
    end
    S_GAME: begin
        if(Q == T_GG)//temp
            P_next = S_GG;
        else
            P_next = S_GAME;
    end
    S_GG: begin
        if(btn_pressed[3])//temp
            P_next = S_MAIN_INIT;
        else
            P_next = S_GG;
    end
    default:
      P_next = S_MAIN_INIT;
  endcase
end

always @(*) begin // FSM next-state logic
  case (Q)
    T_IDLE: begin
        if(P == S_GAME)
            Q_next = T_BLOCK;
        else
            Q_next = T_IDLE;
    end
    T_BLOCK: begin
        if(mp[0][4] != 0 || mp[0][5] != 0 || mp[0][3] != 0)
            Q_next = T_GG;
        else
            Q_next = T_OP;
    end
    T_OP: begin
        if(clkSEC && !move_down_ok)
            Q_next = T_CLEAR;
        else if ((btn_pressed[3] || key_h || key_h_delay) && ~hold) 
            Q_next = T_HOLD;
        else
            Q_next = T_OP;
    end
    T_HOLD: begin
        if (bc_hold == 0)
            Q_next = T_BLOCK;
        else
            Q_next = T_OP;
    end    
    T_CLEAR: begin
        if(delay == DELAY_CLEAR)
            Q_next = T_BLOCK;
        else
            Q_next = T_CLEAR;
    end
    T_GG: begin
        if(P == S_MAIN_INIT)
            Q_next = T_IDLE;
        else
            Q_next = T_GG;
    end
    default:
      Q_next = T_IDLE;
  endcase
end

localparam S_IDLE       = 0;
localparam S_WAIT_BRACKET = 1;
localparam S_WAIT_CODE  = 2;

localparam CHAR_ESC     = 8'h1B;
localparam CHAR_BRACKET = 8'h5B;
localparam CHAR_UP      = 8'h41; // A
localparam CHAR_DOWN    = 8'h42; // B
localparam CHAR_RIGHT   = 8'h43; // C
localparam CHAR_LEFT    = 8'h44; // D
localparam CHAR_SPACE   = 8'h20; // 空白鍵
localparam CHAR_Z_UPPER = 8'h5A; // Z (大寫)
localparam CHAR_Z_LOWER = 8'h7A; // z (小寫)
localparam CHAR_H_UPPER = 8'h48; // H (大寫)
localparam CHAR_H_LOWER = 8'h68; // h (小寫)

localparam CHAR_W_UPPER = 8'h57; // W (大寫)
localparam CHAR_W_LOWER = 8'h77; // w (小寫)
localparam CHAR_A_UPPER = 8'h41; // A (大寫)
localparam CHAR_A_LOWER = 8'h61; // a (小寫)
localparam CHAR_S_UPPER = 8'h53; // S (大寫)
localparam CHAR_S_LOWER = 8'h73; // s (小寫)
localparam CHAR_D_UPPER = 8'h44; // D (大寫)
localparam CHAR_D_LOWER = 8'h64; // d (小寫)

reg [1:0] uart_state;

wire received;
wire [7:0] rx_byte;
wire transmit;
wire [7:0] tx_byte;
wire is_receiving;
wire is_transmitting;
wire recv_error;

assign transmit = 0; 
assign tx_byte = 0;

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

always @(posedge clk) begin
    if (~reset_n) begin
        uart_state <= S_IDLE;
        key_left <= 0;
        key_right <= 0;
        key_up <= 0;
        key_down <= 0;
        key_h <= 0;
        key_z <= 0;
        key_space <= 0;
    end else begin
        key_left <= 0;
        key_right <= 0;
        key_up <= 0;
        key_down <= 0;
        key_h <= 0;
        key_z <= 0;
        key_space <= 0;
        
        key_left_delay <= key_left;
        key_right_delay <= key_right;
        key_up_delay <= key_up;
        key_down_delay <= key_down;
        key_h_delay <= key_h;
        key_z_delay <= key_z;
        key_space_delay <= key_space;
        if (received) begin
            case (uart_state)
                S_IDLE: begin
                    if (rx_byte == CHAR_ESC) begin
                        uart_state <= S_WAIT_BRACKET; 
                    end else begin
                        if (rx_byte == CHAR_SPACE)
                            key_space <= 1;
                        else if (rx_byte == CHAR_Z_UPPER || rx_byte == CHAR_Z_LOWER)
                            key_z <= 1;
                        else if (rx_byte == CHAR_H_UPPER || rx_byte == CHAR_H_LOWER)
                            key_h <= 1;
                        else if (rx_byte == CHAR_W_UPPER || rx_byte == CHAR_W_LOWER)
                            key_up <= 1;
                        else if (rx_byte == CHAR_A_UPPER || rx_byte == CHAR_A_LOWER)
                            key_left <= 1;
                        else if (rx_byte == CHAR_S_UPPER || rx_byte == CHAR_S_LOWER)
                            key_down <= 1;
                        else if (rx_byte == CHAR_D_UPPER || rx_byte == CHAR_D_LOWER)
                            key_right <= 1;
                        uart_state <= S_IDLE;
                    end
                end
                S_WAIT_BRACKET: begin
                    if (rx_byte == CHAR_BRACKET) 
                        uart_state <= S_WAIT_CODE;
                    else 
                        uart_state <= S_IDLE;
                end
                S_WAIT_CODE: begin
                    if (rx_byte == CHAR_UP)
                        key_up <= 1;
                    else if (rx_byte == CHAR_DOWN)
                        key_down <= 1;
                    else if (rx_byte == CHAR_RIGHT)
                        key_right <= 1;
                    else if (rx_byte == CHAR_LEFT)
                        key_left <= 1;
                    uart_state <= S_IDLE;
                end
                default: uart_state <= S_IDLE;
            endcase
        end
    end
end

assign usr_led[0] = key_h;
assign usr_led[1] = key_down;
assign usr_led[2] = key_left;
assign usr_led[3] = key_right;

endmodule
