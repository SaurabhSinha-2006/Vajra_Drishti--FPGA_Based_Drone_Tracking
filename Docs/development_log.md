# Development Log

This is a high-level summary of the current project state, not a substitute for dated commits or full tool logs. Add dated entries as work is completed.

## Stage-I — Earlier simulation-focused version

- Established the core architecture and processing flow.
- Developed RTL for CNN-related processing, ROI handling, SAD tracking, control, and supporting blocks.
- Created modulewise and system-oriented testbenches.
- Preserved Stage-I schematic, simulation, Tcl, and implementation images.
- Used a different FPGA target/configuration from the current hardware direction. Treat Stage-I implementation reports as historical and do not compare them directly with current reports unless target, constraints, clock settings, and implementation settings are comparable.

## Current development — Updated RTL and implementation

- Reorganized source into CNN, Communication, Control, Top, Tracking, and Vision areas.
- Continued development of pipelined modules and top-level integration while retaining the fundamental architecture.
- Added current resource-utilization, timing, and power report images under `images/implementation/`.
- Added a current simulation-log screenshot at `images/simulation/tb_log.png`.
- Prepared the project for a UART-based hardware demonstration.
- The end-to-end hardware demo remains in progress; the repository tree and screenshots alone do not prove it has passed.

## Evidence index

| Item | Path | Meaning |
|---|---|---|
| Complete architecture | `images/architecture/complete_architecture.jpg` | System overview |
| FSM | `images/architecture/fsm.png` | Control-flow illustration |
| ROI | `images/architecture/roi.png` | ROI concept |
| MAC | `images/architecture/mac_hardware_explain.png` | MAC concept |
| SAD | `images/architecture/SAD_explain.png` | Tracking concept |
| PWM | `images/architecture/PWM.png` | PWM/control concept |
| Current log screenshot | `images/simulation/tb_log.png` | Visual record; pair with transcript and testbench |
| Current utilization | `images/implementation/utilization.png` | Resource report snapshot |
| Current timing | `images/implementation/timing.png` | Timing report snapshot |
| Current power | `images/implementation/power.png` | Power report snapshot |
| Stage-I implementation | `images/implementation/stage-I_implementation/` | Historical evidence |
| Stage-I RTL schematic | `images/rtl diagram/stage-I_rtl/schematics.jpg` | Historical evidence |
| Stage-I simulation images | `images/simulation/stage-I_simulation/` | Historical evidence |

## Template for future dated entries

```text
### YYYY-MM-DD — Milestone title
Objective:
Changes (RTL / testbench / XDC / host software):
Tool and version:
Target board and FPGA part:
Testbench or hardware setup:
Parameters and constraints:
Expected result:
Observed result:
Pass/fail and warnings:
Resource/timing/power highlights:
Evidence paths:
Known limitations:
Next action:
```

## Suggested next milestones

1. Confirm the current top module and exact RTL dependencies.
2. Preserve the complete transcript corresponding to `tb_log.png`.
3. Record exact values from the current utilization, timing, and power reports.
4. Verify UART adapter voltage, wiring, constraints, and reset.
5. Pass a byte-level UART echo test.
6. Confirm frame marker and result-packet format from RTL.
7. Test frame transfer and end-to-end processing on hardware.
8. Update verification status with observed results, not expectations.

## Reporting discipline

Keep these levels distinct: **designed**, **simulated**, **synthesized**, **implemented**, **hardware-tested**, and **end-to-end verified**. A module may be simulated without having been hardware-tested; a report screenshot does not prove end-to-end operation.
