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

import controlP5.*;

ControlP5 cp5;

void setup() {
  size(1100, 720);
  surface.setTitle("FNIRSI DPS-150 Power Supply Control");
  smooth(4);
  cp5 = new ControlP5(this);
  cp5.setAutoDraw(false);
  psu.initHistory();
  initGUI();
}

/**
 * Main draw loop — redraws the GUI and polls the PSU for new data.
 */
void draw() {
  drawGUI();
  cp5.draw();
  drawAdvanced();
  updateAdvanced();
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

/** Route mouse-press events — Advanced overlay gets priority. */
void mousePressed() {
  if (advancedOpen) {
    handleAdvancedClick();
  }
  // cp5 handles its own mouse events automatically
}

/** Route key-press events — Advanced overlay gets priority. */
void keyPressed() {
  if (advancedOpen) {
    handleAdvancedKey(key, keyCode);
  }
  // cp5 handles textfield key events automatically
}

/** Route mouse-wheel events to the graph zoom handler. */
void mouseWheel(MouseEvent event) {
  handleMouseWheel(event.getCount());
}

/**
 * ControlP5 event handler — dispatches all cp5 widget events.
 */
void controlEvent(ControlEvent e) {
  if (advancedOpen) return;
  handleCp5Event(e);
}
