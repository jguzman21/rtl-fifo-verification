# FIFO Architecture

## Overview

The design is a parameterized synchronous FIFO written in SystemVerilog. It stores `DATA_WIDTH`-bit words in a memory with `DEPTH` entries. The default parameters are an 8-bit data width and a depth of 4, but both can be changed when the module is instantiated.

The main pieces of the design are:

- A memory array that stores the data words
- A write pointer that identifies where the next accepted write goes
- A read pointer that identifies the next word to be read
- An occupancy counter that tracks how many entries are in the FIFO
- `full` and `empty` outputs derived from the occupancy counter
- A registered `rd_data` output

## Interface

| Signal | Direction | Description |
|---|---|---|
| `clk` | Input | Clock for synchronous state updates |
| `rst` | Input | Synchronous, active-high reset |
| `wr_en` | Input | Requests a write |
| `wr_data` | Input | Data to write |
| `rd_en` | Input | Requests a read |
| `rd_data` | Output | Registered data from an accepted read |
| `full` | Output | High when occupancy equals `DEPTH` |
| `empty` | Output | High when occupancy is zero |

## State and status flags

The write pointer advances when a write is accepted, and the read pointer advances when a read is accepted. The occupancy counter increases for a write without a read, decreases for a read without a write, and stays the same when both operations are accepted or neither is accepted.

The status flags are based on the counter:

- `empty` is high when `count == 0`.
- `full` is high when `count == DEPTH`.

The pointer width is based on `$clog2(DEPTH)`, with a minimum width of one bit. The counter is wide enough to represent values from zero through `DEPTH`.

## Accepting reads and writes

The design uses two internal signals to determine which operations actually take place:

- `do_write = wr_en && !full`
- `do_read = rd_en && !empty`

This means a write request is ignored when the FIFO is full, and a read request is ignored when it is empty. These rules also determine what happens when read and write are requested in the same cycle.

| FIFO state | `wr_en` | `rd_en` | Result |
|---|---:|---:|---|
| Empty | 1 | 1 | Write accepted; read rejected |
| Partially occupied | 1 | 1 | Both accepted; occupancy unchanged |
| Full | 1 | 1 | Read accepted; write rejected |
| Any state | 1 while full | X | Write rejected |
| Any state | X | 1 while empty | Read rejected |

`X` in the table means the value of that request does not change the stated boundary behavior.

## Pointer wraparound

When a pointer reaches `DEPTH - 1`, the design sets it back to zero. Otherwise, it increments by one. This explicit wraparound is important when `DEPTH` is not a power of two, since natural binary overflow could otherwise point outside the valid memory entries.

The module also checks at initialization that `DEPTH` and `DATA_WIDTH` are at least one.

## Reset behavior

Reset is synchronous and active-high. When `rst` is high at a rising clock edge, the design clears both pointers, the occupancy counter, and the registered read output. The memory contents themselves are not reset; the occupancy count indicates that the FIFO is empty after reset.

## Read behavior

When a read is accepted at a rising clock edge, the value at the current read pointer is copied into `rd_data`, and the read pointer advances. If a read is not accepted, `rd_data` retains its previous value, except during reset when it is cleared.

## Design trade-offs and scope

This implementation is intended as a straightforward learning project for FIFO control and verification. It uses an occupancy counter to derive `full` and `empty`, rather than relying only on pointer comparisons. The documentation and tests focus on functional simulation; no claim is made here about synthesis results, timing closure, or formal proof.
