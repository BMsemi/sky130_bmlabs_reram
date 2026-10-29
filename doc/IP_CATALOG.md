# IP catalog

| Product | Open-PDK cell name | Capability | Interface | Release state |
|---|---|---|---|---|
| X2 | `sky130_bmlabs_reram__cim32x32` | program/read plus compute-in-memory dot product | raw signals | Reserved; waiting for a verified cross-view release |
| X2 | `sky130_bmlabs_reram__cim32x32wb` | program/read plus compute-in-memory dot product | Wishbone | Physical release available |
| X1 | `sky130_bmlabs_reram__nvm32x32wb` | non-volatile program/read | Wishbone | Planned; waiting for a verified cross-view release |

The names describe capability and interface, not the consuming project. A row
marked reserved or planned is not an available hard macro and must not be added
to a physical design until its GDS, LEF, Liberty and Verilog views have been
released and validated together.
