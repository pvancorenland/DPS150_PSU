// Widgets.pde — Enhanced GUI widgets with circular gauges, graphs, and lab instrument styling

// ============================================================
// COLOR PALETTE — professional instrument look
// ============================================================
static final color COL_BG           = #1C1C28;
static final color COL_PANEL        = #232336;
static final color COL_PANEL_HEADER = #2A2A44;
static final color COL_PANEL_LITE   = #2E2E4A;
static final color COL_BORDER       = #3A3A5C;
static final color COL_ACCENT       = #4A90D9;
static final color COL_ACCENT_LITE  = #6BB0FF;
static final color COL_TEXT         = #E0E0E8;
static final color COL_TEXT_DIM     = #888899;
static final color COL_DIM          = #555566;
static final color COL_VOLT         = #FFD54F;  // warm amber
static final color COL_VOLT_DIM     = #664D00;
static final color COL_CURR         = #4DD0E1;  // teal cyan
static final color COL_CURR_DIM     = #005662;
static final color COL_POWER        = #81C784;  // soft green
static final color COL_POWER_DIM    = #1B5E20;
static final color COL_ON           = #00E676;
static final color COL_OFF          = #FF5252;
static final color COL_WARN         = #FF9800;
static final color COL_BTN          = #2E3B55;
static final color COL_BTN_HOVER    = #3D5070;
static final color COL_BTN_ACTIVE   = #4A6590;
static final color COL_INPUT_BG     = #171722;
static final color COL_INPUT_BORDER = #3A3A5C;
static final color COL_GRAPH_BG     = #14141E;
static final color COL_GRID         = #252538;

// ============================================================
// CIRCULAR GAUGE — analog meter style
// ============================================================
class CircularGauge {
  float cx, cy, radius;
  float minVal, maxVal;
  float value = 0;
  String label, unit;
  color gaugeColor, gaugeDim;
  int majorTicks, minorTicks;
  float startAngle = PI * 0.75;   // 135 degrees (lower-left)
  float sweepAngle = PI * 1.5;    // 270 degree sweep

  CircularGauge(float cx, float cy, float radius, String label, String unit,
                float minVal, float maxVal, color gaugeColor, color gaugeDim) {
    this.cx = cx;
    this.cy = cy;
    this.radius = radius;
    this.label = label;
    this.unit = unit;
    this.minVal = minVal;
    this.maxVal = maxVal;
    this.gaugeColor = gaugeColor;
    this.gaugeDim = gaugeDim;
    this.majorTicks = 6;
    this.minorTicks = 5;
  }

  void draw() {
    pushMatrix();
    translate(cx, cy);

    // Outer ring shadow
    noFill();
    stroke(0, 40);
    strokeWeight(3);
    arc(0, 0, radius*2+6, radius*2+6, startAngle, startAngle + sweepAngle);

    // Outer bezel ring
    stroke(COL_BORDER);
    strokeWeight(2);
    arc(0, 0, radius*2+2, radius*2+2, startAngle, startAngle + sweepAngle);

    // Background arc (dim track)
    stroke(gaugeDim, 60);
    strokeWeight(10);
    arc(0, 0, radius*1.7, radius*1.7, startAngle, startAngle + sweepAngle);

    // Value arc (filled portion)
    float fraction = constrain((value - minVal) / (maxVal - minVal), 0, 1);
    float valueAngle = startAngle + sweepAngle * fraction;
    stroke(gaugeColor);
    strokeWeight(10);
    arc(0, 0, radius*1.7, radius*1.7, startAngle, valueAngle);

    // Glow effect on the value arc
    stroke(gaugeColor, 40);
    strokeWeight(18);
    arc(0, 0, radius*1.7, radius*1.7, startAngle, valueAngle);

    // Draw tick marks
    for (int i = 0; i <= majorTicks; i++) {
      float tickAngle = startAngle + sweepAngle * ((float)i / majorTicks);
      float innerR = radius * 0.78;
      float outerR = radius * 0.9;
      float x1 = cos(tickAngle) * innerR;
      float y1 = sin(tickAngle) * innerR;
      float x2 = cos(tickAngle) * outerR;
      float y2 = sin(tickAngle) * outerR;
      stroke(COL_TEXT_DIM);
      strokeWeight(1.5);
      line(x1, y1, x2, y2);

      // Tick labels
      float labelR = radius * 0.65;
      float lx = cos(tickAngle) * labelR;
      float ly = sin(tickAngle) * labelR;
      fill(COL_TEXT_DIM);
      noStroke();
      textAlign(CENTER, CENTER);
      textSize(9);
      float tickVal = minVal + (maxVal - minVal) * ((float)i / majorTicks);
      text(nf(tickVal, 0, (maxVal <= 10) ? 1 : 0), lx, ly);

      // Minor ticks
      if (i < majorTicks) {
        for (int j = 1; j < minorTicks; j++) {
          float minAngle = tickAngle + (sweepAngle / majorTicks) * ((float)j / minorTicks);
          float mx1 = cos(minAngle) * (radius * 0.83);
          float my1 = sin(minAngle) * (radius * 0.83);
          float mx2 = cos(minAngle) * (radius * 0.88);
          float my2 = sin(minAngle) * (radius * 0.88);
          stroke(COL_DIM, 120);
          strokeWeight(0.8);
          line(mx1, my1, mx2, my2);
        }
      }
    }

    // Needle
    float needleAngle = startAngle + sweepAngle * fraction;
    float needleLen = radius * 0.72;
    float nx = cos(needleAngle) * needleLen;
    float ny = sin(needleAngle) * needleLen;
    // Needle shadow
    stroke(0, 60);
    strokeWeight(3);
    line(2, 2, nx+2, ny+2);
    // Needle body
    stroke(gaugeColor);
    strokeWeight(2.5);
    line(0, 0, nx, ny);
    // Center cap
    fill(COL_PANEL_HEADER);
    stroke(gaugeColor);
    strokeWeight(1.5);
    ellipse(0, 0, 12, 12);

    // Digital readout in center
    fill(gaugeColor);
    noStroke();
    textAlign(CENTER, CENTER);
    textSize(radius * 0.32);
    text(nf(value, 0, (maxVal <= 10) ? 3 : 2), 0, radius * 0.28);

    // Unit label
    fill(gaugeColor, 180);
    textSize(radius * 0.16);
    text(unit, 0, radius * 0.48);

    // Label at bottom
    fill(COL_TEXT_DIM);
    textSize(radius * 0.13);
    text(label, 0, radius * 0.63);

    popMatrix();
  }
}

// ============================================================
// SCROLLING GRAPH — real-time V/A/W plot
// ============================================================
class ScrollingGraph {
  float x, y, w, h;
  String title;
  boolean showVoltage = true;
  boolean showCurrent = true;
  boolean showPower = false;
  float voltScale = 30.0;
  float currScale = 5.0;
  float powerScale = 150.0;

  ScrollingGraph(float x, float y, float w, float h) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    this.title = "Waveform";
  }

  void draw() {
    // Background
    fill(COL_GRAPH_BG);
    stroke(COL_BORDER);
    strokeWeight(1);
    rect(x, y, w, h, 4);

    // Title bar
    fill(COL_PANEL_HEADER);
    noStroke();
    rect(x+1, y+1, w-2, 22, 3, 3, 0, 0);
    fill(COL_TEXT);
    textAlign(LEFT, CENTER);
    textSize(11);
    text(title, x + 8, y + 12);

    // Legend
    float lx = x + w - 200;
    float ly = y + 12;
    if (showVoltage) {
      fill(COL_VOLT); noStroke(); rect(lx, ly-4, 8, 8);
      fill(COL_TEXT_DIM); textAlign(LEFT, CENTER); textSize(9);
      text("Voltage", lx+12, ly); lx += 55;
    }
    if (showCurrent) {
      fill(COL_CURR); noStroke(); rect(lx, ly-4, 8, 8);
      fill(COL_TEXT_DIM); text("Current", lx+12, ly); lx += 55;
    }
    if (showPower) {
      fill(COL_POWER); noStroke(); rect(lx, ly-4, 8, 8);
      fill(COL_TEXT_DIM); text("Power", lx+12, ly);
    }

    float gx = x + 45;
    float gy = y + 28;
    float gw = w - 55;
    float gh = h - 38;

    // Grid
    stroke(COL_GRID);
    strokeWeight(0.5);
    for (int i = 0; i <= 5; i++) {
      float yy = gy + gh * i / 5.0;
      line(gx, yy, gx + gw, yy);
    }
    for (int i = 0; i <= 10; i++) {
      float xx = gx + gw * i / 10.0;
      line(xx, gy, xx, gy + gh);
    }

    // Y-axis labels (voltage scale on left)
    fill(COL_TEXT_DIM);
    textSize(8);
    textAlign(RIGHT, CENTER);
    for (int i = 0; i <= 5; i++) {
      float yy = gy + gh * i / 5.0;
      float vLabel = voltScale * (1.0 - (float)i/5.0);
      text(nf(vLabel, 0, 0), gx - 4, yy);
    }

    // X-axis time labels
    textAlign(CENTER, TOP);
    float totalTimeSec = historyCount * pollInterval / 1000.0;
    for (int i = 0; i <= 4; i++) {
      float xx = gx + gw * i / 4.0;
      float tLabel = -totalTimeSec + totalTimeSec * ((float)i / 4.0);
      text(nf(tLabel, 0, 0) + "s", xx, gy + gh + 2);
    }

    // Plot data
    if (historyCount > 1) {
      noFill();
      int start = (historyIndex - historyCount + GRAPH_HISTORY) % GRAPH_HISTORY;

      if (showVoltage) {
        stroke(COL_VOLT);
        strokeWeight(1.5);
        beginShape();
        for (int i = 0; i < historyCount; i++) {
          int idx = (start + i) % GRAPH_HISTORY;
          float px = gx + gw * ((float)i / (GRAPH_HISTORY - 1));
          float py = gy + gh * (1.0 - historyV[idx] / voltScale);
          vertex(px, constrain(py, gy, gy+gh));
        }
        endShape();
      }

      if (showCurrent) {
        stroke(COL_CURR);
        strokeWeight(1.5);
        beginShape();
        for (int i = 0; i < historyCount; i++) {
          int idx = (start + i) % GRAPH_HISTORY;
          float px = gx + gw * ((float)i / (GRAPH_HISTORY - 1));
          float py = gy + gh * (1.0 - historyA[idx] / currScale);
          vertex(px, constrain(py, gy, gy+gh));
        }
        endShape();
      }

      if (showPower) {
        stroke(COL_POWER);
        strokeWeight(1.0);
        beginShape();
        for (int i = 0; i < historyCount; i++) {
          int idx = (start + i) % GRAPH_HISTORY;
          float px = gx + gw * ((float)i / (GRAPH_HISTORY - 1));
          float py = gy + gh * (1.0 - historyW[idx] / powerScale);
          vertex(px, constrain(py, gy, gy+gh));
        }
        endShape();
      }
    }

    // Border
    noFill();
    stroke(COL_BORDER);
    strokeWeight(1);
    rect(gx, gy, gw, gh);
  }
}

// ============================================================
// PANEL — titled panel with header
// ============================================================
class Panel {
  float x, y, w, h;
  String title;

  Panel(float x, float y, float w, float h, String title) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    this.title = title;
  }

  void draw() {
    // Shadow
    fill(0, 30);
    noStroke();
    rect(x+2, y+2, w, h, 5);
    // Body
    fill(COL_PANEL);
    stroke(COL_BORDER);
    strokeWeight(1);
    rect(x, y, w, h, 5);
    // Header
    fill(COL_PANEL_HEADER);
    noStroke();
    rect(x+1, y+1, w-2, 24, 4, 4, 0, 0);
    // Title
    fill(COL_TEXT);
    textAlign(LEFT, CENTER);
    textSize(11);
    text(title, x + 10, y + 13);
  }

  float contentX() { return x + 8; }
  float contentY() { return y + 30; }
  float contentW() { return w - 16; }
  float contentH() { return h - 36; }
}

// ============================================================
// BUTTON — enhanced with icon support
// ============================================================
class Button {
  float x, y, w, h;
  String label;
  color bgColor, hoverColor, textColor;
  boolean hovered = false;
  boolean enabled = true;
  boolean rounded = false;

  Button(float x, float y, float w, float h, String label) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    this.label = label;
    this.bgColor = COL_BTN;
    this.hoverColor = COL_BTN_HOVER;
    this.textColor = COL_TEXT;
  }

  void draw() {
    hovered = enabled && mouseX >= x && mouseX <= x+w && mouseY >= y && mouseY <= y+h;
    // Shadow
    fill(0, 25);
    noStroke();
    rect(x+1, y+1, w, h, rounded ? h/2 : 4);
    // Body
    fill(enabled ? (hovered ? hoverColor : bgColor) : #2A2A35);
    stroke(enabled ? COL_BORDER : #333340);
    strokeWeight(1);
    rect(x, y, w, h, rounded ? h/2 : 4);
    // Highlight edge
    if (enabled && hovered) {
      stroke(COL_ACCENT_LITE, 40);
      line(x+2, y+1, x+w-2, y+1);
    }
    // Label
    fill(enabled ? textColor : #555560);
    textAlign(CENTER, CENTER);
    textSize(constrain(h * 0.42, 9, 14));
    text(label, x + w/2, y + h/2);
  }

  boolean clicked() {
    return enabled && hovered;
  }
}

// ============================================================
// TOGGLE BUTTON — large ON/OFF with LED indicator
// ============================================================
class ToggleButton {
  float x, y, w, h;
  boolean state = false;
  boolean hovered = false;

  ToggleButton(float x, float y, float w, float h) {
    this.x = x; this.y = y; this.w = w; this.h = h;
  }

  void draw() {
    hovered = mouseX >= x && mouseX <= x+w && mouseY >= y && mouseY <= y+h;

    // Outer glow when ON
    if (state) {
      fill(COL_ON, 15);
      noStroke();
      rect(x-4, y-4, w+8, h+8, 12);
    }

    // Button body
    fill(state ? #1B4332 : #3E1A1A);
    stroke(state ? COL_ON : COL_OFF);
    strokeWeight(2);
    rect(x, y, w, h, 8);

    // LED indicator
    float ledX = x + w/2;
    float ledY = y + 14;
    fill(state ? COL_ON : #441111);
    noStroke();
    ellipse(ledX, ledY, 10, 10);
    // LED glow
    if (state) {
      fill(COL_ON, 40);
      ellipse(ledX, ledY, 20, 20);
    }

    // Label
    fill(state ? COL_ON : COL_OFF);
    textAlign(CENTER, CENTER);
    textSize(18);
    text(state ? "OUTPUT ON" : "OUTPUT OFF", x + w/2, y + h/2 + 4);
  }

  boolean clicked() { return hovered; }
}

// ============================================================
// TEXT FIELD — enhanced editable input
// ============================================================
class TextField {
  float x, y, w, h;
  String value = "";
  String label = "";
  String suffix = "";
  boolean focused = false;
  boolean hovered = false;
  float minVal = 0;
  float maxVal = 100;

  TextField(float x, float y, float w, float h, String label, String suffix) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    this.label = label;
    this.suffix = suffix;
  }

  void draw() {
    hovered = mouseX >= x && mouseX <= x+w && mouseY >= y && mouseY <= y+h;
    // Label
    fill(COL_TEXT_DIM);
    textAlign(LEFT, BOTTOM);
    textSize(10);
    text(label, x, y - 3);
    // Input box
    fill(COL_INPUT_BG);
    stroke(focused ? COL_ACCENT : COL_INPUT_BORDER);
    strokeWeight(focused ? 1.5 : 1);
    rect(x, y, w, h, 3);
    // Focused highlight
    if (focused) {
      noFill();
      stroke(COL_ACCENT, 30);
      strokeWeight(3);
      rect(x-1, y-1, w+2, h+2, 4);
    }
    // Value
    fill(COL_TEXT);
    textAlign(LEFT, CENTER);
    textSize(14);
    String display = value + (focused && (frameCount % 40 < 20) ? "|" : "") + " " + suffix;
    text(display, x + 6, y + h/2);
  }

  boolean clicked() { return hovered; }

  void handleKey(char k, int kCode) {
    if (!focused) return;
    if (k == BACKSPACE || k == DELETE) {
      if (value.length() > 0) value = value.substring(0, value.length()-1);
    } else if ((k >= '0' && k <= '9') || k == '.') {
      if (k == '.' && value.indexOf('.') >= 0) return;
      if (value.length() < 8) value += k;
    }
  }

  float getFloat() {
    try { return Float.parseFloat(value); }
    catch (Exception e) { return 0; }
  }

  void setFloat(float v) {
    value = nf(v, 0, 3);
  }
}

// ============================================================
// SLIDER — enhanced with value display
// ============================================================
class Slider {
  float x, y, w, h;
  float minVal = 0, maxVal = 20;
  float value = 10;
  String label = "";
  boolean dragging = false;
  boolean hovered = false;

  Slider(float x, float y, float w, float h, String label, float minVal, float maxVal) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    this.label = label;
    this.minVal = minVal; this.maxVal = maxVal;
  }

  void draw() {
    float knobX = map(value, minVal, maxVal, x, x + w);
    hovered = mouseX >= x-5 && mouseX <= x+w+5 && mouseY >= y-10 && mouseY <= y+h+10;
    // Label
    fill(COL_TEXT_DIM);
    textAlign(LEFT, BOTTOM);
    textSize(10);
    text(label, x, y - 6);
    // Value
    fill(COL_TEXT);
    textAlign(RIGHT, BOTTOM);
    text(nf(value, 0, 0), x + w, y - 6);
    // Track background
    fill(#1A1A25);
    stroke(COL_BORDER);
    strokeWeight(1);
    rect(x, y + h/2 - 4, w, 8, 4);
    // Filled portion
    noStroke();
    fill(COL_ACCENT);
    rect(x+1, y + h/2 - 3, knobX - x, 6, 3);
    // Knob
    fill(COL_TEXT);
    stroke(COL_ACCENT);
    strokeWeight(2);
    ellipse(knobX, y + h/2, 16, 16);

    if (dragging) {
      value = constrain(map(mouseX, x, x + w, minVal, maxVal), minVal, maxVal);
      value = round(value);
    }
  }

  boolean pressedOn() { return hovered; }
}

// ============================================================
// STATUS BADGE — mode indicator
// ============================================================
class StatusBadge {
  float x, y, w, h;
  String label;
  color activeColor;
  boolean active = false;

  StatusBadge(float x, float y, float w, float h, String label, color activeColor) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    this.label = label;
    this.activeColor = activeColor;
  }

  void draw() {
    // Glow
    if (active) {
      fill(activeColor, 20);
      noStroke();
      rect(x-2, y-2, w+4, h+4, 6);
    }
    fill(active ? activeColor : #2A2A35);
    stroke(active ? activeColor : COL_BORDER);
    strokeWeight(1);
    rect(x, y, w, h, 4);
    fill(active ? #000000 : #444455);
    textAlign(CENTER, CENTER);
    textSize(12);
    text(label, x + w/2, y + h/2);
  }
}

// ============================================================
// SEVEN-SEGMENT STYLE DISPLAY
// ============================================================
class DigitalReadout {
  float x, y, w, h;
  String value = "0.000";
  String unit = "V";
  String label = "";
  color displayColor;

  DigitalReadout(float x, float y, float w, float h, String unit, String label, color c) {
    this.x = x; this.y = y; this.w = w; this.h = h;
    this.unit = unit; this.label = label; this.displayColor = c;
  }

  void draw() {
    // Recessed display
    fill(#08080F);
    stroke(COL_BORDER, 80);
    strokeWeight(1);
    rect(x, y, w, h, 3);
    // Inner shadow
    fill(#050510);
    noStroke();
    rect(x+2, y+2, w-4, h-4, 2);
    // Label
    fill(displayColor, 120);
    textAlign(LEFT, CENTER);
    textSize(10);
    text(label, x + 6, y + h/2);
    // Value
    fill(displayColor);
    textAlign(RIGHT, CENTER);
    textSize(h * 0.55);
    text(value, x + w - 30, y + h/2);
    // Unit
    fill(displayColor, 160);
    textSize(h * 0.35);
    textAlign(LEFT, CENTER);
    text(unit, x + w - 26, y + h/2);
  }

  void setValue(float v, int intD, int decD) {
    value = nf(v, intD, decD);
  }
}
