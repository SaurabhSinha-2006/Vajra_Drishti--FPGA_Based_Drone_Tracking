# ============================================================
# VAJRA DRISHTI - ZEDBOARD
# Device: XC7Z020
# ============================================================


# ============================================================
# 1. 100 MHz PL CLOCK
# ZedBoard GCLK = Y9
# ============================================================

set_property PACKAGE_PIN Y9 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

create_clock -period 10.000 -name sys_clk [get_ports clk]


# ============================================================
# 2. UART RX
# USB-TTL TX  ->  ZedBoard JA1
# JA1 = Y11
# ============================================================

set_property PACKAGE_PIN Y11 [get_ports uart_rx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]


# ============================================================
# 3. UART TX
# ZedBoard JA2  ->  USB-TTL RX
# JA2 = AA11
# ============================================================

set_property PACKAGE_PIN AA11 [get_ports uart_tx_pin]
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]


# ============================================================
# 4. PAN PWM
# JA3 = Y10
# ============================================================

set_property PACKAGE_PIN Y10 [get_ports pwm_pan]
set_property IOSTANDARD LVCMOS33 [get_ports pwm_pan]


# ============================================================
# 5. TILT PWM
# JA4 = AA9
# ============================================================

set_property PACKAGE_PIN AA9 [get_ports pwm_tilt]
set_property IOSTANDARD LVCMOS33 [get_ports pwm_tilt]


# ============================================================
# 6. SYSTEM STATUS LED
# LD0 = T22
# ============================================================

set_property PACKAGE_PIN T22 [get_ports system_state_led]
set_property IOSTANDARD LVCMOS33 [get_ports system_state_led]


# ============================================================
# 7. RESET
# BTNC = P16
# Bank 34 = 1.8 V by default
# ============================================================

set_property PACKAGE_PIN P16 [get_ports reset]
set_property IOSTANDARD LVCMOS18 [get_ports reset]