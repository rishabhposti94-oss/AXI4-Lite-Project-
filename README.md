# AXI4-Lite-Project-
# AXI4-Lite Slave Design and Verification

## Overview
This project focuses on the design and functional verification of an AXI4-Lite slave interface using Verilog and SystemVerilog. The slave uses an FSM-based architecture to control read and write transactions and interfaces with a 128 × 32-bit memory.

## Design Features
- FSM-based control for read and write transactions.
- 128 × 32-bit memory organization.
- VALID/READY handshaking for AXI4-Lite transactions.
- Read and write response handling.
- Support for the five AXI4-Lite channels: AW, W, B, AR and R.

## Verification Environment
Developed a class-based SystemVerilog testbench with the following components:

- **Transaction:** Defines randomized read/write operations, addresses and write data.
- **Generator:** Generates constrained-random transactions.
- **Driver:** Applies transactions to the DUT through a virtual interface.
- **Monitor:** Observes read/write responses and forwards transaction information.
- **Scoreboard:** Maintains a reference memory model and compares read data against expected values to detect mismatches.

## Project Structure
- `design.sv` — AXI4-Lite slave RTL implementation.
- `testbench.sv` — SystemVerilog interface, transaction class and verification components.

## Tools and Technologies
- Verilog
- SystemVerilog
- EDA Playground
- RTL simulation and functional verification

## How to Run
1. Open the project on EDA Playground.
2. Select a compatible SystemVerilog simulator.
3. Compile the RTL design and testbench.
4. Run the simulation and inspect the transaction logs and waveform output.

## Online Simulation
[Open the project on EDA Playground](https://edaplayground.com/x/ZLCE)

## Author
Rishabh Posti  
M.Tech VLSI, IIT Kharagpur
