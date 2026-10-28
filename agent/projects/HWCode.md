# HWCode Profile (Private Personal Knowledge Base)

- **Hardware Scope:** ESP32, Heltec LoRa microcontrollers.
- **Toolchain:** PlatformIO standard (preferred over Arduino IDE unless requested).

## Embedded Safety & Architecture
- **OTA Updates:** Mandatory dual-bank partition rollback (ESP-IDF / PlatformIO). Never write blocking delays inside OTA download loops.
- **Memory Safety:** Enforce array bounds and buffer checks on all LoRa packet decoders; prevent stack/heap overflows.
- **FreeRTOS:** Banned: `delay()`. Mandatory: `vTaskDelay()`. Explicit stack allocation checks on all tasks.
- **LoRa Payloads:** Max 51 bytes for low data rates; specify exact library (RadioLib or LMIC).
