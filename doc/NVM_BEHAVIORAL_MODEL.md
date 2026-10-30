# X1 NVM Wishbone behavioral model

The `sky130_bmlabs_reram__nvm32x32wb` behavioral view is a simulation model
for the digital SET, RESET and READ behavior of the 32 x 32 X1 array. It does
not implement compute-in-memory operations.

## Wishbone access

The model responds at `0x3000_0004` when `wbs_cyc_i` and `wbs_stb_i` are high
and `wbs_sel_i` is `4'hF`. A Wishbone write enqueues one 32-bit command. A
Wishbone read dequeues one completed READ result. Reading while the result FIFO
is empty returns `32'hDEAD_C0DE`, which makes a premature result read visible
in simulation.

## Command format

| Bits | Meaning |
|---|---|
| `[31:30]` | `2'b11` PROGRAM or `2'b01` READ |
| `[29:25]` | Array row, 0 through 31 |
| `[24:20]` | Array column, 0 through 31 |
| `[19:8]` | Reserved by this model |
| `[7:0]` | PROGRAM value |

PROGRAM uses the data value to select the operation:

- a value greater than `8'h7F` performs SET and stores `1`;
- a value less than or equal to `8'h7F` performs RESET and stores `0`.

Modes `2'b00` and `2'b10` are not X1 NVM operations. The model discards those
commands so that an unsupported command cannot block commands queued behind
it.

## Timing and persistence

The input and result queues are modeled as 32-entry FIFOs. PROGRAM completes
after `WR_Dly` clock cycles (200 by default), and READ places its result in the
output FIFO after `RD_Dly` cycles (44 by default). These delays are functional
simulation delays and are not signoff timing data.

At simulation start, the array is initialized to zero. `wb_rst_i` clears the
Wishbone state and both FIFOs, but it does not clear the stored array contents;
this represents the non-volatile behavior at the digital model level. The
`user_rst` pin is retained for hard-macro interface compatibility and does not
control the Wishbone behavioral engine.

## Model limits

The analog bias inputs, power pins and scan pins are present so the simulation
interface matches the released macro, but their electrical behavior is not
modeled. `ScanOutCC` is held low. The model also does not represent forming,
voltage validity, resistance distributions, read disturb, write endurance,
retention time, process variation or power cycling. Use the supplied physical
and characterization views, rather than this behavioral view, for physical and
timing signoff.

The self-checking testbench verifies SET/readback, retention across a Wishbone
reset, rejection of an unsupported COMPUTE command without FIFO blockage, and
RESET/readback.
