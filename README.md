# FNIRSI DPS-150 Power Supply Control

A Processing desktop application for controlling the FNIRSI DPS-150 programmable power supply over USB serial.

## Features

- Real-time voltage, current, and power monitoring with analog gauges and scrolling graph
- Set voltage (0-30 V) and current (0-5 A) with sliders, textfields, or fine-adjust buttons
- Output on/off toggle with CV/CC mode indication
- 6 preset slots (load/save)
- Over-voltage, over-current, over-power, and over-temperature protection configuration
- Display brightness control
- CSV data logging
- Advanced programmable output:
  - Sequential output (up to 10 steps with configurable voltage, current, delay, and looping)
  - Voltage sweep (scan voltage range at fixed current)
  - Current sweep (scan current range at fixed voltage)

## Prerequisites

1. **Processing 4** -- Download and install from [https://processing.org/download](https://processing.org/download)
2. **ControlP5 library** -- Install from within Processing:
   - Open Processing
   - Go to **Sketch > Import Library... > Manage Libraries...**
   - Search for **ControlP5**
   - Click **Install**
3. **FNIRSI DPS-150** connected via USB

## Running the Application

1. Connect the DPS-150 to your computer via USB
2. Open `DPS150_PSU.pde` in Processing (the other `.pde` files in the same folder will load automatically as tabs)
3. Click the **Run** button (or press Cmd+R / Ctrl+R)
4. In the application window, select the correct serial port and click **Connect**

On macOS the port typically appears as `/dev/cu.usbmodem...`. The application will attempt to auto-connect to a known port on startup.

## Serial Connection

- Baud rate: 115200, 8N1
- The DPS-150 streams live data continuously once connected
- The application polls for additional registers (mode, protection status) every ~1 second

## File Structure

| File | Description |
|------|-------------|
| `DPS150_PSU.pde` | Main sketch -- setup, draw loop, event routing |
| `Protocol.pde` | Serial protocol layer (`DPS150Protocol` class) |
| `GUI.pde` | GUI layout, widget creation, event handling |
| `Widgets.pde` | Custom display widgets (gauges, graph, panels, buttons) |
| `Advanced.pde` | Advanced overlay -- sequential output and sweep modes |

## Documentation

Open `docs.html` in a browser to view the Doxygen-generated API documentation.

To regenerate the documentation (requires [Doxygen](https://www.doxygen.nl)):

```sh
doxygen Doxyfile
```

## License

Copyright 2026 Peter Vancorenland. All rights reserved.

Redistribution and use of this source code, with or without modification, is permitted provided that the original author is credited.
