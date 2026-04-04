/**
 * @file Widgets.pde
 * @brief Reusable GUI widgets with circular gauges, graphs, and lab instrument styling.
 *
 * Provides the visual building blocks for the DPS-150 control interface:
 * - CircularGauge — analog-style meter with needle and arc
 * - ScrollingGraph — real-time V/A/W strip chart
 * - Panel — titled container with header bar
 * - Button — click-able button with hover state
 * - ToggleButton — large ON/OFF button with LED indicator
 * - TextField — numeric input field with cursor
 * - Slider — draggable slider with value display
 * - StatusBadge — small mode indicator (CV/CC)
 * - DigitalReadout — seven-segment style numeric display
 */

// ============================================================
// Widget base class — shared position, size, and hit-testing
// ============================================================
class Widget {
  float x, y, w, h;
  boolean visible = true;

  Widget(float x, float y, float w, float h) {
    this.x = x; this.y = y; this.w = w; this.h = h;
  }

  boolean hitTest() {
    return mouseX >= x && mouseX <= x+w && mouseY >= y && mouseY <= y+h;
  }

  void draw() {}
}

// ============================================================
// COLOR PALETTE — professional instrument look
// ============================================================

/** @name Color Constants
 *  Dark-theme palette designed for extended lab use.
 *  @{ */
static final color COL_BG           = #1C1C28;  ///< Window background
static final color COL_PANEL        = #232336;  ///< Panel body
static final color COL_PANEL_HEADER = #2A2A44;  ///< Panel header bar
static final color COL_PANEL_LITE   = #2E2E4A;  ///< Lighter panel variant
static final color COL_BORDER       = #3A3A5C;  ///< Border / separator
static final color COL_ACCENT       = #4A90D9;  ///< Primary accent (blue)
static final color COL_ACCENT_LITE  = #6BB0FF;  ///< Light accent
static final color COL_TEXT         = #E0E0E8;  ///< Primary text
static final color COL_TEXT_DIM     = #888899;  ///< Secondary / label text
static final color COL_DIM          = #555566;  ///< Dim elements
static final color COL_VOLT         = #FFD54F;  ///< Voltage color (warm amber)
static final color COL_VOLT_DIM     = #664D00;  ///< Voltage dim
static final color COL_CURR         = #4DD0E1;  ///< Current color (teal cyan)
static final color COL_CURR_DIM     = #005662;  ///< Current dim
static final color COL_POWER        = #81C784;  ///< Power color (soft green)
static final color COL_POWER_DIM    = #1B5E20;  ///< Power dim
static final color COL_ON           = #00E676;  ///< Output-ON indicator
static final color COL_OFF          = #FF5252;  ///< Output-OFF / alarm
static final color COL_WARN         = #FF9800;  ///< Warning indicator
static final color COL_BTN          = #2E3B55;  ///< Button normal
static final color COL_BTN_HOVER    = #3D5070;  ///< Button hover
static final color COL_BTN_ACTIVE   = #4A6590;  ///< Button active / pressed
static final color COL_INPUT_BG     = #171722;  ///< Text field background
static final color COL_INPUT_BORDER = #3A3A5C;  ///< Text field border
static final color COL_GRAPH_BG     = #14141E;  ///< Graph background
static final color COL_GRID         = #252538;  ///< Graph grid lines
/** @} */

// ============================================================
/**
 * @class CircularGauge
 * @brief Analog-style circular gauge with needle, arc, ticks, and digital readout.
 *
 * Draws a 270° arc gauge centered at (cx, cy) with configurable range,
 * colors, and tick marks.  The current value is shown both as a needle
 * deflection and a centered digital number.
 */
// ============================================================
class CircularGauge {
  float cx, cy, radius;       ///< Center coordinates and radius
  float minVal, maxVal;        ///< Value range
  float value = 0;             ///< Current display value
  String label, unit;          ///< Label text and unit suffix
  color gaugeColor, gaugeDim;  ///< Active and dim arc colors
  int majorTicks, minorTicks;  ///< Tick subdivision counts
  float startAngle = PI * 0.75;  ///< Arc start angle (135°, lower-left)
  float sweepAngle = PI * 1.5;   ///< Arc sweep (270°)

  /**
   * @param cx         Center X
   * @param cy         Center Y
   * @param radius     Gauge radius in pixels
   * @param label      Bottom label text
   * @param unit       Value unit suffix ("V", "A", etc.)
   * @param minVal     Minimum scale value
   * @param maxVal     Maximum scale value
   * @param gaugeColor Active arc and needle color
   * @param gaugeDim   Dim / background arc color
   */
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

  /** Draw the gauge at its configured position. */
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

    // Glow effect
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
    stroke(0, 60);
    strokeWeight(3);
    line(2, 2, nx+2, ny+2);
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
/**
 * @class ScrollingGraph
 * @brief Real-time scrolling strip chart for voltage, current, and power.
 *
 * Reads sample data from the global @c psu instance's history ring-buffers
 * and plots up to three traces (V, A, W) with independent Y-axis scales.
 * Supports mouse-wheel zoom.
 */
// ============================================================
class ScrollingGraph extends Widget {
  String title;                   ///< Title text shown in header bar
  boolean showVoltage = true;     ///< Show voltage trace
  boolean showCurrent = true;     ///< Show current trace
  boolean showPower = false;      ///< Show power trace
  float voltScale = 30.0;        ///< Voltage Y-axis maximum
  float currScale = 5.0;         ///< Current Y-axis maximum
  float powerScale = 150.0;      ///< Power Y-axis maximum

  /**
   * @param x X position
   * @param y Y position
   * @param w Width
   * @param h Height
   */
  ScrollingGraph(float x, float y, float w, float h) {
    super(x, y, w, h);
    this.title = "Waveform";
  }

  /** Draw the graph and all enabled traces. */
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

    // Y-axis labels
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
    float totalTimeSec = psu.historyCount * psu.pollInterval / 1000.0;
    for (int i = 0; i <= 4; i++) {
      float xx = gx + gw * i / 4.0;
      float tLabel = -totalTimeSec + totalTimeSec * ((float)i / 4.0);
      text(nf(tLabel, 0, 0) + "s", xx, gy + gh + 2);
    }

    // Plot data
    if (psu.historyCount > 1) {
      noFill();
      int start = (psu.historyIndex - psu.historyCount + psu.GRAPH_HISTORY) % psu.GRAPH_HISTORY;

      if (showVoltage) {
        stroke(COL_VOLT);
        strokeWeight(1.5);
        beginShape();
        for (int i = 0; i < psu.historyCount; i++) {
          int idx = (start + i) % psu.GRAPH_HISTORY;
          float px = gx + gw * ((float)i / (psu.GRAPH_HISTORY - 1));
          float py = gy + gh * (1.0 - psu.historyV[idx] / voltScale);
          vertex(px, constrain(py, gy, gy+gh));
        }
        endShape();
      }

      if (showCurrent) {
        stroke(COL_CURR);
        strokeWeight(1.5);
        beginShape();
        for (int i = 0; i < psu.historyCount; i++) {
          int idx = (start + i) % psu.GRAPH_HISTORY;
          float px = gx + gw * ((float)i / (psu.GRAPH_HISTORY - 1));
          float py = gy + gh * (1.0 - psu.historyA[idx] / currScale);
          vertex(px, constrain(py, gy, gy+gh));
        }
        endShape();
      }

      if (showPower) {
        stroke(COL_POWER);
        strokeWeight(1.0);
        beginShape();
        for (int i = 0; i < psu.historyCount; i++) {
          int idx = (start + i) % psu.GRAPH_HISTORY;
          float px = gx + gw * ((float)i / (psu.GRAPH_HISTORY - 1));
          float py = gy + gh * (1.0 - psu.historyW[idx] / powerScale);
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
/**
 * @class Panel
 * @brief Titled panel container with a header bar.
 */
// ============================================================
class Panel extends Widget {
  String title;        ///< Header title text

  /**
   * @param x     X position
   * @param y     Y position
   * @param w     Width
   * @param h     Height
   * @param title Header text
   */
  Panel(float x, float y, float w, float h, String title) {
    super(x, y, w, h);
    this.title = title;
  }

  /** Draw the panel with shadow, body, header bar, and title. */
  void draw() {
    fill(0, 30);
    noStroke();
    rect(x+2, y+2, w, h, 5);
    fill(COL_PANEL);
    stroke(COL_BORDER);
    strokeWeight(1);
    rect(x, y, w, h, 5);
    fill(COL_PANEL_HEADER);
    noStroke();
    rect(x+1, y+1, w-2, 24, 4, 4, 0, 0);
    fill(COL_TEXT);
    textAlign(LEFT, CENTER);
    textSize(11);
    text(title, x + 10, y + 13);
  }

  float contentX() { return x + 8; }   ///< Left edge of content area
  float contentY() { return y + 30; }  ///< Top edge of content area
  float contentW() { return w - 16; }  ///< Content area width
  float contentH() { return h - 36; }  ///< Content area height
}

// ============================================================
/**
 * @class Button
 * @brief Clickable button with hover highlight and optional rounding.
 */
// ============================================================
class Button extends Widget {
  String label;                     ///< Button label text
  color bgColor, hoverColor, textColor; ///< Color scheme
  boolean hovered = false;          ///< True while mouse is over the button
  boolean enabled = true;           ///< Disabled buttons are grayed out and unclickable
  boolean rounded = false;          ///< Use pill-shaped corners

  /**
   * @param x     X position
   * @param y     Y position
   * @param w     Width
   * @param h     Height
   * @param label Button text
   */
  Button(float x, float y, float w, float h, String label) {
    super(x, y, w, h);
    this.label = label;
    this.bgColor = COL_BTN;
    this.hoverColor = COL_BTN_HOVER;
    this.textColor = COL_TEXT;
  }

  /** Draw the button with shadow, body, highlight, and label. */
  void draw() {
    hovered = enabled && hitTest();
    fill(0, 25);
    noStroke();
    rect(x+1, y+1, w, h, rounded ? h/2 : 4);
    fill(enabled ? (hovered ? hoverColor : bgColor) : #2A2A35);
    stroke(enabled ? COL_BORDER : #333340);
    strokeWeight(1);
    rect(x, y, w, h, rounded ? h/2 : 4);
    if (enabled && hovered) {
      stroke(COL_ACCENT_LITE, 40);
      line(x+2, y+1, x+w-2, y+1);
    }
    fill(enabled ? textColor : #555560);
    textAlign(CENTER, CENTER);
    textSize(constrain(h * 0.42, 9, 14));
    text(label, x + w/2, y + h/2);
  }

  /** @return True if the button is enabled and the mouse is over it. */
  boolean clicked() {
    return enabled && hitTest();
  }
}

// ============================================================
/**
 * @class ToggleButton
 * @brief Large ON/OFF toggle button with LED glow indicator.
 *
 * Used for the main output enable/disable control.
 */
// ============================================================
class ToggleButton extends Widget {
  boolean state = false;   ///< Current ON/OFF state
  boolean hovered = false; ///< Mouse hover state

  /**
   * @param x X position
   * @param y Y position
   * @param w Width
   * @param h Height
   */
  ToggleButton(float x, float y, float w, float h) {
    super(x, y, w, h);
  }

  /** Draw the toggle button with LED indicator and label. */
  void draw() {
    hovered = hitTest();

    if (state) {
      fill(COL_ON, 15);
      noStroke();
      rect(x-4, y-4, w+8, h+8, 12);
    }

    fill(state ? #1B4332 : #3E1A1A);
    stroke(state ? COL_ON : COL_OFF);
    strokeWeight(2);
    rect(x, y, w, h, 8);

    float ledX = x + w/2;
    float ledY = y + 14;
    fill(state ? COL_ON : #441111);
    noStroke();
    ellipse(ledX, ledY, 10, 10);
    if (state) {
      fill(COL_ON, 40);
      ellipse(ledX, ledY, 20, 20);
    }

    fill(state ? COL_ON : COL_OFF);
    textAlign(CENTER, CENTER);
    textSize(18);
    text(state ? "OUTPUT ON" : "OUTPUT OFF", x + w/2, y + h/2 + 4);
  }

  /** @return True if the mouse is over this button. */
  boolean clicked() {
    return hitTest();
  }
}

// ============================================================
/**
 * @class TextField
 * @brief Numeric text input field with label, suffix, and blinking cursor.
 */
// ============================================================
class TextField extends Widget {
  String value = "";        ///< Current text value
  String label = "";        ///< Label displayed above the field
  String suffix = "";       ///< Unit suffix displayed after the value
  boolean focused = false;  ///< True when the field has keyboard focus
  boolean hovered = false;  ///< Mouse hover state
  float minVal = 0;         ///< Minimum allowed float value
  float maxVal = 100;       ///< Maximum allowed float value

  /**
   * @param x      X position
   * @param y      Y position
   * @param w      Width
   * @param h      Height
   * @param label  Label text
   * @param suffix Unit suffix ("V", "A", etc.)
   */
  TextField(float x, float y, float w, float h, String label, String suffix) {
    super(x, y, w, h);
    this.label = label;
    this.suffix = suffix;
  }

  /** Draw the text field with label, input box, cursor, and value. */
  void draw() {
    hovered = hitTest();
    fill(COL_TEXT_DIM);
    textAlign(LEFT, BOTTOM);
    textSize(10);
    text(label, x, y - 3);
    fill(COL_INPUT_BG);
    stroke(focused ? COL_ACCENT : COL_INPUT_BORDER);
    strokeWeight(focused ? 1.5 : 1);
    rect(x, y, w, h, 3);
    if (focused) {
      noFill();
      stroke(COL_ACCENT, 30);
      strokeWeight(3);
      rect(x-1, y-1, w+2, h+2, 4);
    }
    fill(COL_TEXT);
    textAlign(LEFT, CENTER);
    textSize(14);
    String display = value + (focused && (frameCount % 40 < 20) ? "|" : "") + " " + suffix;
    text(display, x + 6, y + h/2);
  }

  /** @return True if the mouse is over this field. */
  boolean clicked() {
    return hitTest();
  }

  /**
   * Process a key press while this field is focused.
   * Accepts digits and one decimal point.
   * @param k     Character typed
   * @param kCode Key code
   */
  void handleKey(char k, int kCode) {
    if (!focused) return;
    if (k == BACKSPACE || k == DELETE) {
      if (value.length() > 0) value = value.substring(0, value.length()-1);
    } else if ((k >= '0' && k <= '9') || k == '.') {
      if (k == '.' && value.indexOf('.') >= 0) return;
      if (value.length() < 8) value += k;
    }
  }

  /** @return Parsed float value, or 0 on parse error. */
  float getFloat() {
    try { return Float.parseFloat(value); }
    catch (Exception e) { return 0; }
  }

  /**
   * Set the field text from a float value (3 decimal places).
   * @param v Value to display
   */
  void setFloat(float v) {
    value = nf(v, 0, 3);
  }
}

// ============================================================
/**
 * @class Slider
 * @brief Horizontal slider with label, value readout, and draggable knob.
 */
// ============================================================
class Slider extends Widget {
  float minVal = 0;         ///< Minimum value
  float maxVal = 20;        ///< Maximum value
  float value = 10;         ///< Current value
  String label = "";        ///< Label text
  boolean dragging = false; ///< True while the user is dragging the knob
  boolean hovered = false;  ///< Mouse hover state

  /**
   * @param x      X position
   * @param y      Y position
   * @param w      Width
   * @param h      Height
   * @param label  Label text
   * @param minVal Minimum value
   * @param maxVal Maximum value
   */
  Slider(float x, float y, float w, float h, String label, float minVal, float maxVal) {
    super(x, y, w, h);
    this.label = label;
    this.minVal = minVal; this.maxVal = maxVal;
  }

  /** Draw the slider track, filled portion, knob, label, and value. */
  void draw() {
    float knobX = map(value, minVal, maxVal, x, x + w);
    hovered = mouseX >= x-5 && mouseX <= x+w+5 && mouseY >= y-10 && mouseY <= y+h+10;
    fill(COL_TEXT_DIM);
    textAlign(LEFT, BOTTOM);
    textSize(10);
    text(label, x, y - 6);
    fill(COL_TEXT);
    textAlign(RIGHT, BOTTOM);
    text(nf(value, 0, 0), x + w, y - 6);
    fill(#1A1A25);
    stroke(COL_BORDER);
    strokeWeight(1);
    rect(x, y + h/2 - 4, w, 8, 4);
    noStroke();
    fill(COL_ACCENT);
    rect(x+1, y + h/2 - 3, knobX - x, 6, 3);
    fill(COL_TEXT);
    stroke(COL_ACCENT);
    strokeWeight(2);
    ellipse(knobX, y + h/2, 16, 16);

    if (dragging) {
      value = constrain(map(mouseX, x, x + w, minVal, maxVal), minVal, maxVal);
      value = round(value);
    }
  }

  /** @return True if the mouse is over the slider area. */
  boolean pressedOn() {
    return mouseX >= x-5 && mouseX <= x+w+5 && mouseY >= y-10 && mouseY <= y+h+10;
  }
}

// ============================================================
/**
 * @class StatusBadge
 * @brief Small mode indicator badge (e.g. "CV", "CC").
 *
 * When active, displays a glow effect and the active color.
 */
// ============================================================
class StatusBadge extends Widget {
  String label;            ///< Badge text
  color activeColor;       ///< Color when active
  boolean active = false;  ///< Active state

  /**
   * @param x           X position
   * @param y           Y position
   * @param w           Width
   * @param h           Height
   * @param label       Badge text
   * @param activeColor Color when active
   */
  StatusBadge(float x, float y, float w, float h, String label, color activeColor) {
    super(x, y, w, h);
    this.label = label;
    this.activeColor = activeColor;
  }

  /** Draw the badge with optional glow. */
  void draw() {
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
/**
 * @class DigitalReadout
 * @brief Seven-segment style recessed numeric display.
 *
 * Displays a value with a unit suffix and a label, styled to
 * resemble a backlit LCD panel on lab equipment.
 */
// ============================================================
class DigitalReadout extends Widget {
  String value = "0.000";  ///< Display string
  String unit = "V";       ///< Unit suffix
  String label = "";       ///< Left-side label
  color displayColor;      ///< Text and accent color

  /**
   * @param x X position
   * @param y Y position
   * @param w Width
   * @param h Height
   * @param unit  Unit suffix ("V", "A", "W")
   * @param label Left label text
   * @param c     Display color
   */
  DigitalReadout(float x, float y, float w, float h, String unit, String label, color c) {
    super(x, y, w, h);
    this.unit = unit; this.label = label; this.displayColor = c;
  }

  /** Draw the recessed display panel with label, value, and unit. */
  void draw() {
    fill(#08080F);
    stroke(COL_BORDER, 80);
    strokeWeight(1);
    rect(x, y, w, h, 3);
    fill(#050510);
    noStroke();
    rect(x+2, y+2, w-4, h-4, 2);
    fill(displayColor, 120);
    textAlign(LEFT, CENTER);
    textSize(10);
    text(label, x + 6, y + h/2);
    fill(displayColor);
    textAlign(RIGHT, CENTER);
    textSize(h * 0.55);
    text(value, x + w - 30, y + h/2);
    fill(displayColor, 160);
    textSize(h * 0.35);
    textAlign(LEFT, CENTER);
    text(unit, x + w - 26, y + h/2);
  }

  /**
   * Update the displayed value.
   * @param v    Float value
   * @param intD Integer digits
   * @param decD Decimal digits
   */
  void setValue(float v, int intD, int decD) {
    value = nf(v, intD, decD);
  }
}
