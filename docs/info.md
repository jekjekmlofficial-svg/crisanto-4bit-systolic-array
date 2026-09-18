---
title: 4-bit 2x2 Systolic Array Matrix Multiplier
author: Crisanto Cabello Florencondia Jr.
discord: ""
description: A signed 4-bit 2x2 systolic array matrix multiplier using output-stationary dataflow
language: Verilog
clock_hz: 10000000
---

## How it works

This project implements a 2x2 systolic array using four processing elements (PEs) with signed 4-bit operands. The input matrix elements are temporally skewed so that operands propagate horizontally and vertically through the array, allowing the required multiplications to meet at the correct processing elements on successive clock cycles.

Each PE contains a 9-bit signed accumulator that retains its partial result while the operands move through the array. This gives the design an output-stationary accumulation behavior.

For matrices A and B, the array computes:

C00 = A00×B00 + A01×B10

C01 = A00×B01 + A01×B11

C10 = A10×B00 + A11×B10

C11 = A10×B01 + A11×B11

All input operands are signed 4-bit values in the range -8 to +7.

## How to test

The design uses a sequential FSM controller to load the two 2x2 matrices through the 8-bit `ui_in` bus. Each byte contains two signed 4-bit matrix elements. `uio_in[0]` is used as the start trigger.

After the matrices are loaded, the controller runs the systolic array for four compute cycles, including the final propagation cycle. The four 9-bit signed matrix results are then streamed sequentially through `uo_out[7:0]` and `uio_out[0]`.