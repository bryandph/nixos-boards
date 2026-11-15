---
type: Gotcha
title: FRDM-i.MX95 M7 console
description: Use the CH344 if04 stable device path for M7 UART capture.
tags: [nixos-boards, frdm-imx95, m7, uart]
status: draft
generated:
  by: worker-nixos-boards-BPH-66-1/openai-gpt-6.1-sol
  at: 2026-11-15T05:48:37Z
sources:
  - id: memory-1
    resource: https://git.bph/bryan/nixspace/src/commit/ae19e6622a977e985b3521f17fec5895cd9fb51d/.serena/memories/hardware/frdm-imx95-m7-runtime.md
  - id: evidence-1
    resource: https://git.bph/bryan/nixspace/src/commit/ae19e6622a977e985b3521f17fec5895cd9fb51d/docs/operations/frdm-imx95-sd-bringup.md
  - id: evidence-2
    resource: https://github.com/bryandph/nixos-boards/blob/66fcdbb0d61b0e98fbc838c019d45f04f1877c18/packages/nxp/frdm-imx95/scripts/frdm-imx95-m7-ctl
---

# FRDM-i.MX95 M7 console

The confirmed M7 console is the WCH CH344 quad-serial interface with the
stable path `/dev/serial/by-id/usb-wch.cn_USB_Quad_Serial_<serial>-if04`.
The other interfaces are `if00` for A55/U-Boot/Linux, `if02` for M33, and
`if06` spare. `/dev/ttyACM*` and `/dev/ttyCH343USB*` numbering is volatile;
do not use that numbering to identify the M7 console.

`frdm-imx95-m7-ctl uart-list` lists CH34x candidates, including
`/dev/serial/by-id/usb-wch.cn_USB_Quad_Serial_*`; it does not select the M7
interface for you. If no candidates appear, check the FRDM J1 USB connection
and host driver, as the script advises.

`frdm-imx95-m7-ctl uart DEVICE [LOGFILE]` requires an explicit stable
`DEVICE` path. Pass the `-if04` path above to capture at 115200 8N1. Output
is displayed and written to `LOGFILE` (default `frdm-imx95-m7-uart.log`);
press Ctrl-C to stop.

M7 firmware requirements belong to [frdm-imx95-bsp](https://git.bph/bryan/frdm-imx95-bsp)
and its knowledge bundle, carried in embedded-rust at `bsp/devboard/frdm-imx95`.

Repository evidence: [`uart_list` and `uart_capture`](../packages/nxp/frdm-imx95/scripts/frdm-imx95-m7-ctl),
[FRDM-i.MX95 M7 documentation](../docs/wiki/FRDM-i.MX95-M7.md).
