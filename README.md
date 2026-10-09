# SystemVerilog FIFO Design and Verification

I built this project to get more practice with RTL design and verification using SystemVerilog. The project is a parameterized synchronous FIFO, along with a testbench that checks its behavior under normal use and at important boundary conditions.

I wanted to do more than implement the FIFO itself, so I also added a reference model, immediate assertions, and a separate concurrent SVA checker. I used Icarus Verilog and Verilator to run the testbench, with the concurrent SVA checks enabled in the Verilator flow.

## What it includes

- Parameterized FIFO data width and depth
- Read/write pointers and an occupancy counter
- Explicit pointer wraparound, including for non-power-of-two depths
- A self-checking testbench with directed and randomized transactions
- A reference model to check read data
- Immediate assertions and concurrent SystemVerilog Assertions (SVA)
- Simulation flows for Icarus Verilog and Verilator

## Running the testbench

Run these commands from the project root.

### Icarus Verilog

The Icarus flow uses the immediate assertion checker. The testbench should conditionally instantiate the concurrent SVA checker only when `USE_SVA` is defined, so Icarus does not need to compile `fifo_sva.sv`.

```bash
iverilog -g2012 -s fifo_tb -o sim_fifo \
    rtl/fifo.sv \
    tb/fifo_assertions.sv \
    tb/fifo_tb.sv

vvp sim_fifo
```

### Verilator

The Verilator flow enables assertions and defines `USE_SVA` so the concurrent checker is instantiated.

```bash
verilator --binary --timing --assert -Wno-fatal \
    --top-module fifo_tb -DUSE_SVA \
    rtl/fifo.sv \
    tb/fifo_assertions.sv \
    tb/fifo_sva.sv \
    tb/fifo_tb.sv

./obj_dir/Vfifo_tb
```

A successful run should finish with `Errors: 0` and `ALL CHECKS PASSED`. The exact pass-check count may differ between simulators because the testbench includes randomized transactions and its pass counter does not represent every individual check.

## Documentation

- [`docs/architecture.md`](docs/architecture.md) explains the FIFO structure and operation.
- [`docs/verification_plan.md`](docs/verification_plan.md) describes the tests and assertion checks.

The project gave me a chance to practice thinking about both sides of RTL work: how the design should behave, and how to check that behavior. The simulation results are useful evidence for the cases covered by the testbench, but they are not a formal proof that the design is correct for every possible input sequence.
