/**
 * @file DPS150_PSU.pde
 * @brief Main sketch — FNIRSI DPS-150 Power Supply Control.
 *
 * Entry point for the Processing application.  Sets up the window,
 * initialises the GUI and protocol layer, and routes Processing
 * callbacks (draw, serial, mouse, keyboard) to the appropriate handlers.
 *
 * Window size: 1100 x 720 pixels.
 */

void setup() {
  size(1100, 720);
  surface.setTitle("FNIRSI DPS-150 Power Supply Control");
  smooth(4);
  psu.initHistory();
  initGUI();
}

/**
 * Main draw loop — redraws the GUI and polls the PSU for new data.
 */
void draw() {
  drawGUI();
  psu.pollPSU();
}

/**
 * Serial receive callback — feeds incoming bytes to the protocol
 * state machine one at a time.
 * @param port The serial port that has data available
 */
void serialEvent(Serial port) {
  while (port.available() > 0) {
    int b = port.read();
    psu.processSerialByte(b);
  }
}

/** Route mouse-press events to the GUI handler. */
void mousePressed() {
  handleGUIClick();
}

/** Route mouse-release events to the GUI handler. */
void mouseReleased() {
  handleGUIRelease();
}

/** Route key-press events to the GUI handler. */
void keyPressed() {
  handleGUIKey(key, keyCode);
}

/** Route mouse-wheel events to the graph zoom handler. */
void mouseWheel(MouseEvent event) {
  handleMouseWheel(event.getCount());
}
