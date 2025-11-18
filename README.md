# FPGA-SIGNAL-BASED-CO-PROCESSOR-
# FPGA Algo Trading Core (MACD + Risk Manager)

This project is a hardware implementation of a standard algorithmic trading strategy (MACD) designed for FPGAs (specifically Xilinx UltraScale+). 

The goal was to move the strategy logic off the CPU and directly onto the network card (or FPGA accelerator) to eliminate the latency spikes you get from operating system jitter and PCIe transfer times. By doing this in Verilog, we get deterministic, nanosecond-level decision making.

## What does it do?

It takes in raw market data (ticks), processes them through a momentum strategy, and spits out a `Buy`, `Sell`, or `Liquidation` signal. 

Crucially, it runs fully pipelined. It doesn't wait for a loop to finish; it processes a new price update on every single clock cycle.

## Technical Implementation

I focused on keeping this efficient enough to fit hundreds of these cores on a single Alveo card.

### 1. Fixed-Point Math (Q16.16)
Floating point is too slow and resource-heavy for this. I mapped everything to **Q16.16 Fixed Point**. 
* **Why?** It lets us treat prices as integers while keeping enough decimal precision for the calculations. 
* **Result:** We avoid the massive latency penalty of using an FPU.

### 2. Hardware DSP Inference
The code is written specifically to map the EMA (Exponential Moving Average) calculations to **DSP48E2 slices** on Xilinx chips. 
* Instead of using generic logic gates for multiplication, it uses the hard-wired DSP blocks.
* This allows the core to run at high frequencies (>400 MHz) without timing violations.

### 3. The "Kill Switch" (RMS)
Safety first. I implemented a hard-coded Risk Management System (RMS) that sits *in front* of the strategy logic.
* It tracks the entry price of the current position.
* If the price moves against us by more than `STOP_LOSS_PTS`, it forces a close signal immediately.
* This logic overrides the MACD strategy—if the trade goes bad, the FPGA cuts it instantly in 1 clock cycle.

## Architecture

The data path is a 4-stage pipeline:

1.  **Ingest:** Convert raw integer price to 48-bit Fixed Point.
2.  **Filter:** Compute Fast (12) and Slow (26) EMAs in parallel.
3.  **Compute:** Calculate MACD line and Signal line.
4.  **Decide:** Check RMS constraints -> Check Crossover -> Issue Signal.

```mermaid
graph TD;
    Input[Market Data] --> Convert(Int to Fixed Point);
    Convert --> Filter{Parallel DSP Filters};
    Filter -->|Fast EMA| Diff(Subtractor);
    Filter -->|Slow EMA| Diff;
    Diff --> SignalEMA[Signal Line Filter];
    SignalEMA --> Logic{RMS & Strategy Logic};
    Logic --> Output[Order Signal];
