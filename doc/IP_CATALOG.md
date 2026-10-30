# IP catalog

| Product | Open-PDK cell name | Capability | Interface | Release state |
|---|---|---|---|---|
| X2 | `sky130_bmlabs_reram__cim32x32` | program/read plus compute-in-memory dot product | raw signals plus reference analog/test pins | Provisional floorplanning views; not signoff-qualified |
| X2 | `sky130_bmlabs_reram__cim32x32wb` | program/read plus compute-in-memory dot product | Wishbone | Physical release available |
| X1 | `sky130_bmlabs_reram__nvm32x32wb` | non-volatile program/read | Wishbone | Physical release available |

The names describe capability and interface, not the consuming project. A row
marked provisional may be used to exercise a floorplanning or file-loading
flow, but it is not an available signoff hard macro. It must be replaced by
GDS, LEF and Liberty views generated from and characterized against the actual
raw-interface implementation before LVS, timing signoff, fabrication or
tapeout.
