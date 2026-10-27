# Hardware Setup

## 1. Status and intent

The hardware-demo direction is a host PC running Python, connected to the FPGA through a USB-to-TTL UART adapter. The intended workflow sends grayscale frames to the FPGA and receives result data for host-side visualization.

**The complete physical demonstration is not claimed as successful here.** This document is a bring-up guide. Confirm details against the exact board revision, adapter specification, schematic, and active XDC.

## 2. Hardware checklist

- Intended ZedBoard / Zynq-7000 board.
- USB-to-TTL UART adapter compatible with the PC.
- Board power/programming cable as required.
- Jumper wires.
- Host PC; Python/`pyserial` for serial testing.

## 3. Voltage and electrical safety

- Confirm the adapter provides **3.3 V TTL UART** signaling for the selected FPGA I/O.
- Do not connect RS-232 voltage levels directly to FPGA I/O.
- Power the board according to its manual.
- Connect adapter ground to board ground.
- Do not connect adapter VCC to FPGA I/O; normally leave it disconnected when the board is independently powered.
- Check adapter logic voltage; do not assume 5 V logic is safe.
- Confirm that the physical I/O bank supports the I/O standard in the XDC.

## 4. UART wiring

The current project notes identify this intended mapping in `Constaints/zedboard_vajra.xdc`; verify it against the official board master XDC and schematic before wiring.

| USB-TTL | FPGA signal | Current intended mapping |
|---|---|---|
| TXD | `uart_rx_pin` | JA1 / package pin Y11 |
| RXD | `uart_tx_pin` | JA2 / package pin AA11 |
| GND | Board GND | Common ground |
| VCC | — | Do not connect by default |

TX and RX are crossed: adapter TXD goes to FPGA RX, and FPGA TX goes to adapter RX.

## 5. Constraints and reset

Check the active XDC against the selected top-level module. Confirm clock pin/period, UART pin locations, I/O standards, bank voltage, reset pin and polarity, and that all active top-level ports are constrained. A full-system XDC may contain PWM/LED ports that do not exist in a minimal UART echo top; use an appropriate stage-specific constraints file or ensure all active ports are correctly constrained.

Do not ignore DRC errors or force bitstream generation with unknown pin/bank settings.

## 6. Recommended bring-up sequence

### Stage A — Adapter loopback
1. Find the adapter COM port in Windows Device Manager.
2. Confirm adapter model and logic voltage.
3. If supported by its documentation, disconnect it from the FPGA and connect TXD to RXD.
4. Send test bytes from a terminal or Python and check they return unchanged.
5. Remove the loopback connection before connecting the FPGA.

### Stage B — FPGA byte echo
Build a minimal top containing only clock, reset, RX, and TX. Do not start with the full CNN/frame pipeline. Start at 115200 baud, 8 data bits, no parity, one stop bit (8-N-1), with the FPGA and host configured identically. Send one byte and wait for its echo before sending the next, unless the design has a FIFO.

### Stage C — Frame protocol
After byte echo passes:
1. Confirm the frame-start marker from the RTL.
2. Confirm the exact expected frame byte count.
3. Test a small frame if parameters permit.
4. Verify frame-complete signaling and memory contents.
5. Check behavior after reset or a partial frame.

### Stage D — Full-frame test
The development configuration has used 640 × 480 grayscale frames, or 307,200 payload bytes per frame. With 8-N-1 UART framing, each payload byte typically uses 10 transmitted bits. Approximate raw transfer times, excluding host overhead and processing:
- 115200 baud: 26.7 seconds per frame.
- 921600 baud: 3.33 seconds per frame.

Actual speed depends on the adapter, driver, protocol overhead, and system behavior. Do not begin full-frame streaming until framing and byte counts are reliable.

## 7. Python host setup

Install `pyserial` from PowerShell:

```powershell
py -m pip install pyserial
```

Use the actual COM port, close other applications holding that port, and match the FPGA baud rate. Inspect the result-packetizer RTL before writing a host parser; do not guess packet fields or coordinate encoding.

## 8. Troubleshooting

**No echo:** check COM port, crossed TX/RX, common ground, matching baud/framing, reset deassertion, correct programmed top, active XDC, and adapter voltage.

**Garbled data:** lower baud rate, verify clock/baud parameters, check wiring and adapter capability, and simulate UART sampling/stop-bit behavior.

**Fails during streams:** check buffering/FIFO capacity, upstream busy handling, frame counters, frame markers, memory arbitration, and whether the host sends faster than the FPGA can accept.

**Bitstream DRC failure:** check top-module ports, pin assignments, I/O standards, bank voltage, and clock constraints. Do not suppress errors simply to force generation.

## 9. Record each hardware test

Save date, Git commit, board/FPGA part, adapter and voltage, top module/XDC, baud/framing, test data, expected and observed output, errors, and evidence such as a terminal log or photo.
