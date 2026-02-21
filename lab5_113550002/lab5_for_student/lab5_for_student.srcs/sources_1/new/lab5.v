`timescale 1ns / 1ps
/////////////////////////////////////////////////////////
module lab5(
  input clk,
  input reset_n,
  input [3:0] usr_btn,      // button 
  input [3:0] usr_sw,       // switches
  output [3:0] usr_led,     // led
  output LCD_RS,
  output LCD_RW,
  output LCD_E,
  output [3:0] LCD_D
);

assign usr_led = 4'b0000; // turn off led
reg [7:0] slot1[0:8], slot2[0:8], slot3[0:8];
reg [26:0] cnt;
reg [5:0] second = 0;
reg [3:0] cnt1, cnt2, cnt3;
reg [127:0] msg;
reg [3:0] state = 0;
integer i;
reg start = 0, stop1 = 0, stop2 = 0, stop3 = 0;


reg [127:0] row_A; // Initialize the text of the first row. 
reg [127:0] row_B; // Initialize the text of the second row.


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
    
initial begin
    start = 0;
    state = 0;
    stop3 = 0;
    stop2 = 0;
    stop1 = 0;
    for (i = 0; i < 9; i = i + 1) begin
        slot1[i] = "1" + i;
        slot2[i] = "9" - i;
    end
    slot3[0] = "1";
    slot3[1] = "3";
    slot3[2] = "5";
    slot3[3] = "7";
    slot3[4] = "9";
    slot3[5] = "2";
    slot3[6] = "4";
    slot3[7] = "6";
    slot3[8] = "8";
end

always @(posedge clk) begin
    if (start == 1) begin
        if (cnt + 1 == 27'd100_000_000) begin
            if (second + 1 == 18) second <= 0;
            else second <= second + 1;
            cnt <= 0;
        end
        else cnt <= cnt + 1;
        cnt1 <= stop1 == 1 ? cnt1 : second % 9;
        cnt2 <= stop2 == 1 ? cnt2 : second / 2 % 9;
        cnt3 <= stop3 == 1 ? cnt3 : second % 9;
    end
    else begin
        cnt <= 0;
        second <= 0;
        cnt1 <= 0;
        cnt2 <= 0;
        cnt3 <= 0;
    end
end

always @(posedge clk) begin
    if(~reset_n) begin
        start <= 0;
        stop3 <= 0;
        stop2 <= 0;
        stop1 <= 0;
        state <= 0;
    end
    else if (state == 0) begin
        // game finish
        if (~usr_sw[0] && ~usr_sw[1] && ~usr_sw[2] && ~usr_sw[3]) begin
            if (slot1[cnt1] == slot2[cnt2] && slot1[cnt1] == slot3[cnt3]) state <= 1;
            else if ((slot1[cnt1] == slot2[cnt2]) || (slot1[cnt1] == slot3[cnt3]) || (slot2[cnt2] == slot3[cnt3])) state <= 2;
            else state <= 3;
        end        
        row_A <= {"     |", slot1[(cnt1 + 1) % 9], "|", slot2[(cnt2 + 1) % 9], "|", slot3[(cnt3 + 1) % 9], "|    "};
        row_B <= {"     |", slot1[cnt1], "|", slot2[cnt2], "|", slot3[cnt3], "|    "};
        if (~usr_sw[0]) start <= 1;
        if (~usr_sw[1]) stop3 <= 1;
        if (~usr_sw[2]) stop2 <= 1;
        if (~usr_sw[3]) stop1 <= 1;
        if (usr_sw[0] & ~(usr_sw[1] & usr_sw[2] & usr_sw[3])) state <= 4;
        else if (start & usr_sw[0]) state <= 4;
        else if (stop3 & usr_sw[1]) state <= 4;
        else if (stop2 & usr_sw[2]) state <= 4;
        else if (stop1 & usr_sw[3]) state <= 4;
    end
    else if (state == 1) begin
        row_A <= "    Jackpots!   ";        
        row_B <= "    Game over   ";    
    end
    else if (state == 2) begin
        row_A <= "   Free Game!   ";    
        row_B <= "    Game over   ";   
    end
    else if (state == 3) begin
        row_A <= "     Loser!     ";
        row_B <= "    Game over   ";    
    end
    else if (state == 4) begin
        row_A <= "      ERROR     ";
        row_B <= "  game stopped  "; 
    end
end

endmodule
