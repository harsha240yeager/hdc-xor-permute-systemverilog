# hdc-xor-permute-systemverilog
SystemVerilog implementation of a 1024-bit XOR-permute pipeline for Hyperdimensional Computing
# HDC XOR-Permute Pipeline in SystemVerilog

A student hardware project exploring **Hyperdimensional Computing (HDC)** using **SystemVerilog**.

This repository implements a **1024-bit XOR-permute pipeline** for hypervector processing, along with a ROM-based bind vector source and a testbench for verification.

---

## Project Summary

Hyperdimensional Computing represents information using very large binary vectors called **hypervectors**. In this project, I explored how key HDC operations can be implemented in digital hardware.

The design focuses on two important operations:

- **Binding** using XOR
- **Permutation** using configurable transformations

This project helped me understand how ideas from AI and emerging computing models can be mapped into hardware-oriented design.

---

## Features

- 1024-bit hypervector processing
- XOR-based binding
- Permutation stage for hypervector transformation
- ROM-based bind vector source
- Modular SystemVerilog design
- Functional verification using a testbench
- Exploration of HDC concepts in hardware

---

## Repository Structure

```text
hdc-xor-permute-systemverilog/
├── rtl/
│   ├── permute_stage.sv
│   ├── simple_bind_rom.sv
│   └── xor_permute_top.sv
├── tb/
│   └── tb_xor_permute.sv
├── docs/
│   └── architecture.png   # optional
├── README.md
├── .gitignore
└── LICENSE