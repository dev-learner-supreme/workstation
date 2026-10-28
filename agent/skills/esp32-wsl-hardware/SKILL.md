---
name: esp32-wsl-hardware
description: Procedures and commands for connecting, binding, attaching, and flashing ESP32 microcontrollers in WSL2 via usbipd-win.
---

# ESP32 & Embedded Hardware in WSL2

Guide and reference for attaching USB serial devices (ESP32, ESP8266, STM32, Arduino) from Windows 11 to WSL2 Ubuntu using `usbipd-win`.

## Environment Status
- **Host**: Windows 11 with `usbipd-win` installed.
- **WSL2**: Ubuntu (`arun` user belongs to `dialout` group, `usbip` CLI tools installed at `/usr/bin/usbip`).

## 1. One-Time Setup (Per Physical USB Port)
Run in **PowerShell as Administrator**:

1. Plug in the ESP32 board.
2. Identify the device BUSID (look for CP210x, CH340, HL-340, FTDI, or USB Serial):
   ```powershell
   usbipd list
   ```
3. Bind the device to the sharing service:
   ```powershell
   usbipd bind --busid <BUSID>
   ```

## 2. Daily / Per-Session Attachment
Run in **Standard PowerShell** (No Admin required):

```powershell
usbipd attach --wsl --busid <BUSID>
```
*Note: If targeting Ubuntu specifically, run `usbipd attach --wsl Ubuntu --busid <BUSID>`.*

To detach cleanly when finished:
```powershell
usbipd detach --busid <BUSID>
```

## 3. Verification & Flashing in WSL2
Run in **WSL Ubuntu Terminal**:

1. Check for active serial devices:
   ```bash
   ls -l /dev/ttyUSB* /dev/ttyACM*
   ```
   Expected output format: `crw-rw---- 1 root dialout 188, 0 ... /dev/ttyUSB0`

2. Communicate or flash firmware:
   - **esptool.py**:
     ```bash
     esptool.py --port /dev/ttyUSB0 chip_id
     esptool.py --port /dev/ttyUSB0 flash_id
     ```
   - **PlatformIO**:
     ```bash
     pio run -t upload --upload-port /dev/ttyUSB0
     pio device monitor -p /dev/ttyUSB0 -b 115200
     ```

## 4. Hardware Safety & Firmware Rules
- **Safety (OTA):** Any OTA update code must include dual-bank rollback mechanisms (ESP-IDF/PlatformIO standard). Never write blocking code inside OTA download loops.
- **Safety (Memory):** Always validate array bounds and buffer sizes before copying LoRa payloads. Prevent buffer overflows.
- **Safety (RTOS):** Do not use `delay()` in FreeRTOS tasks; use `vTaskDelay()`. Always monitor and check for stack overflows when creating new tasks.
- **Architecture:** Assume ESP32 architecture. Default to PlatformIO structure unless Arduino IDE is explicitly requested.
- **LoRa (Heltec):** Specify the exact library (e.g. RadioLib or LMIC) and enforce strict payload size limits (max 51 bytes for low data rates).
