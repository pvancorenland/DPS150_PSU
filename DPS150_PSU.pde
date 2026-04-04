// DPS150_PSU.pde — Fnirsi DPS-150 Power Supply Control
// Full-featured GUI with circular gauges, real-time graphs, and data logging

void setup() {
  size(1100, 720);
  surface.setTitle("FNIRSI DPS-150 Power Supply Control");
  smooth(4);
  psu.initHistory();
  initGUI();
}

void draw() {
  drawGUI();
  psu.pollPSU();
}

void serialEvent(Serial port) {
  while (port.available() > 0) {
    int b = port.read();
    psu.processSerialByte(b);
  }
}

void mousePressed() {
  handleGUIClick();
}

void mouseReleased() {
  handleGUIRelease();
}

void keyPressed() {
  handleGUIKey(key, keyCode);
}

void mouseWheel(MouseEvent event) {
  handleMouseWheel(event.getCount());
}
