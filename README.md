![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg)

# 4-bit 2x2 Systolic Array Matrix Multiplier

A signed 4-bit 2x2 output-stationary systolic array for matrix multiplication, implemented in Verilog and targeted to the Tiny Tapeout IHP SG13G2 shuttle.

## Design Overview

The design contains four processing elements (PEs) arranged as a 2x2 systolic array:

```text
PE00  PE01
PE10  PE11
```

Each PE receives a signed 4-bit A operand from the left and a signed 4-bit B operand from the top. A values move horizontally, B values move vertically, and each PE performs a signed multiplication and accumulates the product locally.

For input matrices A and B, the accelerator computes:

```text
C00 = A00*B00 + A01*B10
C01 = A00*B01 + A01*B11
C10 = A10*B00 + A11*B10
C11 = A10*B01 + A11*B11
```

The input operands use 4-bit two's-complement signed values from -8 to +7. Each PE uses a 9-bit signed accumulator so that the complete result can be represented.

## Interface

The project uses the standard Tiny Tapeout digital interface.

| Pins | Function |
|---|---|
| `ui_in[7:0]` | Matrix input data |
| `uo_out[7:0]` | Lower 8 bits of the selected result |
| `uio_in[0]` | START |
| `uio_out[0]` | Result sign bit (bit 8) during output |
| `uio_oe[0]` | Enables `uio_out[0]` during result output |
| `clk` | System clock |
| `rst_n` | Active-low reset |
| `ena` | Tiny Tapeout enable |

Each input byte contains two signed 4-bit values. Four input bytes load the 2x2 matrices:

1. A row 0: `A00` and `A01`
2. A row 1: `A10` and `A11`
3. B row 0: `B00` and `B01`
4. B row 1: `B10` and `B11`

The four 9-bit output results are sent in row-major order:

```text
C00, C01, C10, C11
```

For each result, `uo_out[7:0]` carries bits [7:0] and `uio_out[0]` carries bit [8].

## How to Use

1. Hold `rst_n` low to reset the design.
2. Set `uio_in[0]` high to start a transaction.
3. Present the four matrix bytes on `ui_in[7:0]`, one byte per clock cycle.
4. After the four load cycles, the controller performs the required systolic compute cycles automatically.
5. Read the four results during the SEND state in the order `C00`, `C01`, `C10`, `C11`.
6. Return to IDLE before starting the next matrix multiplication.

The design operates at a 10 MHz clock rate in the Tiny Tapeout configuration.

## Verification

The RTL is verified with Cocotb and Icarus Verilog. The regression includes:

- signed corner cases
- exhaustive single-term tests covering all PE positions
- randomized 2x2 signed matrix multiplication tests

The same Tiny Tapeout interface is used for RTL and gate-level verification.

## Project Files

- `src/project.v` - synthesizable Verilog design
- `test/tb.v` - simulation testbench wrapper
- `test/test.py` - Cocotb functional regression
- `test/Makefile` - RTL and IHP gate-level simulation setup
- `info.yaml` - Tiny Tapeout project metadata and pinout
- `docs/info.md` - detailed project documentation

## Tiny Tapeout

This project targets the IHP SG13G2 process and is configured as a single `1x1` tile.

Project documentation: [docs/info.md](docs/info.md)

Repository: https://github.com/jekjekmlofficial-svg/crisanto-4bit-systolic-array
