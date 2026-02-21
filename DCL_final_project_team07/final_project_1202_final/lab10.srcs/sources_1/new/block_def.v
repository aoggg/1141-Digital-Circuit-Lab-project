module block_def (
    input [2:0] type_in,    // 1:I, 2:J, 3:L, 4:O, 5:S, 6:T, 7:Z
    input [1:0] rot_in,     // 0:Spawn, 1:R, 2:2, 3:L
    output reg signed [3:0] dx0, output reg signed [3:0] dy0,
    output reg signed [3:0] dx1, output reg signed [3:0] dy1,
    output reg signed [3:0] dx2, output reg signed [3:0] dy2,
    output reg signed [3:0] dx3, output reg signed [3:0] dy3
);
    localparam I_BLK = 3'd1;
    localparam J_BLK = 3'd2;
    localparam L_BLK = 3'd3;
    localparam O_BLK = 3'd4;
    localparam S_BLK = 3'd5;
    localparam T_BLK = 3'd6;
    localparam Z_BLK = 3'd7;

    always @(*) begin
        dx0=0; dy0=0; dx1=0; dy1=0; dx2=0; dy2=0; dx3=0; dy3=0;
        case (type_in)
            I_BLK: begin
                case (rot_in)
                    2'd0: begin
                        dx0=0; dy0=-1; dx1=0; dy1=0; dx2=0; dy2=1; dx3=0; dy3=2;
                    end
                    2'd1: begin
                        dx0=-1; dy0=0; dx1=0; dy0=0; dx2=1; dy2=0; dx3=2; dy3=0;
                    end
                    2'd2: begin
                        dx0=1; dy0=-1; dx1=1; dy1=0; dx2=1; dy2=1; dx3=1; dy3=2;
                    end
                    2'd3: begin
                        dx0=-1; dy0=0; dx1=0; dy1=0; dx2=1; dy2=0; dx3=2; dy3=0;
                    end
                endcase
            end
            J_BLK: begin
                case (rot_in)
                    2'd0: begin
                        dx0=-1; dy0=-1; dx1=0; dy1=-1; dx2=0; dy2=0; dx3=0; dy3=1;
                    end
                    2'd1: begin
                        dx0=-1; dy0=1;  dx1=-1; dy1=0; dx2=0; dy2=0; dx3=1; dy3=0;
                    end
                    2'd2: begin
                        dx0=1; dy0=1;   dx1=0; dy1=1;  dx2=0; dy2=0; dx3=0; dy3=-1;
                    end
                    2'd3: begin
                        dx0=1; dy0=-1;  dx1=1; dy1=0;  dx2=0; dy2=0; dx3=-1; dy3=0;
                    end
                endcase
            end
            L_BLK: begin
                case (rot_in)
                    2'd0: begin
                        dx0=-1; dy0=1; dx1=0; dy1=1; dx2=0; dy2=0; dx3=0; dy3=-1;
                    end
                    2'd1: begin
                        dx0=1; dy0=1;  dx1=1; dy1=0; dx2=0; dy2=0; dx3=-1; dy3=0;
                    end
                    2'd2: begin
                        dx0=1; dy0=-1; dx1=0; dy1=-1; dx2=0; dy2=0; dx3=0; dy3=1;
                    end
                    2'd3: begin
                        dx0=-1; dy0=-1; dx1=-1; dy1=0; dx2=0; dy2=0; dx3=1; dy3=0;
                    end
                endcase
            end
            O_BLK: begin
                dx0=-1; dy0=0; dx1=-1; dy1=1; dx2=0; dy2=0; dx3=0; dy3=1;
            end
            S_BLK: begin
                case (rot_in)
                    2'd0: begin
                        dx0=0; dy0=-1; dx1=0; dy1=0; dx2=-1; dy2=0; dx3=-1; dy3=1;
                    end
                    2'd1: begin
                        dx0=-1; dy0=0; dx1=0; dy1=0; dx2=0; dy2=1; dx3=1; dy3=1;
                    end
                    2'd2: begin
                        dx0=1; dy0=-1; dx1=1; dy1=0; dx2=0; dy2=0; dx3=0; dy3=1;
                    end
                    2'd3: begin
                        dx0=-1; dy0=-1; dx1=0; dy1=-1; dx2=0; dy2=0; dx3=1; dy3=0;
                    end
                endcase
            end
            T_BLK: begin
                case (rot_in)
                    2'd0: begin
                        dx0=-1; dy0=0; dx1=0; dy1=-1; dx2=0; dy2=0; dx3=0; dy3=1;
                    end
                    2'd1: begin
                        dx0=0; dy0=1; dx1=-1; dy1=0; dx2=0; dy2=0; dx3=1; dy3=0;
                    end
                    2'd2: begin
                        dx0=1; dy0=0; dx1=0; dy1=1; dx2=0; dy2=0; dx3=0; dy3=-1;
                    end
                    2'd3: begin
                        dx0=0; dy0=-1; dx1=1; dy1=0; dx2=0; dy2=0; dx3=-1; dy3=0;
                    end
                endcase
            end
            Z_BLK: begin
                case (rot_in)
                    2'd0: begin
                        dx0=-1; dy0=-1; dx1=-1; dy1=0; dx2=0; dy2=0; dx3=0; dy3=1;
                    end
                    2'd1: begin
                        dx0=1; dy0=0; dx1=0; dy1=0; dx2=0; dy2=1; dx3=-1; dy3=1; 
                    end
                    2'd2: begin
                        dx0=0; dy0=-1; dx1=0; dy1=0; dx2=1; dy2=0; dx3=1; dy3=1;
                    end
                    2'd3: begin
                        dx0=1; dy0=-1; dx1=0; dy1=-1; dx2=0; dy2=0; dx3=-1; dy3=0;
                    end
                endcase
            end
            default: begin 
                dx0=0; dy0=0; dx1=0; dy1=0; dx2=0; dy2=0; dx3=0; dy3=0;
            end
        endcase
    end
endmodule