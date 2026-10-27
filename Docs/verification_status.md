# Verification Status

## Purpose

This page separates repository artifacts from verified behavior. Update it after tests are run. The source tree, a screenshot, or successful synthesis alone does not prove the complete system works on hardware.

## Current status overview

| Area | Evidence visible in the repository | Accurate status description |
|---|---|---|
| Core architecture | `images/architecture/complete_architecture.jpg` and related diagrams | Architecture defined; design continues to evolve |
| RTL modules | Organized under `RTL/` | RTL present; behavior depends on tests actually run |
| Testbenches | `Simulation/Testbenches/` with modulewise and complete-system folders | Testbench assets present |
| Current simulation log | `images/simulation/tb_log.png` | Screenshot available; pair it with the exact testbench and full transcript |
| Current utilization report | `images/implementation/utilization.png` | Report image available |
| Current timing report | `images/implementation/timing.png` | Report image available |
| Current power report | `images/implementation/power.png` | Report image available |
| Stage-I implementation results | `images/implementation/stage-I_implementation/` | Historical Stage-I evidence |
| UART wiring | Existing XDC and hardware-demo preparation | Preparation in progress |
| UART byte echo on physical board | Not established by the repository tree alone | Not confirmed here |
| Full host-frame-to-FPGA-result flow | Not established by the repository tree alone | Not yet claimed as hardware-verified |
| Physical PWM/actuator behavior | RTL/diagram present | Physical behavior not confirmed here |

## Simulation log

`images/simulation/tb_log.png` is a visual record. Before describing the associated test as passed, identify:
- Testbench filename and DUT/top module.
- Parameter values and scenarios exercised.
- Expected and observed outputs.
- Warnings/errors and whether the simulation ended normally.
- Simulator/Vivado version and source commit.

Scope any pass claim to the test cases that were actually exercised. A module-level pass does not automatically validate the complete integrated pipeline.

## Implementation reports

Current images:
- `images/implementation/utilization.png`
- `images/implementation/timing.png`
- `images/implementation/power.png`

Record the target FPGA part and exact counts from the utilization report (LUTs, registers, BRAM, DSPs, I/O as applicable). For timing, record the clock constraint, worst slack, and whether the report is post-synthesis or post-implementation. For power, state whether it is an estimate or measurement and document its assumptions. Do not infer numbers from filenames.

## Stage-I versus current results

Historical images are stored under `images/implementation/stage-I_implementation/`, `images/rtl diagram/stage-I_rtl/`, and `images/simulation/stage-I_simulation/`. Label them Stage-I. The earlier version used a different FPGA target/configuration, so direct numerical comparisons may be misleading unless the FPGA part, clock constraints, source revision, tool settings, and report stage are comparable.

## Verification ladder

1. **Code present** — module exists.
2. **Module simulation passed** — named testbench passed specified cases.
3. **Integration simulation passed** — integrated top exercised with meaningful scenarios.
4. **Synthesis passed** — synthesis completed for a stated part.
5. **Implementation passed** — implementation/DRC and timing status documented.
6. **UART link tested** — physical byte communication observed.
7. **Frame protocol tested** — frame boundaries and byte counts validated.
8. **End-to-end hardware tested** — host sends a frame and receives the expected result.
9. **Actuator tested** — any physical PWM/actuator path safely and repeatably tested.

Do not skip levels when describing progress.

## Test record template

```text
Test ID:
Date:
Git commit:
Vivado/simulator version:
Target board and FPGA part:
DUT/top module:
Testbench or hardware setup:
Parameters and constraints:
Expected behavior:
Observed behavior:
Pass/fail:
Warnings/errors:
Evidence paths:
Known limitations:
Next action:
```

## Recommended next steps

1. Confirm the current top module, RTL dependencies, target part, and active XDC.
2. Preserve the full transcript for the test represented by `tb_log.png`.
3. Extract exact values from current utilization, timing, and power reports.
4. Verify UART adapter voltage, wiring, pin constraints, and reset.
5. Pass a minimal byte-echo test.
6. Confirm frame-start and result-packet formats from the RTL.
7. Test frame transfer and end-to-end processing on hardware.
8. Update this page with measured results, keeping simulation and hardware evidence separate.
