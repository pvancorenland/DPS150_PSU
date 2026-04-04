/**
 * @file Advanced.pde
 * @brief Advanced programmable output window — Sequential Output, Voltage Sweep, Current Sweep.
 *
 * Provides a modal overlay with three modes:
 * - **Sequential Output**: step through a table of V/A/delay rows with looping
 * - **Voltage Sweep**: ramp voltage at a fixed current
 * - **Current Sweep**: ramp current at a fixed voltage
 *
 * Each mode has Start/Pause/Continue/Stop controls and a visual preview.
 * Matches the Fnirsi official PC software Advanced features.
 */

// ============================================================
// ADVANCED MODE STATE
// ============================================================

boolean advancedOpen = false;  ///< True when the advanced overlay is visible

/** @name Mode Selectors
 *  @{ */
int advMode = 0;  ///< Active mode: 0 = Sequential, 1 = V Sweep, 2 = I Sweep
/** @} */

/** @name Execution States
 *  @{ */
static final int ADV_IDLE     = 0;  ///< Not running
static final int ADV_RUNNING  = 1;  ///< Actively executing steps/sweep
static final int ADV_PAUSED   = 2;  ///< Paused mid-execution
int advState = ADV_IDLE;             ///< Current execution state
/** @} */

// ============================================================
// SEQUENTIAL OUTPUT
// ============================================================

static final int SEQ_MAX_ROWS = 10;  ///< Maximum number of sequence rows

float[] seqVoltage = new float[SEQ_MAX_ROWS];   ///< Voltage for each step
float[] seqCurrent = new float[SEQ_MAX_ROWS];   ///< Current for each step
float[] seqDelay   = new float[SEQ_MAX_ROWS];   ///< Delay in seconds for each step
boolean[] seqEnabled = new boolean[SEQ_MAX_ROWS]; ///< Whether each row is enabled
int[] seqStatus = new int[SEQ_MAX_ROWS];         ///< 0=waiting, 1=running, 2=done

int seqLoopCount = 1;       ///< Number of loops (0 = infinite)
int seqCurrentLoop = 0;     ///< Current loop iteration
int seqCurrentStep = -1;    ///< Index of the currently executing step (-1 = none)
long seqStepStartTime = 0;  ///< millis() when the current step started

/** @name Sequential Table Editing State
 *  @{ */
int seqEditRow = -1;        ///< Row being edited (-1 = none)
int seqEditCol = -1;        ///< Column being edited (0=V, 1=A, 2=delay)
String seqEditBuffer = "";  ///< Text buffer for the cell being edited
/** @} */

// ============================================================
// VOLTAGE SWEEP
// ============================================================

float vsFixedCurrent = 1.0;   ///< Fixed current during voltage sweep (A)
float vsStartVoltage = 1.0;   ///< Sweep start voltage (V)
float vsEndVoltage   = 12.0;  ///< Sweep end voltage (V)
float vsStepVoltage  = 0.5;   ///< Voltage step size (V)
float vsDelay        = 2.0;   ///< Delay between steps (seconds)

float vsCurrentValue = 0;     ///< Current sweep voltage value
boolean vsSweepUp = true;     ///< True if sweeping from low to high

int vsEditField = -1;          ///< Field being edited (0-4, -1 = none)
String vsEditBuffer = "";      ///< Text buffer for sweep field editing

// ============================================================
// CURRENT SWEEP
// ============================================================

float csFixedVoltage = 5.0;   ///< Fixed voltage during current sweep (V)
float csStartCurrent = 0.1;   ///< Sweep start current (A)
float csEndCurrent   = 3.0;   ///< Sweep end current (A)
float csStepCurrent  = 0.1;   ///< Current step size (A)
float csDelay        = 2.0;   ///< Delay between steps (seconds)

float csCurrentValue = 0;     ///< Current sweep current value
boolean csSweepUp = true;     ///< True if sweeping from low to high

int csEditField = -1;          ///< Field being edited (0-4, -1 = none)
String csEditBuffer = "";      ///< Text buffer for sweep field editing

// ============================================================
// ADVANCED WINDOW WIDGETS
// ============================================================

/// @name Window Geometry
/// @{
float advX, advY, advW, advH;
/// @}

Button btnAdvClose;
Button btnAdvModeSeq, btnAdvModeVS, btnAdvModeCS;
Button btnAdvStart, btnAdvPause, btnAdvContinue, btnAdvStop;
Button btnAdvSingleStep;
Button btnAdvClearTable;
Button btnLoopUp, btnLoopDown;

/** Initialise the advanced window widgets and default sequence data. */
void initAdvanced() {
  // Window position (centered overlay)
  advW = 780;
  advH = 520;
  advX = (WIN_W - advW) / 2;
  advY = (WIN_H - advH) / 2;

  float bx = advX + advW - 30;
  btnAdvClose = new Button(bx, advY + 5, 24, 20, "X");
  btnAdvClose.bgColor = #7F1D1D;
  btnAdvClose.hoverColor = #B71C1C;

  // Mode tabs
  float tabY = advY + 32;
  btnAdvModeSeq = new Button(advX + 8, tabY, 120, 26, "Sequential");
  btnAdvModeVS  = new Button(advX + 134, tabY, 120, 26, "V Sweep");
  btnAdvModeCS  = new Button(advX + 260, tabY, 120, 26, "I Sweep");

  // Control buttons
  float ctrlY = advY + advH - 45;
  btnAdvStart    = new Button(advX + 10,  ctrlY, 90, 30, "Start");
  btnAdvStart.bgColor = #1B5E20; btnAdvStart.hoverColor = #2E7D32;
  btnAdvPause    = new Button(advX + 108, ctrlY, 90, 30, "Pause");
  btnAdvPause.bgColor = #E65100; btnAdvPause.hoverColor = #FF8F00;
  btnAdvContinue = new Button(advX + 206, ctrlY, 90, 30, "Continue");
  btnAdvContinue.bgColor = #1565C0; btnAdvContinue.hoverColor = #1E88E5;
  btnAdvStop     = new Button(advX + 304, ctrlY, 90, 30, "Stop");
  btnAdvStop.bgColor = #7F1D1D; btnAdvStop.hoverColor = #B71C1C;
  btnAdvSingleStep = new Button(advX + 402, ctrlY, 100, 30, "Single Step");
  btnAdvSingleStep.bgColor = #4A148C; btnAdvSingleStep.hoverColor = #7B1FA2;
  btnAdvClearTable = new Button(advX + 510, ctrlY, 90, 30, "Clear");

  // Loop controls
  btnLoopUp   = new Button(advX + advW - 80, tabY, 24, 12, "+");
  btnLoopDown = new Button(advX + advW - 80, tabY + 14, 24, 12, "-");

  // Initialize sequence rows
  for (int i = 0; i < SEQ_MAX_ROWS; i++) {
    seqVoltage[i] = 5.0;
    seqCurrent[i] = 1.0;
    seqDelay[i]   = 2.0;
    seqEnabled[i] = (i == 0);
    seqStatus[i]  = 0;
  }
}

// ============================================================
// DRAW ADVANCED WINDOW
// ============================================================

/** Draw the advanced overlay window (dim background, window chrome, active mode content). */
void drawAdvanced() {
  if (!advancedOpen) return;

  // Dim overlay
  fill(0, 160);
  noStroke();
  rect(0, 0, WIN_W, WIN_H);

  // Window shadow
  fill(0, 80);
  noStroke();
  rect(advX + 4, advY + 4, advW, advH, 8);

  // Window body
  fill(COL_PANEL);
  stroke(COL_BORDER);
  strokeWeight(2);
  rect(advX, advY, advW, advH, 8);

  // Title bar
  fill(COL_PANEL_HEADER);
  noStroke();
  rect(advX + 2, advY + 2, advW - 4, 28, 6, 6, 0, 0);
  fill(COL_TEXT);
  textAlign(LEFT, CENTER);
  textSize(13);
  text("Advanced — Programmable Output", advX + 12, advY + 16);

  btnAdvClose.draw();

  // Mode tabs
  btnAdvModeSeq.bgColor = (advMode == 0) ? COL_ACCENT : COL_BTN;
  btnAdvModeVS.bgColor  = (advMode == 1) ? COL_ACCENT : COL_BTN;
  btnAdvModeCS.bgColor  = (advMode == 2) ? COL_ACCENT : COL_BTN;
  btnAdvModeSeq.draw();
  btnAdvModeVS.draw();
  btnAdvModeCS.draw();

  // Loop count display
  fill(COL_TEXT_DIM);
  textAlign(RIGHT, CENTER);
  textSize(10);
  text("Loops: " + seqLoopCount + (seqLoopCount == 0 ? " (inf)" : ""), advX + advW - 88, advY + 45);
  btnLoopUp.draw();
  btnLoopDown.draw();

  // Running state indicator
  float stateX = advX + 400;
  float stateY = advY + 45;
  if (advState == ADV_RUNNING) {
    fill(COL_ON);
    float pulse = sin(millis() * 0.01) * 0.3 + 0.7;
    fill(color(0, 230, 118, (int)(255 * pulse)));
    noStroke();
    ellipse(stateX, stateY, 10, 10);
    fill(COL_ON);
    textAlign(LEFT, CENTER);
    textSize(11);
    text("RUNNING", stateX + 10, stateY);

    if (advMode == 0) {
      text("Step " + (seqCurrentStep + 1) + "/" + countEnabledSteps() + "  Loop " + (seqCurrentLoop + 1) + "/" + (seqLoopCount == 0 ? "inf" : str(seqLoopCount)), stateX + 80, stateY);
    } else {
      float cv = (advMode == 1) ? vsCurrentValue : csCurrentValue;
      String unit = (advMode == 1) ? "V" : "A";
      text("Value: " + nf(cv, 0, 3) + " " + unit, stateX + 80, stateY);
    }
  } else if (advState == ADV_PAUSED) {
    fill(COL_WARN);
    noStroke();
    ellipse(stateX, stateY, 10, 10);
    fill(COL_WARN);
    textAlign(LEFT, CENTER);
    textSize(11);
    text("PAUSED", stateX + 10, stateY);
  }

  // Content area
  float contentY = advY + 64;
  float contentH = advH - 64 - 55;

  switch (advMode) {
    case 0: drawSequentialOutput(advX + 8, contentY, advW - 16, contentH); break;
    case 1: drawVoltageSweep(advX + 8, contentY, advW - 16, contentH); break;
    case 2: drawCurrentSweep(advX + 8, contentY, advW - 16, contentH); break;
  }

  // Control buttons
  btnAdvStart.enabled = (advState == ADV_IDLE) && psu.connected;
  btnAdvPause.enabled = (advState == ADV_RUNNING);
  btnAdvContinue.enabled = (advState == ADV_PAUSED);
  btnAdvStop.enabled = (advState != ADV_IDLE);
  btnAdvSingleStep.enabled = (advState == ADV_IDLE || advState == ADV_PAUSED) && psu.connected && advMode == 0;
  btnAdvClearTable.enabled = (advState == ADV_IDLE);

  btnAdvStart.draw();
  btnAdvPause.draw();
  btnAdvContinue.draw();
  btnAdvStop.draw();
  if (advMode == 0) btnAdvSingleStep.draw();
  btnAdvClearTable.draw();
}

// ============================================================
// SEQUENTIAL OUTPUT TABLE
// ============================================================

/**
 * Draw the sequential output table with editable voltage/current/delay cells.
 * @param x X origin
 * @param y Y origin
 * @param w Width
 * @param h Height
 */
void drawSequentialOutput(float x, float y, float w, float h) {
  float[] colX = {x, x+35, x+130, x+250, x+370, x+480, x+580};
  String[] headers = {"En", "No.", "Voltage (V)", "Current (A)", "Delay (s)", "Status", "Progress"};
  float rowH = 32;

  // Header row
  fill(COL_PANEL_HEADER);
  noStroke();
  rect(x, y, w, 24, 3, 3, 0, 0);

  fill(COL_TEXT);
  textAlign(LEFT, CENTER);
  textSize(10);
  for (int c = 0; c < headers.length; c++) {
    text(headers[c], colX[c] + 4, y + 12);
  }

  // Data rows
  for (int i = 0; i < SEQ_MAX_ROWS; i++) {
    float ry = y + 26 + i * rowH;

    boolean isCurrentRow = (advState == ADV_RUNNING && seqCurrentStep == i);
    if (isCurrentRow) {
      fill(#1B3A1B);
    } else {
      fill(i % 2 == 0 ? COL_PANEL_LITE : COL_PANEL);
    }
    stroke(COL_BORDER, 80);
    strokeWeight(0.5);
    rect(x, ry, w, rowH);

    // Enable checkbox
    fill(seqEnabled[i] ? COL_ON : COL_DIM);
    stroke(COL_BORDER);
    strokeWeight(1);
    rect(colX[0] + 8, ry + 8, 16, 16, 2);
    if (seqEnabled[i]) {
      fill(#000000);
      textAlign(CENTER, CENTER);
      textSize(12);
      text("v", colX[0] + 16, ry + 15);
    }

    // Row number
    fill(COL_TEXT_DIM);
    textAlign(CENTER, CENTER);
    textSize(11);
    text(str(i + 1), colX[1] + 40, ry + rowH/2);

    // Editable cells
    drawEditableCell(colX[2] + 4, ry + 4, 110, rowH - 8, nf(seqVoltage[i], 0, 3), i, 0, "V");
    drawEditableCell(colX[3] + 4, ry + 4, 110, rowH - 8, nf(seqCurrent[i], 0, 3), i, 1, "A");
    drawEditableCell(colX[4] + 4, ry + 4, 90,  rowH - 8, nf(seqDelay[i], 0, 1), i, 2, "s");

    // Status
    fill(seqStatus[i] == 2 ? COL_ON : (seqStatus[i] == 1 ? COL_WARN : COL_TEXT_DIM));
    textAlign(LEFT, CENTER);
    textSize(10);
    String statusText = seqStatus[i] == 2 ? "OK" : (seqStatus[i] == 1 ? "Running..." : "Waiting");
    text(statusText, colX[5] + 4, ry + rowH/2);

    // Progress bar
    if (isCurrentRow && advState == ADV_RUNNING) {
      float elapsed = (millis() - seqStepStartTime) / 1000.0;
      float progress = constrain(elapsed / seqDelay[i], 0, 1);
      fill(#1A1A25);
      noStroke();
      rect(colX[6] + 4, ry + 10, w - colX[6] + x - 12, 12, 3);
      fill(COL_ON);
      rect(colX[6] + 4, ry + 10, (w - colX[6] + x - 12) * progress, 12, 3);
      fill(COL_TEXT);
      textAlign(CENTER, CENTER);
      textSize(8);
      text(nf(elapsed, 0, 1) + "/" + nf(seqDelay[i], 0, 1), colX[6] + 4 + (w - colX[6] + x - 12)/2, ry + 16);
    }
  }
}

/**
 * Draw a single editable table cell with optional edit-mode cursor.
 * @param x          Cell X position
 * @param y          Cell Y position
 * @param w          Cell width
 * @param h          Cell height
 * @param displayVal Display string when not editing
 * @param row        Row index in the sequence table
 * @param col        Column index (0=V, 1=A, 2=delay)
 * @param suffix     Unit suffix ("V", "A", "s")
 */
void drawEditableCell(float x, float y, float w, float h, String displayVal, int row, int col, String suffix) {
  boolean isEditing = (seqEditRow == row && seqEditCol == col);
  fill(isEditing ? #0D1B2A : COL_INPUT_BG);
  stroke(isEditing ? COL_ACCENT : COL_BORDER, isEditing ? 200 : 60);
  strokeWeight(isEditing ? 1.5 : 0.5);
  rect(x, y, w, h, 2);

  fill(COL_TEXT);
  textAlign(LEFT, CENTER);
  textSize(12);
  String display = isEditing ? seqEditBuffer + (frameCount % 30 < 15 ? "|" : "") : displayVal;
  text(display + " " + suffix, x + 4, y + h/2);
}

// ============================================================
// VOLTAGE SWEEP PANEL
// ============================================================

/**
 * Draw the voltage sweep configuration panel with editable fields and preview.
 * @param x X origin
 * @param y Y origin
 * @param w Width
 * @param h Height
 */
void drawVoltageSweep(float x, float y, float w, float h) {
  fill(COL_TEXT_DIM);
  textAlign(LEFT, TOP);
  textSize(11);
  text("Scan voltage within range at fixed current. Step voltage is applied at each delay interval.", x + 5, y + 5);
  text("Commonly used for constant voltage mode testing.", x + 5, y + 20);

  float fieldW = 140;
  float fieldH = 28;
  float labelW = 110;
  float col1 = x + 20;
  float col2 = x + 300;
  float startY = y + 55;
  float gap = 55;

  drawSweepField(col1, startY,           labelW, fieldW, fieldH, "Fixed Current:", nf(vsFixedCurrent, 0, 3), "A", 0, 1);
  drawSweepField(col1, startY + gap,     labelW, fieldW, fieldH, "Start Voltage:", nf(vsStartVoltage, 0, 3), "V", 1, 1);
  drawSweepField(col1, startY + gap * 2, labelW, fieldW, fieldH, "End Voltage:",   nf(vsEndVoltage, 0, 3),   "V", 2, 1);

  drawSweepField(col2, startY,           labelW, fieldW, fieldH, "Step Voltage:",  nf(vsStepVoltage, 0, 3),  "V", 3, 1);
  drawSweepField(col2, startY + gap,     labelW, fieldW, fieldH, "Delay (sec):",   nf(vsDelay, 0, 1),        "s", 4, 1);

  fill(COL_TEXT_DIM);
  textSize(9);
  textAlign(LEFT, TOP);
  text("Voltage range: 0.00 - 30.00 V", col2, startY + gap * 2);
  text("Step range: 0.01 - 30.00 V", col2, startY + gap * 2 + 14);
  text("Delay range: 1 - 86400 s", col2, startY + gap * 2 + 28);

  drawSweepPreview(x + 20, y + h - 150, w - 40, 130, vsStartVoltage, vsEndVoltage, vsStepVoltage, vsDelay, "V", vsCurrentValue, advMode == 1);
}

// ============================================================
// CURRENT SWEEP PANEL
// ============================================================

/**
 * Draw the current sweep configuration panel with editable fields and preview.
 * @param x X origin
 * @param y Y origin
 * @param w Width
 * @param h Height
 */
void drawCurrentSweep(float x, float y, float w, float h) {
  fill(COL_TEXT_DIM);
  textAlign(LEFT, TOP);
  textSize(11);
  text("Scan current within range at fixed voltage. Step current is applied at each delay interval.", x + 5, y + 5);
  text("Commonly used for constant current mode testing.", x + 5, y + 20);

  float fieldW = 140;
  float fieldH = 28;
  float labelW = 110;
  float col1 = x + 20;
  float col2 = x + 300;
  float startY = y + 55;
  float gap = 55;

  drawSweepField(col1, startY,           labelW, fieldW, fieldH, "Fixed Voltage:", nf(csFixedVoltage, 0, 3), "V", 0, 2);
  drawSweepField(col1, startY + gap,     labelW, fieldW, fieldH, "Start Current:", nf(csStartCurrent, 0, 3), "A", 1, 2);
  drawSweepField(col1, startY + gap * 2, labelW, fieldW, fieldH, "End Current:",   nf(csEndCurrent, 0, 3),   "A", 2, 2);

  drawSweepField(col2, startY,           labelW, fieldW, fieldH, "Step Current:",  nf(csStepCurrent, 0, 3),  "A", 3, 2);
  drawSweepField(col2, startY + gap,     labelW, fieldW, fieldH, "Delay (sec):",   nf(csDelay, 0, 1),        "s", 4, 2);

  fill(COL_TEXT_DIM);
  textSize(9);
  textAlign(LEFT, TOP);
  text("Current range: 0.000 - 5.000 A", col2, startY + gap * 2);
  text("Step range: 0.001 - 5.000 A", col2, startY + gap * 2 + 14);
  text("Delay range: 1 - 86400 s", col2, startY + gap * 2 + 28);

  drawSweepPreview(x + 20, y + h - 150, w - 40, 130, csStartCurrent, csEndCurrent, csStepCurrent, csDelay, "A", csCurrentValue, advMode == 2);
}

// ============================================================
// SHARED: Sweep field drawing
// ============================================================

/**
 * Draw a labeled input field for sweep parameters.
 * @param x          X position
 * @param y          Y position
 * @param labelW     Label column width
 * @param fieldW     Input field width
 * @param fieldH     Input field height
 * @param label      Label text
 * @param displayVal Display value string
 * @param suffix     Unit suffix
 * @param fieldIdx   Field index (0-4) within the sweep type
 * @param sweepType  1 = voltage sweep, 2 = current sweep
 */
void drawSweepField(float x, float y, float labelW, float fieldW, float fieldH, String label, String displayVal, String suffix, int fieldIdx, int sweepType) {
  boolean isEditing = false;
  if (sweepType == 1 && vsEditField == fieldIdx) isEditing = true;
  if (sweepType == 2 && csEditField == fieldIdx) isEditing = true;

  fill(COL_TEXT);
  textAlign(RIGHT, CENTER);
  textSize(11);
  text(label, x + labelW - 5, y + fieldH/2);

  fill(isEditing ? #0D1B2A : COL_INPUT_BG);
  stroke(isEditing ? COL_ACCENT : COL_INPUT_BORDER);
  strokeWeight(isEditing ? 1.5 : 1);
  rect(x + labelW, y, fieldW, fieldH, 3);

  fill(COL_TEXT);
  textAlign(LEFT, CENTER);
  textSize(13);
  String editBuf = (sweepType == 1) ? vsEditBuffer : csEditBuffer;
  String display = isEditing ? editBuf + (frameCount % 30 < 15 ? "|" : "") : displayVal;
  text(display + " " + suffix, x + labelW + 6, y + fieldH/2);
}

// ============================================================
// SWEEP PREVIEW — mini staircase graph
// ============================================================

/**
 * Draw a mini staircase preview of a sweep's voltage/current ramp.
 * @param x           X position
 * @param y           Y position
 * @param w           Width
 * @param h           Height
 * @param startVal    Sweep start value
 * @param endVal      Sweep end value
 * @param stepVal     Step size
 * @param delayVal    Delay between steps (for display only)
 * @param unit        Unit label ("V" or "A")
 * @param currentVal  Current sweep position (for marker)
 * @param isThisSweep True if this sweep mode is actively running
 */
void drawSweepPreview(float x, float y, float w, float h, float startVal, float endVal, float stepVal, float delayVal, String unit, float currentVal, boolean isThisSweep) {
  fill(COL_GRAPH_BG);
  stroke(COL_BORDER);
  strokeWeight(1);
  rect(x, y, w, h, 3);

  fill(COL_TEXT_DIM);
  textAlign(LEFT, TOP);
  textSize(9);
  text("Preview", x + 5, y + 3);

  float gx = x + 35;
  float gy = y + 18;
  float gw = w - 45;
  float gh = h - 28;

  // Grid
  stroke(COL_GRID);
  strokeWeight(0.5);
  for (int i = 0; i <= 4; i++) {
    float yy = gy + gh * i / 4.0;
    line(gx, yy, gx + gw, yy);
  }

  // Calculate steps
  if (stepVal <= 0) stepVal = 0.01;
  int numSteps = (int)(abs(endVal - startVal) / stepVal) + 1;
  numSteps = min(numSteps, 200);
  float minV = min(startVal, endVal);
  float maxV = max(startVal, endVal);
  if (maxV <= minV) maxV = minV + 1;

  // Y-axis labels
  fill(COL_TEXT_DIM);
  textAlign(RIGHT, CENTER);
  textSize(8);
  for (int i = 0; i <= 4; i++) {
    float yy = gy + gh * i / 4.0;
    float label = maxV - (maxV - minV) * ((float)i / 4.0);
    text(nf(label, 0, 1), gx - 3, yy);
  }

  // Draw staircase
  stroke(COL_ACCENT_LITE);
  strokeWeight(1.5);
  noFill();
  boolean goingUp = (endVal >= startVal);

  beginShape();
  for (int i = 0; i < numSteps; i++) {
    float val = goingUp ? startVal + i * stepVal : startVal - i * stepVal;
    val = constrain(val, minV, maxV);
    float px1 = gx + gw * ((float)i / numSteps);
    float px2 = gx + gw * ((float)(i + 1) / numSteps);
    float py = gy + gh * (1.0 - (val - minV) / (maxV - minV));
    vertex(px1, py);
    vertex(px2, py);
  }
  endShape();

  // Current position marker
  if (isThisSweep && advState == ADV_RUNNING) {
    float markerY = gy + gh * (1.0 - (currentVal - minV) / (maxV - minV));
    markerY = constrain(markerY, gy, gy + gh);
    fill(COL_ON);
    noStroke();
    ellipse(gx + gw / 2, markerY, 8, 8);
    fill(COL_ON, 40);
    ellipse(gx + gw / 2, markerY, 16, 16);
  }
}

// ============================================================
// ADVANCED EXECUTION ENGINE
// ============================================================

long advLastStepTime = 0;  ///< millis() of last sweep step

/**
 * Execution tick — call from draw().  Advances the active mode
 * (sequential, voltage sweep, or current sweep) if running.
 */
void updateAdvanced() {
  if (advState != ADV_RUNNING || !psu.connected) return;

  long now = millis();

  switch (advMode) {
    case 0: updateSequentialOutput(now); break;
    case 1: updateVoltageSweep(now); break;
    case 2: updateCurrentSweep(now); break;
  }
}

/**
 * Advance the sequential output state machine.
 * @param now Current millis() timestamp
 */
void updateSequentialOutput(long now) {
  if (seqCurrentStep < 0) {
    seqCurrentStep = nextEnabledStep(-1);
    if (seqCurrentStep < 0) { advStop(); return; }
    applySequentialStep(seqCurrentStep);
    return;
  }

  float delaySec = seqDelay[seqCurrentStep];
  if ((now - seqStepStartTime) >= (long)(delaySec * 1000)) {
    seqStatus[seqCurrentStep] = 2; // OK

    int nextStep = nextEnabledStep(seqCurrentStep);
    if (nextStep < 0) {
      seqCurrentLoop++;
      if (seqLoopCount > 0 && seqCurrentLoop >= seqLoopCount) {
        advStop();
        setStatus("Sequence completed. " + seqCurrentLoop + " loop(s) done.");
        return;
      }
      resetSeqStatus();
      seqCurrentStep = nextEnabledStep(-1);
      if (seqCurrentStep < 0) { advStop(); return; }
    } else {
      seqCurrentStep = nextStep;
    }
    applySequentialStep(seqCurrentStep);
  }
}

/**
 * Apply the V/A values for a sequential step and enable the output.
 * @param step Row index to apply
 */
void applySequentialStep(int step) {
  seqStatus[step] = 1; // Running
  seqStepStartTime = millis();
  psu.sendSetVoltage(seqVoltage[step]);
  psu.sendSetCurrent(seqCurrent[step]);
  if (!psu.outputOn) {
    psu.sendOutputOn();
    psu.outputOn = true;
  }
  setStatus("Seq step " + (step+1) + ": " + nf(seqVoltage[step],0,3) + "V / " + nf(seqCurrent[step],0,3) + "A");
}

/**
 * Find the next enabled row after a given index.
 * @param afterStep Index to search after (-1 to start from the beginning)
 * @return Row index, or -1 if no more enabled rows
 */
int nextEnabledStep(int afterStep) {
  for (int i = afterStep + 1; i < SEQ_MAX_ROWS; i++) {
    if (seqEnabled[i]) return i;
  }
  return -1;
}

/** @return Number of enabled rows in the sequence table. */
int countEnabledSteps() {
  int count = 0;
  for (int i = 0; i < SEQ_MAX_ROWS; i++) {
    if (seqEnabled[i]) count++;
  }
  return count;
}

/** Reset all row statuses to "waiting". */
void resetSeqStatus() {
  for (int i = 0; i < SEQ_MAX_ROWS; i++) seqStatus[i] = 0;
}

/**
 * Advance the voltage sweep by one step if the delay has elapsed.
 * @param now Current millis() timestamp
 */
void updateVoltageSweep(long now) {
  if ((now - advLastStepTime) >= (long)(vsDelay * 1000)) {
    advLastStepTime = now;

    psu.sendSetVoltage(vsCurrentValue);
    psu.sendSetCurrent(vsFixedCurrent);
    if (!psu.outputOn) { psu.sendOutputOn(); psu.outputOn = true; }
    setStatus("V Sweep: " + nf(vsCurrentValue, 0, 3) + "V");

    if (vsStartVoltage <= vsEndVoltage) {
      vsCurrentValue += vsStepVoltage;
      if (vsCurrentValue > vsEndVoltage + 0.0001) {
        advStop();
        setStatus("Voltage sweep completed.");
      }
    } else {
      vsCurrentValue -= vsStepVoltage;
      if (vsCurrentValue < vsEndVoltage - 0.0001) {
        advStop();
        setStatus("Voltage sweep completed.");
      }
    }
  }
}

/**
 * Advance the current sweep by one step if the delay has elapsed.
 * @param now Current millis() timestamp
 */
void updateCurrentSweep(long now) {
  if ((now - advLastStepTime) >= (long)(csDelay * 1000)) {
    advLastStepTime = now;

    psu.sendSetVoltage(csFixedVoltage);
    psu.sendSetCurrent(csCurrentValue);
    if (!psu.outputOn) { psu.sendOutputOn(); psu.outputOn = true; }
    setStatus("I Sweep: " + nf(csCurrentValue, 0, 3) + "A");

    if (csStartCurrent <= csEndCurrent) {
      csCurrentValue += csStepCurrent;
      if (csCurrentValue > csEndCurrent + 0.0001) {
        advStop();
        setStatus("Current sweep completed.");
      }
    } else {
      csCurrentValue -= csStepCurrent;
      if (csCurrentValue < csEndCurrent - 0.0001) {
        advStop();
        setStatus("Current sweep completed.");
      }
    }
  }
}

// ============================================================
// START / PAUSE / CONTINUE / STOP
// ============================================================

/** Start the active advanced mode (sequential, V sweep, or I sweep). */
void advStart() {
  if (!psu.connected) return;
  advState = ADV_RUNNING;

  switch (advMode) {
    case 0:
      resetSeqStatus();
      seqCurrentStep = -1;
      seqCurrentLoop = 0;
      setStatus("Sequential output started.");
      break;
    case 1:
      vsCurrentValue = vsStartVoltage;
      advLastStepTime = millis() - (long)(vsDelay * 1000);
      setStatus("Voltage sweep started.");
      break;
    case 2:
      csCurrentValue = csStartCurrent;
      advLastStepTime = millis() - (long)(csDelay * 1000);
      setStatus("Current sweep started.");
      break;
  }
}

/** Pause the currently running advanced mode. */
void advPause() {
  advState = ADV_PAUSED;
  setStatus("Advanced output paused.");
}

/** Resume a paused advanced mode. */
void advContinue() {
  if (advState == ADV_PAUSED) {
    advState = ADV_RUNNING;
    if (advMode == 0 && seqCurrentStep >= 0) {
      seqStepStartTime = millis();
    } else {
      advLastStepTime = millis();
    }
    setStatus("Advanced output resumed.");
  }
}

/** Stop the advanced mode and reset to idle. */
void advStop() {
  advState = ADV_IDLE;
  seqCurrentStep = -1;
  if (advMode == 0) resetSeqStatus();
  setStatus("Advanced output stopped.");
}

/**
 * Execute a single sequential step, then pause.
 *
 * If idle, starts from the first enabled row.  If paused, advances
 * to the next enabled row.
 */
void advSingleStep() {
  if (advMode != 0) return;
  if (advState == ADV_IDLE) {
    seqCurrentStep = nextEnabledStep(-1);
    if (seqCurrentStep < 0) return;
    seqCurrentLoop = 0;
    resetSeqStatus();
  } else if (advState == ADV_PAUSED) {
    seqStatus[seqCurrentStep] = 2;
    int nextStep = nextEnabledStep(seqCurrentStep);
    if (nextStep < 0) {
      advStop();
      setStatus("Sequence completed (single step).");
      return;
    }
    seqCurrentStep = nextStep;
  }

  advState = ADV_PAUSED;
  applySequentialStep(seqCurrentStep);
  setStatus("Single step: " + (seqCurrentStep + 1));
}

// ============================================================
// ADVANCED INPUT HANDLING
// ============================================================

/** Handle mouse clicks inside the advanced overlay. */
void handleAdvancedClick() {
  if (!advancedOpen) return;

  if (btnAdvClose.clicked()) {
    if (advState != ADV_IDLE) advStop();
    advancedOpen = false;
    return;
  }

  // Mode tabs (only when idle)
  if (advState == ADV_IDLE) {
    if (btnAdvModeSeq.clicked()) advMode = 0;
    if (btnAdvModeVS.clicked())  advMode = 1;
    if (btnAdvModeCS.clicked())  advMode = 2;
  }

  // Loop count
  if (btnLoopUp.clicked())   seqLoopCount = min(seqLoopCount + 1, 999);
  if (btnLoopDown.clicked()) seqLoopCount = max(seqLoopCount - 1, 0);

  // Control buttons
  if (btnAdvStart.clicked())      advStart();
  if (btnAdvPause.clicked())      advPause();
  if (btnAdvContinue.clicked())   advContinue();
  if (btnAdvStop.clicked())       advStop();
  if (btnAdvSingleStep.clicked()) advSingleStep();

  if (btnAdvClearTable.clicked() && advState == ADV_IDLE) {
    for (int i = 0; i < SEQ_MAX_ROWS; i++) {
      seqVoltage[i] = 0; seqCurrent[i] = 0; seqDelay[i] = 1.0;
      seqEnabled[i] = false; seqStatus[i] = 0;
    }
    seqEnabled[0] = true;
    vsEditField = -1; csEditField = -1;
    seqEditRow = -1; seqEditCol = -1;
  }

  // Content-area clicks
  if (advMode == 0) {
    handleSeqTableClick();
  } else if (advMode == 1) {
    handleSweepFieldClick(1);
  } else if (advMode == 2) {
    handleSweepFieldClick(2);
  }
}

/** Handle clicks on the sequential table cells and checkboxes. */
void handleSeqTableClick() {
  float tableY = advY + 64 + 26;
  float rowH = 32;

  commitSeqEdit();
  seqEditRow = -1;
  seqEditCol = -1;

  for (int i = 0; i < SEQ_MAX_ROWS; i++) {
    float ry = tableY + i * rowH;
    if (mouseY < ry || mouseY > ry + rowH) continue;

    if (mouseX >= advX + 8 + 8 && mouseX <= advX + 8 + 24) {
      seqEnabled[i] = !seqEnabled[i];
      return;
    }

    float vx = advX + 8 + 130 + 4;
    if (mouseX >= vx && mouseX <= vx + 110) {
      seqEditRow = i; seqEditCol = 0;
      seqEditBuffer = nf(seqVoltage[i], 0, 3);
      return;
    }

    float cx = advX + 8 + 250 + 4;
    if (mouseX >= cx && mouseX <= cx + 110) {
      seqEditRow = i; seqEditCol = 1;
      seqEditBuffer = nf(seqCurrent[i], 0, 3);
      return;
    }

    float dx = advX + 8 + 370 + 4;
    if (mouseX >= dx && mouseX <= dx + 90) {
      seqEditRow = i; seqEditCol = 2;
      seqEditBuffer = nf(seqDelay[i], 0, 1);
      return;
    }
  }
}

/** Commit the currently edited sequential table cell value. */
void commitSeqEdit() {
  if (seqEditRow >= 0 && seqEditCol >= 0) {
    float val = 0;
    try { val = Float.parseFloat(seqEditBuffer); } catch (Exception e) { return; }
    switch (seqEditCol) {
      case 0: seqVoltage[seqEditRow] = constrain(val, 0, 30); break;
      case 1: seqCurrent[seqEditRow] = constrain(val, 0, 5); break;
      case 2: seqDelay[seqEditRow]   = constrain(val, 0.1, 86400); break;
    }
  }
}

/**
 * Handle clicks on sweep parameter fields.
 * @param sweepType 1 = voltage sweep, 2 = current sweep
 */
void handleSweepFieldClick(int sweepType) {
  float x = advX + 8;
  float startY = advY + 64 + 55;
  float gap = 55;
  float labelW = 110;
  float fieldW = 140;
  float fieldH = 28;
  float col1 = x + 20 + labelW;
  float col2 = x + 300 + labelW;

  commitSweepEdit(sweepType);

  if (sweepType == 1) vsEditField = -1;
  else csEditField = -1;

  float[][] fieldPositions = {
    {col1, startY},
    {col1, startY + gap},
    {col1, startY + gap * 2},
    {col2, startY},
    {col2, startY + gap}
  };

  for (int f = 0; f < 5; f++) {
    float fx = fieldPositions[f][0];
    float fy = fieldPositions[f][1];
    if (mouseX >= fx && mouseX <= fx + fieldW && mouseY >= fy && mouseY <= fy + fieldH) {
      if (sweepType == 1) {
        vsEditField = f;
        switch (f) {
          case 0: vsEditBuffer = nf(vsFixedCurrent, 0, 3); break;
          case 1: vsEditBuffer = nf(vsStartVoltage, 0, 3); break;
          case 2: vsEditBuffer = nf(vsEndVoltage, 0, 3); break;
          case 3: vsEditBuffer = nf(vsStepVoltage, 0, 3); break;
          case 4: vsEditBuffer = nf(vsDelay, 0, 1); break;
        }
      } else {
        csEditField = f;
        switch (f) {
          case 0: csEditBuffer = nf(csFixedVoltage, 0, 3); break;
          case 1: csEditBuffer = nf(csStartCurrent, 0, 3); break;
          case 2: csEditBuffer = nf(csEndCurrent, 0, 3); break;
          case 3: csEditBuffer = nf(csStepCurrent, 0, 3); break;
          case 4: csEditBuffer = nf(csDelay, 0, 1); break;
        }
      }
      return;
    }
  }
}

/**
 * Commit the currently edited sweep field value.
 * @param sweepType 1 = voltage sweep, 2 = current sweep
 */
void commitSweepEdit(int sweepType) {
  float val = 0;
  if (sweepType == 1 && vsEditField >= 0) {
    try { val = Float.parseFloat(vsEditBuffer); } catch (Exception e) { return; }
    switch (vsEditField) {
      case 0: vsFixedCurrent = constrain(val, 0.001, 5); break;
      case 1: vsStartVoltage = constrain(val, 0, 30); break;
      case 2: vsEndVoltage   = constrain(val, 0, 30); break;
      case 3: vsStepVoltage  = constrain(val, 0.01, 30); break;
      case 4: vsDelay        = constrain(val, 1, 86400); break;
    }
    vsEditField = -1;
  }
  if (sweepType == 2 && csEditField >= 0) {
    try { val = Float.parseFloat(csEditBuffer); } catch (Exception e) { return; }
    switch (csEditField) {
      case 0: csFixedVoltage = constrain(val, 0.001, 30); break;
      case 1: csStartCurrent = constrain(val, 0, 5); break;
      case 2: csEndCurrent   = constrain(val, 0, 5); break;
      case 3: csStepCurrent  = constrain(val, 0.001, 5); break;
      case 4: csDelay        = constrain(val, 1, 86400); break;
    }
    csEditField = -1;
  }
}

// ============================================================
// ADVANCED KEY HANDLING
// ============================================================

/**
 * Handle keyboard input inside the advanced overlay.
 *
 * Dispatches to the active editing context (sequential table cell
 * or sweep field).  ESC closes the window.
 *
 * @param k    Character typed
 * @param kCode Key code
 */
void handleAdvancedKey(char k, int kCode) {
  if (!advancedOpen) return;

  // Sequential table editing
  if (advMode == 0 && seqEditRow >= 0 && seqEditCol >= 0) {
    if (k == BACKSPACE || k == DELETE) {
      if (seqEditBuffer.length() > 0) seqEditBuffer = seqEditBuffer.substring(0, seqEditBuffer.length()-1);
    } else if ((k >= '0' && k <= '9') || k == '.') {
      if (k == '.' && seqEditBuffer.indexOf('.') >= 0) return;
      if (seqEditBuffer.length() < 10) seqEditBuffer += k;
    } else if (k == ENTER || k == RETURN) {
      commitSeqEdit();
      seqEditRow = -1; seqEditCol = -1;
    } else if (k == TAB) {
      commitSeqEdit();
      seqEditCol++;
      if (seqEditCol > 2) { seqEditCol = 0; seqEditRow = (seqEditRow + 1) % SEQ_MAX_ROWS; }
      switch (seqEditCol) {
        case 0: seqEditBuffer = nf(seqVoltage[seqEditRow], 0, 3); break;
        case 1: seqEditBuffer = nf(seqCurrent[seqEditRow], 0, 3); break;
        case 2: seqEditBuffer = nf(seqDelay[seqEditRow], 0, 1); break;
      }
    }
    return;
  }

  // Voltage sweep field editing
  if (advMode == 1 && vsEditField >= 0) {
    if (k == BACKSPACE || k == DELETE) {
      if (vsEditBuffer.length() > 0) vsEditBuffer = vsEditBuffer.substring(0, vsEditBuffer.length()-1);
    } else if ((k >= '0' && k <= '9') || k == '.') {
      if (k == '.' && vsEditBuffer.indexOf('.') >= 0) return;
      if (vsEditBuffer.length() < 10) vsEditBuffer += k;
    } else if (k == ENTER || k == RETURN) {
      commitSweepEdit(1);
    } else if (k == TAB) {
      commitSweepEdit(1);
    }
    return;
  }

  // Current sweep field editing
  if (advMode == 2 && csEditField >= 0) {
    if (k == BACKSPACE || k == DELETE) {
      if (csEditBuffer.length() > 0) csEditBuffer = csEditBuffer.substring(0, csEditBuffer.length()-1);
    } else if ((k >= '0' && k <= '9') || k == '.') {
      if (k == '.' && csEditBuffer.indexOf('.') >= 0) return;
      if (csEditBuffer.length() < 10) csEditBuffer += k;
    } else if (k == ENTER || k == RETURN) {
      commitSweepEdit(2);
    } else if (k == TAB) {
      commitSweepEdit(2);
    }
    return;
  }

  // ESC to close
  if (k == ESC) {
    key = 0; // prevent Processing from closing
    if (advState != ADV_IDLE) advStop();
    advancedOpen = false;
  }
}
