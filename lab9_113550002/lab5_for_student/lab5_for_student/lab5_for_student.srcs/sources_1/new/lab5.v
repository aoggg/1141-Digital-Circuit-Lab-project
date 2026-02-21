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

localparam [3:0] S_MAIN_INIT = 4'd0, S_MAIN_CALC = 4'd1, S_MAIN_SHOW = 4'd2, S_MAIN_WAIT = 4'd3;

reg [127:0] row_A = "Press BTN3 to   "; // Initialize the text of the first row. 
reg [127:0] row_B = "Start calculate "; // Initialize the text of the second row.
reg [3:0] P, P_next;
reg finish = 0;
wire btn_status, btn_press;
reg prev_btn_status;
reg [7:0] btn;
reg [55:0] timer;
reg done;

reg [255:0] passwd_hash = 256'hae74e53a6f447e10150dd2e83ad3f0289606aec5354ae31fe87f3500b802dfd2;
wire [255:0] test_out[0:9];
reg [71:0] test_pwd[0:9], ans_pwd;
reg start;
wire [9:0] sha_finish;

//module sha256(
//    input start,
//    input [71:0] pwd,
//    input clk,
//    output [255:0] hash,
//    output finish
//);

(* DONT_TOUCH = "yes" *)
sha256 sha0(.start(start), .pwd(test_pwd[0]), .clk(clk), .hash(test_out[0]), .finish(sha_finish[0]));
(* DONT_TOUCH = "yes" *)
sha256 sha1(.start(start), .pwd(test_pwd[1]), .clk(clk), .hash(test_out[1]), .finish(sha_finish[1]));
(* DONT_TOUCH = "yes" *)
sha256 sha2(.start(start), .pwd(test_pwd[2]), .clk(clk), .hash(test_out[2]), .finish(sha_finish[2]));
(* DONT_TOUCH = "yes" *)
sha256 sha3(.start(start), .pwd(test_pwd[3]), .clk(clk), .hash(test_out[3]), .finish(sha_finish[3]));
(* DONT_TOUCH = "yes" *)
sha256 sha4(.start(start), .pwd(test_pwd[4]), .clk(clk), .hash(test_out[4]), .finish(sha_finish[4]));
(* DONT_TOUCH = "yes" *)
sha256 sha5(.start(start), .pwd(test_pwd[5]), .clk(clk), .hash(test_out[5]), .finish(sha_finish[5]));
(* DONT_TOUCH = "yes" *)
sha256 sha6(.start(start), .pwd(test_pwd[6]), .clk(clk), .hash(test_out[6]), .finish(sha_finish[6]));
(* DONT_TOUCH = "yes" *)
sha256 sha7(.start(start), .pwd(test_pwd[7]), .clk(clk), .hash(test_out[7]), .finish(sha_finish[7]));
(* DONT_TOUCH = "yes" *)
sha256 sha8(.start(start), .pwd(test_pwd[8]), .clk(clk), .hash(test_out[8]), .finish(sha_finish[8]));
(* DONT_TOUCH = "yes" *)
sha256 sha9(.start(start), .pwd(test_pwd[9]), .clk(clk), .hash(test_out[9]), .finish(sha_finish[9]));

//begin debouncing
assign btn_status = & btn;
assign btn_press = ~prev_btn_status & btn_status;

always @(posedge clk) begin
    btn <= {btn[6:0], usr_btn[3]};
    prev_btn_status <= btn_status;
end
//finish debouncing

assign usr_led = 4'b0000; // turn off led
//assign usr_led = P;

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

// begin of FSM setting
always @(posedge clk) begin
    if (~reset_n) P <= S_MAIN_INIT;
    else P = P_next;
end

always @(*) begin
    case(P)
        S_MAIN_INIT: begin
            if (btn_press) P_next = S_MAIN_CALC;
            else P_next = S_MAIN_INIT;
        end  
        S_MAIN_WAIT: begin
            if (done) P_next = S_MAIN_SHOW;
            else P_next = S_MAIN_CALC;        
        end
        S_MAIN_CALC: begin
            if (done) P_next = S_MAIN_SHOW;
            else if (&sha_finish) P_next = S_MAIN_WAIT;
            else P_next = S_MAIN_CALC;    
        end
        S_MAIN_SHOW: begin
            P_next = S_MAIN_SHOW;
        end
    endcase
end
// end of FSM setting

always @(posedge clk) begin
    if (P == S_MAIN_INIT) timer <= 0;
    else if (P == S_MAIN_CALC || P == S_MAIN_WAIT) timer <= timer + 1;
end

// begin of LCD message
always @(posedge clk) begin
    if (P == S_MAIN_INIT) begin
        row_A <= "Press BTN3 to   ";
        row_B <= "Start calculate ";
    end else if (P == S_MAIN_CALC) begin
        row_A <= "Calculating...  ";
        row_B <= "                "; 
//        row_B <= {"Pwd:", test_pwd[0], "   "};
    end else if (P == S_MAIN_WAIT) begin
        row_A <= "Calculating...  ";
        row_B <= "                ";        
    end else if (P == S_MAIN_SHOW) begin
        row_A <= {"Pwd:", ans_pwd, "   "};
        row_B <= {"T:", ((timer[55:52] > 9)? "7" : "0") + timer[55:52],
                        ((timer[51:48] > 9)? "7" : "0") + timer[51:48],
                        ((timer[47:44] > 9)? "7" : "0") + timer[47:44],
                        ((timer[43:40] > 9)? "7" : "0") + timer[43:40],
                        ((timer[39:36] > 9)? "7" : "0") + timer[39:36],
                        ((timer[35:32] > 9)? "7" : "0") + timer[35:32],
                        ((timer[31:28] > 9)? "7" : "0") + timer[31:28],
                        ((timer[27:24] > 9)? "7" : "0") + timer[27:24],
                        ((timer[23:20] > 9)? "7" : "0") + timer[23:20],
                        ((timer[19:16] > 9)? "7" : "0") + timer[19:16],
                        ((timer[15:12] > 9)? "7" : "0") + timer[15:12],
                        ((timer[11:8] > 9)? "7" : "0") + timer[11:8],
                        ((timer[7:4] > 9)? "7" : "0") + timer[7:4],
                        ((timer[3:0] > 9)? "7" : "0") + timer[3:0]};
    end
end
// end of LCD message

integer idx;
always @(posedge clk) begin
    if (P == S_MAIN_INIT) begin
        start <= 0;
        done <= 0;
        test_pwd[0] <= "000000000";
        test_pwd[1] <= "100000000";
        test_pwd[2] <= "200000000";
        test_pwd[3] <= "300000000";
        test_pwd[4] <= "400000000";
        test_pwd[5] <= "500000000";
        test_pwd[6] <= "600000000";
        test_pwd[7] <= "700000000";
        test_pwd[8] <= "800000000";
        test_pwd[9] <= "900000000";
    end else if (P == S_MAIN_WAIT) begin
        if (test_out[0] == passwd_hash) begin
            ans_pwd <= test_pwd[0];
            done <= 1;
        end else if (test_out[1] == passwd_hash) begin
            ans_pwd <= test_pwd[1];
            done <= 1;
        end else if (test_out[2] == passwd_hash) begin
            ans_pwd <= test_pwd[2];
            done <= 1;
        end else if (test_out[3] == passwd_hash) begin
            ans_pwd <= test_pwd[3];
            done <= 1;
        end else if (test_out[4] == passwd_hash) begin
            ans_pwd <= test_pwd[4];
            done <= 1;
        end else if (test_out[5] == passwd_hash) begin
            ans_pwd <= test_pwd[5];
            done <= 1;
        end else if (test_out[6] == passwd_hash) begin
            ans_pwd <= test_pwd[6];
            done <= 1;
        end else if (test_out[7] == passwd_hash) begin
            ans_pwd <= test_pwd[7];
            done <= 1;
        end else if (test_out[8] == passwd_hash) begin
            ans_pwd <= test_pwd[8];
            done <= 1;
        end else if (test_out[9] == passwd_hash) begin
            ans_pwd <= test_pwd[9];
            done <= 1;
        end else begin
            for (idx = 0; idx < 10; idx = idx + 1) begin
                if (test_pwd[idx][0] & test_pwd[idx][3]) begin
                    test_pwd[idx][7:0] <= "0";
                    if (test_pwd[idx][8] & test_pwd[idx][11]) begin
                        test_pwd[idx][15:8] <= "0";
                        if (test_pwd[idx][16] & test_pwd[idx][19]) begin
                            test_pwd[idx][23:16] <= "0";
                            if (test_pwd[idx][24] & test_pwd[idx][27]) begin
                                test_pwd[idx][31:24] <= "0";
                                if (test_pwd[idx][32] & test_pwd[idx][35]) begin
                                    test_pwd[idx][39:32] <= "0";
                                    if (test_pwd[idx][40] & test_pwd[idx][43]) begin
                                        test_pwd[idx][47:40] <= "0";
                                        if (test_pwd[idx][48] & test_pwd[idx][51]) begin
                                            test_pwd[idx][55:48] <= "0";
                                            if (test_pwd[idx][56] & test_pwd[idx][59]) begin
                                                test_pwd[idx][63:56] <= "0";
                                                test_pwd[idx][71:64] <= test_pwd[idx][71:64] + 1;
                                            end else test_pwd[idx][63:56] <= test_pwd[idx][63:56] + 1;
                                        end else test_pwd[idx][55:48] <= test_pwd[idx][55:48] + 1;
                                    end else test_pwd[idx][47:40] <= test_pwd[idx][47:40] + 1;
                                end else test_pwd[idx][39:32] <= test_pwd[idx][39:32] + 1;
                            end else test_pwd[idx][31:24] <= test_pwd[idx][31:24] + 1;
                        end else test_pwd[idx][23:16] <= test_pwd[idx][23:16] + 1;
                    end else test_pwd[idx][15:8] <= test_pwd[idx][15:8] + 1;
                end else test_pwd[idx][7:0] <= test_pwd[idx][7:0] + 1;
            end 
            start <= 0;
        end
    end else if (P == S_MAIN_CALC) begin
        start <= 1;    
    end
end

endmodule

module sha256(
    input start,
    input [71:0] pwd,
    input clk,
    output [255:0] hash,
    output finish
);

localparam [0:2047] Ks = {
    32'h428a2f98, 32'h71374491, 32'hb5c0fbcf, 32'he9b5dba5,
    32'h3956c25b, 32'h59f111f1, 32'h923f82a4, 32'hab1c5ed5,
    32'hd807aa98, 32'h12835b01, 32'h243185be, 32'h550c7dc3,
    32'h72be5d74, 32'h80deb1fe, 32'h9bdc06a7, 32'hc19bf174,
    32'he49b69c1, 32'hefbe4786, 32'h0fc19dc6, 32'h240ca1cc,
    32'h2de92c6f, 32'h4a7484aa, 32'h5cb0a9dc, 32'h76f988da,
    32'h983e5152, 32'ha831c66d, 32'hb00327c8, 32'hbf597fc7,
    32'hc6e00bf3, 32'hd5a79147, 32'h06ca6351, 32'h14292967,
    32'h27b70a85, 32'h2e1b2138, 32'h4d2c6dfc, 32'h53380d13,
    32'h650a7354, 32'h766a0abb, 32'h81c2c92e, 32'h92722c85,
    32'ha2bfe8a1, 32'ha81a664b, 32'hc24b8b70, 32'hc76c51a3,
    32'hd192e819, 32'hd6990624, 32'hf40e3585, 32'h106aa070,
    32'h19a4c116, 32'h1e376c08, 32'h2748774c, 32'h34b0bcb5,
    32'h391c0cb3, 32'h4ed8aa4a, 32'h5b9cca4f, 32'h682e6ff3,
    32'h748f82ee, 32'h78a5636f, 32'h84c87814, 32'h8cc70208,
    32'h90befffa, 32'ha4506ceb, 32'hbef9a3f7, 32'hc67178f2};

localparam [31:0] a_temp = 32'h6a09e667;
localparam [31:0] b_temp = 32'hbb67ae85;
localparam [31:0] c_temp = 32'h3c6ef372;
localparam [31:0] d_temp = 32'ha54ff53a;
localparam [31:0] e_temp = 32'h510e527f;
localparam [31:0] f_temp = 32'h9b05688c;
localparam [31:0] g_temp = 32'h1f83d9ab;
localparam [31:0] h_temp = 32'h5be0cd19;

localparam [3:0] S_IDLE = 4'd0, S_PADDING = 4'd1, S_COMPRESS = 4'd2, S_FINAL = 4'd3, S_CALC = 4'd4, S_INIT = 4'd5;

reg [6:0] counter = 0;
reg [3:0] P, P_next;
reg [0:511] padded_msg;
reg done = 0;
assign finish = done;
reg [255:0] hash_msg;
assign hash = hash_msg;
reg [31:0] A, B, C, D, E, F, G, H;
reg [31:0] sigmaA, sigmaE, ch, ma, sigma0, sigma1, t1, t2;
reg [31:0] W[0:15];
wire [6:0] temp1, temp2, temp3, temp4;
assign temp1 = counter - 2;
assign temp2 = counter - 7;
assign temp3 = counter - 15;
assign temp4 = counter - 16;

//FSM
always @(posedge clk) begin
    P <= P_next;    
end

always @(*) begin
    case(P)
        S_IDLE: begin
            if (start) P_next = S_INIT;
            else P_next = S_IDLE;
        end
        S_INIT: begin
            P_next = S_PADDING;
        end
        S_PADDING: begin
            P_next = S_CALC;
        end
        S_COMPRESS: begin
            if (counter == 63) P_next = S_FINAL;
            else P_next = S_CALC;
        end
        S_CALC: begin
            P_next = S_COMPRESS;
        end
        S_FINAL: begin
            P_next = S_IDLE;
        end                    
    endcase
end
//FSM

// calculuate

always @(posedge clk) begin
    if (P == S_INIT) begin
        padded_msg <= 0;
        A <= a_temp;
        B <= b_temp;
        C <= c_temp;
        D <= d_temp;
        E <= e_temp;
        F <= f_temp;
        G <= g_temp;
        H <= h_temp;
        done <= 0;
        counter <= 0;
    end else if (P == S_PADDING) begin
        padded_msg <= {pwd, 1'd1, 375'd0, 64'd72};
    end else if (P == S_CALC) begin
        ch <= (E & F) ^ (~E & G);
        ma <= (A & B) ^ (A & C) ^ (B & C);
        sigmaA <= {A[1:0], A[31:2]} ^ {A[12:0], A[31:13]} ^ {A[21:0], A[31:22]};
        sigmaE <= {E[5:0], E[31:6]} ^ {E[10:0], E[31:11]} ^ {E[24:0], E[31:25]};
        if (counter < 16) begin
            W[counter] = padded_msg[(counter * 32)+:32];
        end else begin
            W[counter[3:0]] <= ({W[temp1[3:0]][16:0], W[temp1[3:0]][31:17]} ^ {W[temp1[3:0]][18:0], W[temp1[3:0]][31:19]} ^ {10'd0, W[temp1[3:0]][31:10]}) +
                               W[temp2[3:0]] +
                               ({W[temp3[3:0]][6:0], W[temp3[3:0]][31:7]} ^ {W[temp3[3:0]][17:0], W[temp3[3:0]][31:18]} ^ {3'd0, W[temp3[3:0]][31:3]}) +
                               W[temp4[3:0]];
        end
//        t1 <= sigmaE + ch + Ks[counter * 32+:32] + W[counter[3:0]] + si
    end else if (P == S_COMPRESS) begin
        A <= H + sigmaE + ch + Ks[counter * 32+:32] + W[counter[3:0]] + sigmaA + ma;
        B <= A;
        C <= B;
        D <= C;
        E <= D + H + sigmaE + ch + Ks[counter * 32+:32] + W[counter[3:0]];
        F <= E;
        G <= F;
        H <= G;
        counter <= counter + 1;
    end else if (P == S_FINAL) begin
        hash_msg <= {a_temp + A, b_temp + B, c_temp + C, d_temp + D, e_temp + E, f_temp + F, g_temp + G, h_temp + H};
        done <= 1;
    end
end
// calculate

endmodule 
