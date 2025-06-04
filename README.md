# Runtime Attestation

This project implements a hardware-based runtime attestation system using SystemVerilog. The design is intended for FPGA or ASIC platforms and provides mechanisms for trace processing, hashing, memory management, and neighbor tracking.

**This project is developed as part of my Bachelor thesis work.**

## Project Structure

- **top.sv**
  Top-level module that integrates all submodules, including clocking, mapping, and neighbor tracking.

- **tb_top.sv**
  Testbench for simulating and verifying the top-level design.

- **Hash.sv**
  Implements a simplified version of lookup3 hash function for 32-bit trace values, producing a 13-bit hash output.

- **MemoryController.sv**
  Manages trace storage and lookup using a hash table (BRAM), with support for trace deduplication and bucket management.

- **NeighborTracker.sv**
  Tracks and encodes neighbor relationships for traces, using URAM for storage and a buffer for recent accesses.

## Key Features

- **Trace Hashing:**
  Efficiently hashes 32-bit trace values to 13-bit indices for memory operations.

- **Memory Management:**
  Uses BRAM and URAM to store trace data and neighbor information, with FIFO buffers for recent entries.

- **Neighbor Tracking:**
  Maintains and updates neighbor relationships for traces, supporting efficient lookup and update operations.

- **Testbench:**
  Provides simulation infrastructure for verifying the design with trace input files and output logging.

## Usage

1. **Simulation:**
   Use the provided `tb_top.sv` testbench to simulate the design. Update file paths in the testbench as needed for your environment.

2. **Synthesis:**
   Integrate the top-level module (`top.sv`) into your FPGA or ASIC project. Ensure all required IPs (e.g., `clk_wiz_0`, `design_1_wrapper`, `hash_table`) are available.

3. **Trace Input:**
   Prepare trace input files as expected by the testbench (`trace_values.txt`, `trace_values_no_duplicates.txt`).

## File Descriptions

- [`top.sv`](top.sv): Top-level integration of all modules.
- [`tb_top.sv`](tb_top.sv): Testbench for simulation.
- [`Hash.sv`](Hash.sv): Hash function implementation.
- [`MemoryController.sv`](MemoryController.sv): Manages trace storage and lookup.
- [`NeighborTracker.sv`](NeighborTracker.sv): Tracks neighbor relationships.

---

*For more details, see the source code and comments within each module.*