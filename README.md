# hdc-xor-permute-systemverilog

SystemVerilog implementation of a 1024-bit XOR-plus-permute pipeline for Hyperdimensional Computing (HDC).

## Overview

This repository contains a modular RTL implementation of a bit-parallel HDC processing pipeline built in SystemVerilog. The design takes a 1024-bit input hypervector, binds it with a 1024-bit bind vector using XOR, and then applies a selectable permutation stage before presenting the registered output.

The project is intended both as a working RTL prototype and as a learning-oriented hardware exploration of how HDC operations can be mapped into digital design.

## Project Motivation

Hyperdimensional Computing represents information using high-dimensional binary vectors called hypervectors. These hypervectors are attractive in emerging computing systems because they support simple but powerful operations for encoding, combining, and transforming information.

Two of the most important HDC operations are:

- `Binding`: combines two hypervectors, typically using bitwise XOR
- `Permutation`: reorders bits or words to capture position, sequence, or structure

This project focuses on implementing those operations in synthesizable RTL using a clean pipeline structure that is easy to read, verify, and extend.

## Key Features

- 1024-bit hypervector datapath
- XOR-based binding stage
- Configurable permutation stage
- Flattened vector interfaces for simpler module integration
- Registered pipeline behavior
- Self-checking SystemVerilog testbench
- Parameterized word count and word width

## Design Configuration

The default configuration is:

- `WORDS = 16`
- `BITS_PER_WORD = 64`
- `D = 1024` total bits

This means the design processes a 1024-bit hypervector as 16 words of 64 bits each.

## Top-Level Dataflow

The processing path is:

`input hypervector -> XOR binding -> permutation -> registered output`

### Pipeline Stages

1. Input capture
2. XOR binding
3. Permutation
4. Output register and handshake

The current top-level implementation keeps the control path intentionally simple and allows only one transaction in flight at a time. This makes the design easier to understand and verify while still demonstrating the core HDC data movement.

## Module Descriptions

### `xor_permute_top.sv`

This is the top-level module that connects the full pipeline.

Responsibilities:

- Receives the input hypervector
- Receives the bind vector
- Captures permutation mode and parameter
- Performs XOR binding
- Sends the result into the permutation stage
- Registers the final output
- Exposes `in_valid/in_ready` and `out_valid/out_ready` handshake signals

Main interface signals:

- `in_valid`, `in_ready`: input-side handshake
- `in_vec_flat[D-1:0]`: input hypervector
- `bind_vec_flat[D-1:0]`: bind hypervector
- `perm_mode[1:0]`: permutation mode selection
- `perm_param[$clog2(D)-1:0]`: permutation control value
- `out_valid`, `out_ready`: output-side handshake
- `out_vec_flat[D-1:0]`: processed output hypervector

### `permute_stage.sv`

This module performs the permutation operation on the bound vector and registers the result.

Supported modes:

- `2'b00`: fixed word-order reversal
- `2'b01`: rotate each 64-bit word right by `param`
- `2'b10`: rotate the entire 1024-bit vector right by `param`
- `2'b11`: default passthrough behavior

Implementation notes:

- The input vector is unpacked into word slices
- A combinational block computes the permuted result
- The permuted vector is repacked into a flat output bus
- The output is registered on the next clock edge

### `simple_bind_rom.sv`

This is a simple placeholder bind-vector generator.

Current behavior:

- Outputs a constant 1024-bit pattern built from repeated `64'hA5A5_A5A5_A5A5_A5A5`

This module can be extended later into:

- A true ROM indexed by address
- A BRAM-backed memory structure
- A `$readmemh` initialized memory
- A runtime-configurable bind-vector source

### `tb_xor_permute.sv`

This is a self-checking testbench for the full pipeline.

It includes:

- A golden model for expected behavior
- Full-vector rotation checks
- Fixed word-reversal checks
- Per-word rotation checks
- Edge-case rotation values such as `0`, `64`, and `1023`
- Output backpressure and stall validation

The testbench stops on a mismatch and prints pass/fail messages for each scenario.

## Repository Structure

```text
hdc-xor-permute-systemverilog/
|- permute_stage.sv
|- simple_bind_rom.sv
|- tb_xor_permute.sv
|- xor_permute_top.sv
`- README.md
```

## Verification Strategy

The verification flow is based on comparing the DUT output against a golden reference model implemented in the testbench.

The current testbench verifies:

- Correct XOR binding plus permutation composition
- Correct handling of each supported permutation mode
- Correct behavior for boundary rotation values
- Stable output behavior when `out_ready` is deasserted

This gives a strong functional starting point for future expansion into randomized or constrained-random testing.

## Running Simulation

Use any simulator with SystemVerilog support.

Typical simulation flow:

1. Compile `xor_permute_top.sv`, `permute_stage.sv`, `simple_bind_rom.sv`, and `tb_xor_permute.sv`
2. Launch the testbench `tb_xor_permute`
3. Run the simulation until completion
4. Inspect the simulator transcript for pass/fail output

Example ModelSim or Questa-style commands:

```text
vlog xor_permute_top.sv permute_stage.sv simple_bind_rom.sv tb_xor_permute.sv
vsim tb_xor_permute
run -all
```

If you use another simulator such as Xcelium, VCS, or Verilator-compatible flows, adjust the commands accordingly.

## How To Extend This Project

This design is a good base for further HDC hardware exploration. Possible extensions include:

- Adding more permutation patterns
- Replacing the fixed bind-vector source with a memory-mapped ROM or RAM
- Supporting multiple transactions in flight
- Adding randomized test cases
- Generating waveform dumps for easier debugging
- Measuring area, timing, and synthesis tradeoffs
- Integrating the block into a larger HDC accelerator architecture

## Current Limitations

- The top-level pipeline currently allows only one active transaction at a time
- `simple_bind_rom.sv` is a fixed-pattern stub, not a full memory subsystem
- The verification environment is directed rather than coverage-driven
- There is no synthesis script or implementation flow included yet

## Educational Value

This project demonstrates how AI-inspired computing concepts can be translated into hardware building blocks. It is especially useful for understanding:

- Wide datapath RTL design
- Modular SystemVerilog coding style
- Simple pipelined processing structures
- Functional verification with a self-checking testbench
- Hardware-oriented implementation of HDC primitives

## Author

**Harshavardhan Reddy Narra**  
Master's in Electrical and Computer Engineering  
University of Southern California (USC)  
Email: `hnarra@usc.edu`

## License

This project is released under the MIT License.

You are free to use, modify, distribute, and adapt this work with attribution under the terms of the [LICENSE](LICENSE) file.
