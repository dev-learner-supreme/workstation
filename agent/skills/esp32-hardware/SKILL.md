---
name: esp32-hardware
description: Procedures and commands for connecting, communicating, and flashing ESP32/microcontroller hardware natively on Omarchy Linux.
---

# ESP32 & Embedded Hardware on Omarchy Linux

Guide and reference for USB serial microcontrollers (ESP32, ESP8266, STM32, Arduino, Heltec LoRa) running natively on Omarchy 4 (Arch Linux).

## Environment & Permissions
- **OS**: Bare-metal Omarchy Linux on Acer Swift Go 14.
- **Hardware Access**: Direct serial attachment via `/dev/ttyUSB*` or `/dev/ttyACM*`.
- **User Permissions**: Standard user `arun` belongs to the `uucp` group (Arch Linux standard for serial device access).
- **Driver Support**: Linux kernel drivers (`cp210x`, `ch341`, `ftdi_sio`, `cdc_acm`) are built into the kernel.

## 1. Device Connection & Verification
When plugging in any microcontroller via USB-C or USB-A:

1. Verify device enumeration via kernel ring buffer:
   ```bash
   dmesg | tail -n 20
   ```
2. Check for active serial nodes:
   ```bash
   ls -l /dev/ttyUSB* /dev/ttyACM* 2>/dev/null
   ```
   *Expected permissions: `crw-rw---- 1 root uucp ... /dev/ttyUSB0`*

3. Verify group membership if permission is denied:
   ```bash
   id -Gn | grep -q uucp || sudo usermod -aG uucp $USER
   ```

## 2. Firmware Flashing & Communication

* **esptool.py**:
  ```bash
  esptool.py --port /dev/ttyUSB0 chip_id
  esptool.py --port /dev/ttyUSB0 flash_id
  ```

* **PlatformIO (`pio`)**:
  ```bash
  pio run -t upload --upload-port /dev/ttyUSB0
  pio device monitor -p /dev/ttyUSB0 -b 115200
  ```

* **Serial Terminal / Monitor**:
  ```bash
  tio /dev/ttyUSB0
  # Or: picocom -b 115200 /dev/ttyUSB0
  ```

## 3. Hardware Safety & Firmware Rules
- **Safety (OTA):** Any OTA update code must include dual-bank rollback mechanisms (ESP-IDF/PlatformIO standard). Never write blocking code inside OTA download loops.
- **Safety (Memory):** Always validate array bounds and buffer sizes before copying LoRa payloads. Prevent buffer overflows.
- **Safety (RTOS):** Do not use `delay()` in FreeRTOS tasks; use `vTaskDelay()`. Always monitor and check for stack overflows when creating new tasks.
- **Architecture:** Assume ESP32 architecture. Default to PlatformIO structure unless Arduino IDE is explicitly requested.
- **LoRa (Heltec):** Specify the exact library (e.g. RadioLib or LMIC) and enforce strict payload size limits (max 51 bytes for low data rates).
