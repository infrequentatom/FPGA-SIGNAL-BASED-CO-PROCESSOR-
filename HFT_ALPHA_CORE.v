`timescale 1ns / 1ps

module HFT_ALPHA_CORE #(
    parameter DATA_W        = 32,
    parameter Q_SCALE       = 16, 
    parameter ALPHA_12      = 10181, 
    parameter ALPHA_26      = 4854,  
    parameter ALPHA_9       = 13107, 
    parameter STOP_LOSS_PTS = 50     
)(
    input wire clk,
    input wire reset,
    input wire valid_tick,
    input wire [DATA_W-1:0] raw_price, 
    input wire [31:0] volume,
    output reg [1:0] order_signal, 
    output reg order_valid
);

    reg signed [47:0] price_q; 
    reg first_run;

    always @(posedge clk) begin
        if (valid_tick)
            price_q <= $signed(raw_price) <<< Q_SCALE; 
    end

    reg signed [47:0] ema_12, ema_26, ema_9_sig;
    reg signed [47:0] macd_line;
    reg signed [47:0] histogram;

    reg signed [47:0] diff_12, diff_26, diff_9;
    reg signed [47:0] prod_12, prod_26, prod_9;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            ema_12    <= 0;
            ema_26    <= 0;
            ema_9_sig <= 0;
            first_run <= 1;
        end 
        else if (valid_tick) begin
            if (first_run) begin
                ema_12    <= price_q;
                ema_26    <= price_q;
                ema_9_sig <= 0; 
                first_run <= 0;
            end else begin
                diff_12 <= price_q - ema_12;
                diff_26 <= price_q - ema_26;
                
                prod_12 <= (diff_12 * $signed(ALPHA_12)) >>> Q_SCALE;
                prod_26 <= (diff_26 * $signed(ALPHA_26)) >>> Q_SCALE;

                ema_12 <= ema_12 + prod_12;
                ema_26 <= ema_26 + prod_26;
            end
        end
    end

    always @(posedge clk) begin
        if (!reset) begin
            macd_line <= ema_12 - ema_26;

            diff_9    <= macd_line - ema_9_sig;
            prod_9    <= (diff_9 * $signed(ALPHA_9)) >>> Q_SCALE;
            ema_9_sig <= ema_9_sig + prod_9;

            histogram <= macd_line - ema_9_sig;
        end
    end

    reg [1:0] current_position; 
    reg signed [31:0] entry_price;
    
    wire signed [31:0] current_price_int;
    assign current_price_int = raw_price; 

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            order_signal <= 0;
            order_valid <= 0;
            current_position <= 0;
            entry_price <= 0;
        end
        else if (valid_tick) begin
            order_valid <= 1'b1;
            order_signal <= 2'b00; 

            if (current_position == 1) begin 
                if ((entry_price - current_price_int) >= STOP_LOSS_PTS) begin
                    order_signal <= 2'b11; 
                    current_position <= 0;
                end
            end
            else if (current_position == 2) begin 
                if ((current_price_int - entry_price) >= STOP_LOSS_PTS) begin
                    order_signal <= 2'b11; 
                    current_position <= 0;
                end
            end

            if (order_signal == 2'b00) begin
                if (histogram > 0 && current_position == 0) begin
                    order_signal <= 2'b01; 
                    current_position <= 1;
                    entry_price <= current_price_int;
                end
                else if (histogram < 0 && current_position == 0) begin
                    order_signal <= 2'b10; 
                    current_position <= 2;
                    entry_price <= current_price_int;
                end
                else if (current_position == 1 && histogram < 0) begin
                    order_signal <= 2'b10; 
                    current_position <= 0;
                end
                else if (current_position == 2 && histogram > 0) begin
                    order_signal <= 2'b01; 
                    current_position <= 0;
                end
            end
        end
        else begin
            order_valid <= 0;
        end
    end

endmodule
