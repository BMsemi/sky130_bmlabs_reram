# Power-pin integration

## Required connections

With `USE_POWER_PINS` enabled, both released Wishbone macros expose the
following pins. The lowercase names are the required top-level supply nets:

| Macro pin | Top-level net | Role |
|---|---|---|
| `VDDC1` | `vccd1` | 1.8 V digital-core supply domain 1 |
| `VDDC2` | `vccd2` | 1.8 V digital-core supply domain 2 |
| `VDDA1` | `vdda1` | 3.3 V analog supply domain 1 |
| `VDDA2` | `vdda2` | 3.3 V analog supply domain 2 |
| `VSS` | `vssd1` | Shared digital and analog ground |

These mappings are required. Preserve the macro pin names and connectivity
through RTL, gate-level, LEF/GDS integration and LVS.

The macro also has analog bias and programming rails at other voltages. Those
signals are not interchangeable with the five power pins above; use the pin
descriptions in the released Verilog/LEF views and the macro-owner
specifications.

## Separate supply connections

`VDDC1` and `VDDC2` connect to the separate 1.8 V Caravel nets `vccd1` and
`vccd2`, respectively. `VDDA1` and `VDDA2` connect to the separate 3.3 V
Caravel nets `vdda1` and `vdda2`, respectively.

Equal nominal voltage does not make two Caravel nets identical. Do not short
either numbered pair, and do not delete, rename or geometrically merge the
individual pins inside the Verilog, LEF, Liberty or GDS views.

Use the same mapping in RTL, the PDN macro hooks and the LVS setup:

```verilog
.VDDC1 (vccd1),
.VDDC2 (vccd2),
.VDDA1 (vdda1),
.VDDA2 (vdda2),
.VSS   (vssd1),
```

## Common ground

Digital and analog circuitry share the macro's single `VSS` ground pin. The
released macro does not expose separate digital and analog ground pins.
Connect `VSS` to the common, low-impedance ground network and control return
noise through floorplanning, routing and decoupling.

Do not invent or split ground pins in any IP view, because that would make the
Verilog, LEF, Liberty, GDS and LVS connectivity inconsistent.

## Integration signoff

Before tapeout, verify the sequencing, ramp, current, ripple, decoupling and
noise limits for the 1.8 V `vccd1/vccd2` domains, the 3.3 V `vdda1/vdda2`
domains and every additional supply or bias rail against the current
macro-owner specification.
