/**
 * @file Widgets.pde
 * @brief Reusable display-only GUI widgets for the DPS-150 control interface.
 *
 * - CircularGauge — analog-style meter with needle and arc
 * - ScrollingGraph — real-time V/A/W strip chart
 * - Panel — titled container with header bar
 * - AdvButton — clickable button (used only in Advanced.pde overlay)
 * - StatusBadge — small mode indicator (CV/CC)
 * - DigitalReadout — seven-segment style numeric display
 * - VerticalBar — vertical bar indicator for Vmax/Imax
 *
 * @author  Peter Vancorenland
 * @copyright 2026 Peter Vancorenland. All rights reserved.
 *
 * Redistribution and use of this source code, with or without modification,
 * is permitted provided that the original author is credited.
 */

// ============================================================
/**
 * @class Widget
 * @brief Abstract base class for all custom widgets.
 *
 * Provides position/size storage and a basic rectangular hit-test.
 * Subclasses override draw() to render themselves.
 */
// ============================================================
class Widget {
  float x, y, w, h;

  /**
   * Construct a widget with the given bounding rectangle.
   * @param x Horizontal position (left edge, in pixels)
   * @param y Vertical position (top edge, in pixels)
   * @param w Width in pixels
   * @param h Height in pixels
   */
  Widget(float x, float y, float w, float h) {
    this.x = x; this.y = y; this.w = w; this.h = h;
  }

  /** @brief Test if the mouse cursor is within this widget's bounds. */
  boolean hitTest() {
    return mouseX >= x && mouseX <= x+w && mouseY >= y && mouseY <= y+h;
  }

  /** @brief Draw the widget (no-op in base class, override in subclasses). */
  void draw() {}
}

// ============================================================
// COLOR PALETTE
// ============================================================

/** @name Color Palette
 *  UI color constants used across all widgets and tabs.
 *  @{ */
static final color COL_BG           = #1C1C28;  ///< Main window background
static final color COL_PANEL        = #232336;  ///< Panel body fill
static final color COL_PANEL_HEADER = #2A2A44;  ///< Panel header bar fill
static final color COL_PANEL_LITE   = #2E2E4A;  ///< Lighter panel variant
static final color COL_BORDER       = #3A3A5C;  ///< General border / outline color
static final color COL_ACCENT       = #4A90D9;  ///< Primary accent (selection, focus)
static final color COL_ACCENT_LITE  = #6BB0FF;  ///< Light accent highlight
static final color COL_TEXT         = #E0E0E8;  ///< Primary text color
static final color COL_TEXT_DIM     = #888899;  ///< Dimmed / secondary text
static final color COL_DIM          = #555566;  ///< Subtle UI elements (minor ticks, dividers)
static final color COL_VOLT         = #FFD54F;  ///< Voltage trace / gauge color
static final color COL_VOLT_DIM     = #664D00;  ///< Voltage dimmed arc background
static final color COL_CURR         = #4DD0E1;  ///< Current trace / gauge color
static final color COL_CURR_DIM     = #005662;  ///< Current dimmed arc background
static final color COL_POWER        = #81C784;  ///< Power trace color
static final color COL_POWER_DIM    = #1B5E20;  ///< Power dimmed background
static final color COL_ON           = #00E676;  ///< Output-ON indicator
static final color COL_OFF          = #FF5252;  ///< Output-OFF indicator
static final color COL_WARN         = #FF9800;  ///< Warning / protection alert
static final color COL_BTN          = #2E3B55;  ///< Button default background
static final color COL_BTN_HOVER    = #3D5070;  ///< Button hovered background
static final color COL_BTN_ACTIVE   = #4A6590;  ///< Button active / pressed background
static final color COL_INPUT_BG     = #171722;  ///< Text input field background
static final color COL_INPUT_BORDER = #3A3A5C;  ///< Text input field border
static final color COL_GRAPH_BG     = #14141E;  ///< Scrolling graph background
static final color COL_GRID         = #252538;  ///< Graph grid lines
/** @} */

// ============================================================
/**
 * @class CircularGauge
 * @brief Analog-style circular gauge with needle, arc, tick marks, and digital readout.
 *
 * Renders a 270-degree sweep arc with major/minor tick marks, a needle
 * that tracks the current value, and a centered digital readout showing
 * the numeric value, unit, and label.
 */
// ============================================================
class CircularGauge {
  float cx, cy, radius;
  float minVal, maxVal;
  float value = 0;
  String label, unit;
  color gaugeColor, gaugeDim;
  int majorTicks, minorTicks;
  float startAngle = PI * 0.75;
  float sweepAngle = PI * 1.5;

  /**
   * Construct a circular gauge.
   * @param cx         Center X coordinate (pixels)
   * @param cy         Center Y coordinate (pixels)
   * @param radius     Outer radius of the gauge (pixels)
   * @param label      Display name shown below the readout (e.g. "Voltage")
   * @param unit       Display unit shown below the value (e.g. "V")
   * @param minVal     Minimum value of the gauge range
   * @param maxVal     Maximum value of the gauge range
   * @param gaugeColor Primary arc and needle color
   * @param gaugeDim   Dimmed arc background color
   */
  CircularGauge(float cx, float cy, float radius, String label, String unit,
                float minVal, float maxVal, color gaugeColor, color gaugeDim) {
    this.cx = cx; this.cy = cy; this.radius = radius;
    this.label = label; this.unit = unit;
    this.minVal = minVal; this.maxVal = maxVal;
    this.gaugeColor = gaugeColor; this.gaugeDim = gaugeDim;
    this.majorTicks = 6; this.minorTicks = 5;
  }

  /** @brief Draw the gauge: bezel, arc, ticks, needle, and digital readout. */
  void draw() {
    pushMatrix();
    translate(cx, cy);
    float endAngle = startAngle + sweepAngle;

    // Outer ring shadow + bezel
    noFill();
    stroke(0, 40); strokeWeight(3);
    arc(0, 0, radius*2+6, radius*2+6, startAngle, endAngle);
    stroke(COL_BORDER); strokeWeight(2);
    arc(0, 0, radius*2+2, radius*2+2, startAngle, endAngle);

    // Background arc
    float arcD = radius * 1.7;
    stroke(gaugeDim, 60); strokeWeight(10);
    arc(0, 0, arcD, arcD, startAngle, endAngle);

    // Value arc + glow
    float fraction = constrain((value - minVal) / (maxVal - minVal), 0, 1);
    float valueAngle = startAngle + sweepAngle * fraction;
    stroke(gaugeColor); strokeWeight(10);
    arc(0, 0, arcD, arcD, startAngle, valueAngle);
    stroke(gaugeColor, 40); strokeWeight(18);
    arc(0, 0, arcD, arcD, startAngle, valueAngle);

    // Tick marks
    float innerR = radius * 0.78, outerR = radius * 0.9, labelR = radius * 0.65;
    int decPlaces = (maxVal <= 10) ? 1 : 0;
    for (int i = 0; i <= majorTicks; i++) {
      float frac = (float)i / majorTicks;
      float tickAngle = startAngle + sweepAngle * frac;
      float cosA = cos(tickAngle), sinA = sin(tickAngle);

      stroke(COL_TEXT_DIM); strokeWeight(1.5);
      line(cosA * innerR, sinA * innerR, cosA * outerR, sinA * outerR);

      fill(COL_TEXT_DIM); noStroke();
      textAlign(CENTER, CENTER); textSize(9);
      text(nf(minVal + (maxVal - minVal) * frac, 0, decPlaces), cosA * labelR, sinA * labelR);

      // Minor ticks
      if (i < majorTicks) {
        float minorStep = sweepAngle / majorTicks / minorTicks;
        float minInR = radius * 0.83, minOutR = radius * 0.88;
        stroke(COL_DIM, 120); strokeWeight(0.8);
        for (int j = 1; j < minorTicks; j++) {
          float ma = tickAngle + minorStep * j;
          line(cos(ma) * minInR, sin(ma) * minInR, cos(ma) * minOutR, sin(ma) * minOutR);
        }
      }
    }

    // Needle
    float needleAngle = startAngle + sweepAngle * fraction;
    float needleLen = radius * 0.72;
    float nx = cos(needleAngle) * needleLen, ny = sin(needleAngle) * needleLen;
    stroke(0, 60); strokeWeight(3);
    line(2, 2, nx+2, ny+2);
    stroke(gaugeColor); strokeWeight(2.5);
    line(0, 0, nx, ny);
    fill(COL_PANEL_HEADER); stroke(gaugeColor); strokeWeight(1.5);
    ellipse(0, 0, 12, 12);

    // Digital readout
    noStroke(); textAlign(CENTER, CENTER);
    fill(gaugeColor);
    textSize(radius * 0.32);
    text(nf(value, 0, (maxVal <= 10) ? 3 : 2), 0, radius * 0.28);
    fill(gaugeColor, 180); textSize(radius * 0.16);
    text(unit, 0, radius * 0.48);
    fill(COL_TEXT_DIM); textSize(radius * 0.13);
    text(label, 0, radius * 0.63);

    popMatrix();
  }
}

// ============================================================
/**
 * @class ScrollingGraph
 * @brief Real-time scrolling strip chart for voltage, current, and power traces.
 *
 * Draws a titled graph area with grid, Y-axis scale labels, time-axis
 * labels, a color-coded legend, and up to three data traces pulled from
 * the global @c psu history ring-buffers.
 */
// ============================================================
class ScrollingGraph extends Widget {
  String title = "Waveform";
  boolean showVoltage = true, showCurrent = true, showPower = false;
  float voltScale = 30.0, currScale = 5.0, powerScale = 150.0;

  /**
   * Construct a scrolling graph widget.
   * @param x Left edge position (pixels)
   * @param y Top edge position (pixels)
   * @param w Width in pixels
   * @param h Height in pixels
   */
  ScrollingGraph(float x, float y, float w, float h) {
    super(x, y, w, h);
  }

  /** @brief Draw the graph background, grid, legend, traces, and border. */
  void draw() {
    fill(COL_GRAPH_BG); stroke(COL_BORDER); strokeWeight(1);
    rect(x, y, w, h, 4);

    // Title bar
    fill(COL_PANEL_HEADER); noStroke();
    rect(x+1, y+1, w-2, 22, 3, 3, 0, 0);
    fill(COL_TEXT); textAlign(LEFT, CENTER); textSize(11);
    text(title, x + 8, y + 12);

    // Legend
    float lx = x + w - 200, ly = y + 12;
    textSize(9);
    if (showVoltage) { drawLegendItem(lx, ly, COL_VOLT, "Voltage"); lx += 55; }
    if (showCurrent) { drawLegendItem(lx, ly, COL_CURR, "Current"); lx += 55; }
    if (showPower)   { drawLegendItem(lx, ly, COL_POWER, "Power"); }

    float gx = x + 45, gy = y + 28, gw = w - 55, gh = h - 38;

    // Grid
    stroke(COL_GRID); strokeWeight(0.5);
    for (int i = 0; i <= 5; i++) { float yy = gy + gh * i / 5.0; line(gx, yy, gx + gw, yy); }
    for (int i = 0; i <= 10; i++) { float xx = gx + gw * i / 10.0; line(xx, gy, xx, gy + gh); }

    // Y-axis labels
    fill(COL_TEXT_DIM); textSize(8); textAlign(RIGHT, CENTER);
    for (int i = 0; i <= 5; i++) {
      float yy = gy + gh * i / 5.0;
      text(nf(voltScale * (1.0 - (float)i/5.0), 0, 0), gx - 4, yy);
    }

    // X-axis time labels
    textAlign(CENTER, TOP);
    float totalTimeSec = psu.historyCount * psu.pollInterval / 1000.0;
    for (int i = 0; i <= 4; i++) {
      float xx = gx + gw * i / 4.0;
      text(nf(-totalTimeSec + totalTimeSec * ((float)i / 4.0), 0, 0) + "s", xx, gy + gh + 2);
    }

    // Plot traces
    if (psu.historyCount > 1) {
      int start = (psu.historyIndex - psu.historyCount + psu.GRAPH_HISTORY) % psu.GRAPH_HISTORY;
      float xScale = gw / (float)(psu.GRAPH_HISTORY - 1);
      if (showVoltage) drawTrace(gx, gy, gw, gh, xScale, start, psu.historyV, voltScale, COL_VOLT, 1.5);
      if (showCurrent) drawTrace(gx, gy, gw, gh, xScale, start, psu.historyA, currScale, COL_CURR, 1.5);
      if (showPower)   drawTrace(gx, gy, gw, gh, xScale, start, psu.historyW, powerScale, COL_POWER, 1.0);
    }

    // Border
    noFill(); stroke(COL_BORDER); strokeWeight(1);
    rect(gx, gy, gw, gh);
  }

  /**
   * @brief Draw a single legend entry with color swatch and label.
   * @param lx    Left edge of the swatch
   * @param ly    Vertical center of the entry
   * @param c     Swatch color
   * @param label Text label
   */
  void drawLegendItem(float lx, float ly, color c, String label) {
    fill(c); noStroke(); rect(lx, ly-4, 8, 8);
    fill(COL_TEXT_DIM); textAlign(LEFT, CENTER);
    text(label, lx+12, ly);
  }

  /**
   * @brief Plot one data trace as a connected line within the graph area.
   * @param gx     Graph area left edge
   * @param gy     Graph area top edge
   * @param gw     Graph area width
   * @param gh     Graph area height
   * @param xScale Horizontal pixels per sample
   * @param start  Ring-buffer start index
   * @param data   Sample data array (ring-buffer)
   * @param scale  Y-axis full-scale value
   * @param c      Trace color
   * @param sw     Stroke weight
   */
  void drawTrace(float gx, float gy, float gw, float gh, float xScale, int start, float[] data, float scale, color c, float sw) {
    noFill(); stroke(c); strokeWeight(sw);
    beginShape();
    for (int i = 0; i < psu.historyCount; i++) {
      int idx = (start + i) % psu.GRAPH_HISTORY;
      vertex(gx + xScale * i, constrain(gy + gh * (1.0 - data[idx] / scale), gy, gy+gh));
    }
    endShape();
  }
}

// ============================================================
/**
 * @class Panel
 * @brief Titled container panel with header bar and content area.
 *
 * Draws a rounded rectangle with a colored header strip containing the
 * title text.  Helper methods return the usable content region inside
 * the panel's padding.
 */
// ============================================================
class Panel extends Widget {
  String title;

  /**
   * Construct a panel.
   * @param x     Left edge position (pixels)
   * @param y     Top edge position (pixels)
   * @param w     Width in pixels
   * @param h     Height in pixels
   * @param title Header text displayed in the title bar
   */
  Panel(float x, float y, float w, float h, String title) {
    super(x, y, w, h);
    this.title = title;
  }

  /** @brief Draw the panel background, header bar, and title text. */
  void draw() {
    fill(0, 30); noStroke();
    rect(x+2, y+2, w, h, 5);
    fill(COL_PANEL); stroke(COL_BORDER); strokeWeight(1);
    rect(x, y, w, h, 5);
    fill(COL_PANEL_HEADER); noStroke();
    rect(x+1, y+1, w-2, 24, 4, 4, 0, 0);
    fill(COL_TEXT); textAlign(LEFT, CENTER); textSize(11);
    text(title, x + 10, y + 13);
  }

  /** @brief Return the content area X position (inside padding). */
  float contentX() { return x + 8; }
  /** @brief Return the content area Y position (inside padding). */
  float contentY() { return y + 30; }
  /** @brief Return the content area width (inside padding). */
  float contentW() { return w - 16; }
  /** @brief Return the content area height (inside padding). */
  float contentH() { return h - 36; }
}

// ============================================================
/**
 * @class AdvButton
 * @brief Clickable button widget used in the Advanced overlay.
 *
 * Renders a rounded button with hover highlight and shadow.
 * Can be disabled to grey out and ignore clicks.
 */
// ============================================================
class AdvButton extends Widget {
  String label;
  color bgColor = COL_BTN, hoverColor = COL_BTN_HOVER, textColor = COL_TEXT;
  boolean enabled = true;

  /**
   * Construct a button.
   * @param x     Left edge position (pixels)
   * @param y     Top edge position (pixels)
   * @param w     Width in pixels
   * @param h     Height in pixels
   * @param label Text displayed on the button face
   */
  AdvButton(float x, float y, float w, float h, String label) {
    super(x, y, w, h);
    this.label = label;
  }

  /** @brief Draw the button with shadow, fill, hover highlight, and label. */
  void draw() {
    boolean hovered = enabled && hitTest();
    float r = 4;
    fill(0, 25); noStroke();
    rect(x+1, y+1, w, h, r);
    fill(enabled ? (hovered ? hoverColor : bgColor) : #2A2A35);
    stroke(enabled ? COL_BORDER : #333340); strokeWeight(1);
    rect(x, y, w, h, r);
    if (hovered) { stroke(COL_ACCENT_LITE, 40); line(x+2, y+1, x+w-2, y+1); }
    fill(enabled ? textColor : #555560);
    textAlign(CENTER, CENTER);
    textSize(constrain(h * 0.42, 9, 14));
    text(label, x + w/2, y + h/2);
  }

  /** @brief Return true if the button is enabled and the mouse is over it. */
  boolean clicked() { return enabled && hitTest(); }
}

// ============================================================
/**
 * @class StatusBadge
 * @brief Small mode indicator badge (e.g. CV/CC).
 *
 * When active, draws a glowing colored rectangle with dark text;
 * when inactive, draws a muted outline with dimmed text.
 */
// ============================================================
class StatusBadge extends Widget {
  String label;
  color activeColor;
  boolean active = false;

  /**
   * Construct a status badge.
   * @param x           Left edge position (pixels)
   * @param y           Top edge position (pixels)
   * @param w           Width in pixels
   * @param h           Height in pixels
   * @param label       Text shown inside the badge (e.g. "CV", "CC")
   * @param activeColor Fill and border color when the badge is active
   */
  StatusBadge(float x, float y, float w, float h, String label, color activeColor) {
    super(x, y, w, h);
    this.label = label; this.activeColor = activeColor;
  }

  /** @brief Draw the badge in its active or inactive state. */
  void draw() {
    if (active) { fill(activeColor, 20); noStroke(); rect(x-2, y-2, w+4, h+4, 6); }
    fill(active ? activeColor : #2A2A35);
    stroke(active ? activeColor : COL_BORDER); strokeWeight(1);
    rect(x, y, w, h, 4);
    fill(active ? #000000 : #444455);
    textAlign(CENTER, CENTER); textSize(12);
    text(label, x + w/2, y + h/2);
  }
}

// ============================================================
/**
 * @class DigitalReadout
 * @brief Seven-segment style numeric display with label and unit.
 *
 * Renders a dark recessed rectangle containing a left-aligned label,
 * a large right-aligned numeric value, and a smaller unit suffix.
 */
// ============================================================
class DigitalReadout extends Widget {
  String value = "0.000", unit = "V", label = "";
  color displayColor;

  /**
   * Construct a digital readout.
   * @param x     Left edge position (pixels)
   * @param y     Top edge position (pixels)
   * @param w     Width in pixels
   * @param h     Height in pixels
   * @param unit  Unit suffix displayed after the value (e.g. "V", "A")
   * @param label Descriptive label shown at the left edge
   * @param c     Display color for the value, unit, and label text
   */
  DigitalReadout(float x, float y, float w, float h, String unit, String label, color c) {
    super(x, y, w, h);
    this.unit = unit; this.label = label; this.displayColor = c;
  }

  /** @brief Draw the recessed background, label, numeric value, and unit. */
  void draw() {
    fill(#08080F); stroke(COL_BORDER, 80); strokeWeight(1);
    rect(x, y, w, h, 3);
    fill(#050510); noStroke();
    rect(x+2, y+2, w-4, h-4, 2);
    fill(displayColor, 120); textAlign(LEFT, CENTER); textSize(10);
    text(label, x + 6, y + h/2);
    fill(displayColor); textAlign(RIGHT, CENTER); textSize(h * 0.55);
    text(value, x + w - 30, y + h/2);
    fill(displayColor, 160); textSize(h * 0.35); textAlign(LEFT, CENTER);
    text(unit, x + w - 26, y + h/2);
  }

  /**
   * @brief Format and store a float value for display.
   * @param v    The float value to format
   * @param intD Number of integer digits (zero-padded)
   * @param decD Number of decimal places
   */
  void setValue(float v, int intD, int decD) { value = nf(v, intD, decD); }
}

// ============================================================
/**
 * @class VerticalBar
 * @brief Vertical bar indicator for displaying a bounded value (e.g. Vmax, Imax).
 *
 * Draws a narrow vertical track with a filled portion proportional to
 * the current value, plus tick marks, a numeric readout at the top,
 * and a label at the bottom.
 */
// ============================================================
class VerticalBar extends Widget {
  float minVal, maxVal, value = 0;
  String label, unit;
  color barColor;

  /**
   * Construct a vertical bar indicator.
   * @param x        Left edge position (pixels)
   * @param y        Top edge position (pixels)
   * @param w        Width in pixels
   * @param h        Height in pixels
   * @param label    Text label shown below the bar
   * @param unit     Unit suffix appended to the numeric readout
   * @param minVal   Minimum value of the range
   * @param maxVal   Maximum value of the range
   * @param barColor Fill color for the active portion of the bar
   */
  VerticalBar(float x, float y, float w, float h, String label, String unit,
              float minVal, float maxVal, color barColor) {
    super(x, y, w, h);
    this.label = label; this.unit = unit;
    this.minVal = minVal; this.maxVal = maxVal; this.barColor = barColor;
  }

  /** @brief Draw the bar track, filled portion, tick marks, value, and label. */
  void draw() {
    float trackX = x + w/2 - 4, trackW = 8;
    float trackY = y + 14, trackH = h - 38;

    fill(barColor); noStroke();
    textAlign(CENTER, BOTTOM); textSize(10);
    text(nf(value, 0, 1) + unit, x + w/2, y + 12);

    fill(#1A1A25); stroke(COL_BORDER); strokeWeight(1);
    rect(trackX, trackY, trackW, trackH, 4);

    float fraction = constrain((value - minVal) / (maxVal - minVal), 0, 1);
    float fillH = trackH * fraction;
    noStroke();
    fill(barColor, 180);
    rect(trackX + 1, trackY + trackH - fillH, trackW - 2, fillH, 3);
    fill(barColor, 40);
    rect(trackX - 2, trackY + trackH - fillH - 2, trackW + 4, fillH + 4, 4);

    stroke(COL_DIM, 120); strokeWeight(0.5);
    for (int i = 0; i <= 4; i++) {
      float ty = trackY + trackH * (1.0 - (float)i / 4.0);
      line(trackX - 3, ty, trackX, ty);
    }

    fill(COL_TEXT_DIM); noStroke();
    textAlign(CENTER, TOP); textSize(8);
    text(label, x + w/2, y + h - 20);
  }
}
