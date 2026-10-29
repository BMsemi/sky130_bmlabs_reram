# Power-pin integration

## Required connections

With `USE_POWER_PINS` enabled, `sky130_bmlabs_reram__cim32x32wb` exposes the
following macro pins. The lowercase names are the required top-level supply
nets:

| Macro pin | Top-level net | Role |
|---|---|---|
| `VDDC1` | `vccd1` | Digital-core supply domain 1 |
| `VDDC2` | `vccd2` | Digital-core supply domain 2 |
| `VDDA1` | `vdda1` | Analog supply domain 1 |
| `VDDA2` | `vdda2` | Analog supply domain 2 |
| `VSS` | common `VSS` | Shared digital and analog ground |

These mappings are required. Preserve the macro pin names and connectivity
through RTL, gate-level, LEF/GDS integration and LVS.

The macro also has analog bias and programming rails at other voltages. Those
signals are not interchangeable with the five power pins above; use the pin
descriptions in the released Verilog/LEF views and the macro-owner
specifications.

## Separate supply domains

`VDDC1` and `VDDC2` must remain separate and connect to `vccd1` and `vccd2`,
respectively. `VDDA1` and `VDDA2` must also remain separate and connect to
`vdda1` and `vdda2`, respectively.

Do not short either numbered pair together, and do not short a `VDDA*` rail to
a `VDDC*` rail merely because they may have the same nominal voltage. Separate
domains allow independent power distribution, filtering, decoupling and noise
control. Each rail must be included in circuit, IR-drop, EM, noise and LVS
signoff.

## Common ground

Digital and analog circuitry share the macro's single `VSS` ground pin. The
released macro does not expose separate digital and analog ground pins.
Connect `VSS` to the common, low-impedance ground network and control return
noise through floorplanning, routing and decoupling.

Do not invent or split ground pins in any IP view, because that would make the
Verilog, LEF, Liberty, GDS and LVS connectivity inconsistent.

## Integration signoff

Before tapeout, verify the voltage, sequencing, ramp, current, ripple,
decoupling and noise limits for `vccd1`, `vccd2`, `vdda1`, `vdda2` and every
additional supply or bias rail against the current macro-owner specification.
