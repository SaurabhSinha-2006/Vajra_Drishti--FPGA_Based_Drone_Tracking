# Architecture

## 1. Purpose

Vajra Drishti is an RTL-first FPGA project exploring motion-guided target detection and tracking. The core architecture remains consistent with the earlier Stage-I work; the current version continues to evolve through pipelining, RTL updates, integration, implementation analysis, and hardware-demo preparation.

![Complete architecture](../images/architecture/complete_architecture.jpg)

## 2. Intended processing flow

```text
Host frame source
   -> UART receiver
   -> frame storage / motion candidate detection
   -> ROI extraction / ROI buffer
   -> CNN processing / candidate verification
   -> SAD-based tracking / coordinate update
   -> system control and result interface
   -> planned UART result return to host
```

PWM-related control logic is also present. The diagram describes design intent; the exact handshakes, memory arbitration, coordinate conventions, and packet fields must be confirmed from current RTL.

![System FSM](../images/architecture/fsm.png)

## 3. Subsystems

### Communication
UART-related logic is intended to carry frame data from a host and return results. Verify byte echo first, then frame framing and finally full-frame behavior. An echo test proves only the serial path.

### Frame handling and motion candidate
The development configuration has used 640 × 480 grayscale frames: 640 × 480 = 307,200 bytes at one byte per pixel. Confirm the actual top-level parameters before relying on this. Define frame marker, byte count, incomplete-frame behavior, and reset recovery.

### ROI extraction
![ROI concept](../images/architecture/roi.png)

ROI extraction focuses downstream processing on a candidate region. Confirm actual ROI dimensions, coordinate origin, edge clipping, and memory latency from RTL.

### CNN datapath
![MAC hardware explanation](../images/architecture/mac_hardware_explain.png)

![CNN concept](../images/architecture/software_cnn.png)

The source tree includes line/window buffering, MAC, convolution, pooling, serialization, and dense-processing modules. Document tensor dimensions, kernel/stride/padding, signedness, weight sources, accumulator widths, overflow behavior, thresholds, and latency from the source and tests. The illustrations are explanatory, not a replacement for implementation details.

### SAD tracking
![SAD explanation](../images/architecture/SAD_explain.png)

SAD compares candidate patches using absolute pixel differences. Document search window, patch size, candidate stepping, score width, tie-breaking, and coordinate update behavior from current RTL.

### Control and PWM
![PWM concept](../images/architecture/PWM.png)

The FSM coordinates processing and PWM-related RTL is present. Physical actuator behavior should only be claimed after safe electrical integration and board testing.

## 4. Source-tree map

| Path | Intended role |
|---|---|
| `RTL/Top/` | Top-level integration |
| `RTL/Communication/` | UART/serial logic |
| `RTL/Vision/` | Frame and ROI processing |
| `RTL/CNN/` | CNN datapath |
| `RTL/Tracking/` | SAD tracking |
| `RTL/Control/` | FSM and PWM/control |
| `Simulation/Testbenches/` | Modulewise and complete-system tests |
| `Memory files/` | Memory/weight assets where used |
| `Constaints/zedboard_vajra.xdc` | Existing constraints file; verify pins and I/O standards |

## 5. Interface contracts to document

Before declaring the design reproducible, specify baud rate and serial framing, frame marker, pixel byte order, frame byte count, recovery after dropped bytes/reset, memory latency/arbitration, ROI size and coordinate convention, CNN output encoding, result-packet layout, system clock, target part, and XDC revision.

## 6. Current versus planned

The fundamental architecture is retained from Stage-I, while the current RTL and implementation work have evolved. UART hardware demonstration is in preparation. Mark the full host-to-FPGA-to-host pipeline hardware-verified only after a repeatable test is recorded.
