`timescale 1ns / 1ps

module TB_HFT_MACD;

    reg clk, reset, valid;
    reg [31:0] price, vol;
    wire [1:0] signal;
    wire sig_valid;

    HFT_ALPHA_CORE #(
        .STOP_LOSS_PTS(20) 
    ) uut (
        .clk(clk), .reset(reset),
        .valid_tick(valid), .raw_price(price), .volume(vol),
        .order_signal(signal), .order_valid(sig_valid)
    );

    always #1.25 clk = ~clk; 

    real PI = 3.14159;
    real sine_val;
    integer i;

    initial begin
        $dumpfile("macd_hft.vcd");
        $dumpvars(0, TB_HFT_MACD);
        
        clk = 0; reset = 1; valid = 0; price = 1000; vol = 100;
        #20 reset = 0;

        for (i = 0; i < 200; i = i + 1) begin
            @(posedge clk);
            valid = 1;
            sine_val = $sin(i * PI / 20.0); 
            price = 1050 + (50.0 * sine_val); 
            vol = 1000 + $random % 500;
            
            @(posedge clk);
            valid = 0; 
            #5; 
        end

        @(posedge clk);
        valid = 1;
        price = 900; 
        @(posedge clk);
        valid = 0;

        #100 $finish;
    end
    
    initial begin
        $monitor("T:%0t | Price:%d | Hist:%d | Sig:%b | Valid:%b", 
                 $time, price, uut.histogram >>> 16, signal, sig_valid);
    end

endmodule
