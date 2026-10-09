# Verification Plan

## Testbench approach

The testbench drives requests to the FIFO, tracks the expected contents in a reference model, and compares accepted read data against the expected value. It also checks status and occupancy-related behavior after transactions.

The testbench includes both directed scenarios, where the expected situation is deliberately set up, and randomized transactions, which exercise additional combinations of read and write requests.

## Directed test scenarios

| Scenario | What it checks |
|---|---|
| Reset | Pointers, count, and registered output clear as expected |
| Read while empty | A read is rejected when no data is available |
| Single-item transaction | A written word can be read back |
| Data ordering | Words are returned in FIFO order |
| Fill to capacity | The `full` flag asserts at the expected occupancy |
| Write while full | A write request does not increase occupancy beyond capacity |
| Drain to empty | The FIFO returns to the empty state after accepted reads |
| Read while empty | An extra read request does not consume nonexistent data |
| Simultaneous request while empty | The write is accepted and the read is rejected |
| Simultaneous request while partially occupied | Both operations are accepted and occupancy stays the same |
| Simultaneous request while full | The read is accepted and the write is rejected |

## Randomized testing

After the directed tests, the testbench generates randomized read and write requests and then drains the FIFO. This provides more combinations than the directed cases alone.

The random sequence can differ between simulator runs or tools. Because of that, the total pass-check count may differ too. The pass counter is a summary rather than a count of every individual assertion or comparison, so it should not be treated as a coverage metric.

## Reference-model checks

The reference model tracks the expected FIFO contents and is used to check read data. The testbench also checks the expected status and occupancy behavior after transactions. A mismatch increments the testbench error count and is intended to make the run fail visibly.

## Immediate assertions

`tb/fifo_assertions.sv` contains immediate assertion checks for invariants including:

- `empty` agrees with zero occupancy
- `full` agrees with occupancy equal to `DEPTH`
- Occupancy remains within its legal range
- Read and write pointers remain within the valid depth
- Reset clears the relevant state

These checks are included in the Icarus Verilog simulation flow.

## Concurrent SystemVerilog Assertions

`tb/fifo_sva.sv` contains concurrent properties that check status/occupancy consistency and that occupancy and pointers remain in range. The testbench conditionally instantiates this checker when `USE_SVA` is defined.

The Verilator command defines `USE_SVA` and enables assertion support, so the concurrent properties run in that flow. The Icarus flow leaves `USE_SVA` undefined and does not compile `fifo_sva.sv`, since concurrent SVA support varies by simulator.

## Commands

Run from the project root.

### Icarus Verilog

```bash
iverilog -g2012 -s fifo_tb -o sim_fifo \
    rtl/fifo.sv \
    tb/fifo_assertions.sv \
    tb/fifo_tb.sv

vvp sim_fifo
```

### Verilator

```bash
verilator --binary --timing --assert -Wno-fatal \
    --top-module fifo_tb -DUSE_SVA \
    rtl/fifo.sv \
    tb/fifo_assertions.sv \
    tb/fifo_sva.sv \
    tb/fifo_tb.sv

./obj_dir/Vfifo_tb
```

## Pass criteria and limitations

A successful run should report zero testbench errors and finish with `ALL CHECKS PASSED`. The assertion-enabled Verilator run should also complete without SVA failures.

Simulation is only as strong as the scenarios and properties being checked. These tests provide evidence that the design behaves correctly in the exercised cases, but they do not prove correctness for every possible input sequence. Further work could include parameter sweeps, reproducible random seeds, more functional coverage, additional temporal properties, and formal verification.
