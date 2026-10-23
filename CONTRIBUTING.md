# Contributing

1. Create a short-lived branch.
2. Keep a cell's GDS, LEF, Liberty and Verilog names and pins synchronized.
3. Do not change an existing physical boundary without a new reviewed release.
4. Run `python3 scripts/check_views.py`.
5. Update `ip_manifest.json` and `CHANGELOG.md`.
6. Submit a pull request with interface, physical-view and simulation evidence.

Never commit generated tool caches, virtual environments or chip-level run
directories to this IP library.
