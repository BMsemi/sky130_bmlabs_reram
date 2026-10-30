# Analog-pad and routing requirements

## Required external connections

Every macro instance that exposes the following pins must connect each pin to
an analog pad or another approved external analog source. Do not leave these
pins floating, drive them from ordinary digital cells, or short different
analog nets together.

| Pin | Nominal function or value |
|---|---|
| `Iref` | 100 uA current reference |
| `Vcc_read` | 0.3 V read rail |
| `Vcomp` | 0.6 V comparator/reference bias |
| `Bias_comp2` | 0.6 V comparator bias |
| `Vcc_wl_read` | 0.7 V wordline read rail |
| `Vcc_wl_set` | 1.8 V wordline set rail |
| `Vbias` | 1.8 V analog bias |
| `Vcc_wl_reset` | 2.6 V wordline reset rail |
| `Vcc_set` | 3.3 V array set rail |
| `dc_bias` | Externally driven; use the macro-owner-approved value |

Confirm the operating values, tolerances, sequencing and source-current limits
with the macro owner before tapeout. These bias and programming nets are not
substitutes for `VDDC1`, `VDDC2`, `VDDA1`, `VDDA2` or `VSS`.

## Pin and route geometry

The provisional `sky130_bmlabs_reram__cim32x32` LEF/GDS uses 1.30 um-wide,
routing-grid-aligned met3 access shapes for all ten analog pins. The chip-level
route from each pin to its analog pad must use an NDR with a met3 width of at
least 1.30 um; wider routing may be used when current, IR-drop or noise analysis
requires it. Do not allow the detailed router to neck an analog connection down
to the default digital signal width.

When several macro instances share a bias source, size the shared trunk for the
combined load and use branches that are at least as wide as the macro pin.
Keep the analog routes away from noisy switching nets and use project-approved
spacing, shielding and via arrays. The chip project owns the pad assignment,
NDR definition and route constraints because those depend on placement and the
number of macro instances.

The provisional raw-interface views also provide one separate, full-width
1.80 um met3 strap for each of `VDDC1`, `VDDC2`, `VDDA1`, `VDDA2` and `VSS`.
Connect these straps to the matching PDN domain described in `POWER_PINS.md`;
do not merge the numbered supply domains. `VSS` is the common digital and
analog ground.

## Verification

Before signoff, verify that:

1. every analog pin reaches its intended analog pad or approved source;
2. the routed width never falls below the corresponding macro pin width;
3. all routes and via arrays pass DRC and extraction;
4. voltage drop, current capacity, coupling noise and startup sequencing meet
   the macro-owner limits; and
5. the final extracted GDS/LEF replaces the provisional raw-interface views.
