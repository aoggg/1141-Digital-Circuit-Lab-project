`timescale 1ns / 1ps

module alu(
    // DO NOT modify the interface!
    // input signal
    input [7:0] accum,
    input [7:0] data,
    input [2:0] opcode,
    input reset,
    
    // result
    output [7:0] alu_out,
    
    // PSW
    output zero,
    output overflow,
    output parity,
    output sign
    );
    
    reg [7:0] out;
    reg signed [3:0] mula;
    reg signed [3:0] muld;
    reg signed [7:0] signed_accum;
    reg signed [7:0] signed_data;
    reg [7:0] neg_data;
    assign alu_out = out;
    localparam [7:0] MAX = 8'b01111111;
    localparam [7:0] MIN = 8'b10000000;
    
    reg psw_overflow;
    assign zero = (out == 0);
    assign overflow = psw_overflow; // addition and subtraction
    assign parity = ^out;  // even parity
    assign sign = out[7];
    
    always @(*) begin
        psw_overflow = 0;
        if (reset) begin
            out = 0;            
        end
        else begin
            case (opcode)
                3'b000: out = accum;
                3'b001: begin // accum + data
                    out = accum + data;
                    if (~(accum[7] ^ data[7])) begin
                        if (out[7] ^ accum[7]) begin
                            psw_overflow = 1;
                            if (accum[7] == 0) out = MAX;
                            else out = MIN;
                        end                    
                    end
                end
                3'b010: begin // accum - data
                    neg_data = ~data + 1;
                    out = accum + neg_data;
                    if (~(accum[7] ^ neg_data[7])) begin
                        if (out[7] ^ accum[7]) begin
                            psw_overflow = 1;
                            if (accum[7] == 0) out = MAX;
                            else out = MIN;
                        end 
                    end
                end
                3'b011: begin // accum arithmetic right shift data bit
                    signed_accum = accum;
                    out = signed_accum >>> data;
                end
                3'b100: begin // accum XOR data
                    out = accum ^ data;
                end
                3'b101: begin // ABS(accum)
                    if (accum[7] == 1'b1) begin
                        out = ~(accum) + 1;
                    end
                    else out = accum;
                end
                3'b110: begin // accum * data
                    mula = accum[3:0];
                    muld = data[3:0];
                    out = mula * muld;
                end
                3'b111: begin // -(accum)
                    out = ~(accum) + 1;
                end
                default: out = 0;
            endcase
        end
    end

endmodule
