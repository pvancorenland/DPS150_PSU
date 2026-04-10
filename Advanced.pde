/**
 * @file Advanced.pde
 * @brief Advanced programmable output — Sequential Output, Voltage Sweep, Current Sweep.
 *
 * @author  Peter Vancorenland
 * @copyright 2026 Peter Vancorenland. All rights reserved.
 *
 * Redistribution and use of this source code, with or without modification,
 * is permitted provided that the original author is credited.
 */

// ============================================================
// STATE
// ============================================================

/// True when the Advanced overlay is visible
boolean advancedOpen = false;
/// Active mode: 0=Sequential, 1=V Sweep, 2=I Sweep
int advMode = 0;

/** @name Advanced State Codes
 *  @{ */
static final int ADV_IDLE = 0;     ///< No sequence or sweep is running
static final int ADV_RUNNING = 1;  ///< Sequence or sweep is actively executing
static final int ADV_PAUSED = 2;   ///< Execution is paused and can be resumed
/** @} */

/// Current execution state
int advState = ADV_IDLE;

// Sequential output
/// Maximum number of rows in the sequential output table
static final int SEQ_MAX_ROWS = 10;
/// Voltage set-point for each sequential step (V)
float[] seqVoltage = new float[SEQ_MAX_ROWS];
/// Current set-point for each sequential step (A)
float[] seqCurrent = new float[SEQ_MAX_ROWS];
/// Delay duration for each sequential step (seconds)
float[] seqDelay   = new float[SEQ_MAX_ROWS];
/// Whether each sequential step is enabled
boolean[] seqEnabled = new boolean[SEQ_MAX_ROWS];
/// Status of each step: 0=waiting, 1=running, 2=done
int[] seqStatus = new int[SEQ_MAX_ROWS];
/// Number of loops (0 = infinite)
int seqLoopCount = 1;
/// Current loop index during execution
int seqCurrentLoop = 0;
/// Current step index during execution
int seqCurrentStep = -1;
/// Timestamp when the current step began
long seqStepStartTime = 0;
/// Row being edited (-1 = none)
int seqEditRow = -1;
/// Column being edited (-1 = none)
int seqEditCol = -1;
/// Text buffer for the active table cell editor
String seqEditBuffer = "";

// Voltage sweep
/// Fixed current applied during voltage sweep (A)
float vsFixedCurrent = 1.0;
/// Start voltage for the sweep (V)
float vsStartVoltage = 1.0;
/// End voltage for the sweep (V)
float vsEndVoltage = 12.0;
/// Voltage increment per step (V)
float vsStepVoltage = 0.5;
/// Delay between sweep steps (seconds)
float vsDelay = 2.0;
/// Current sweep output value (V)
float vsCurrentValue = 0;
/// Sweep field currently being edited (-1 = none)
int vsEditField = -1;
/// Text buffer for the active voltage sweep field editor
String vsEditBuffer = "";

// Current sweep
/// Fixed voltage applied during current sweep (V)
float csFixedVoltage = 5.0;
/// Start current for the sweep (A)
float csStartCurrent = 0.1;
/// End current for the sweep (A)
float csEndCurrent = 3.0;
/// Current increment per step (A)
float csStepCurrent = 0.1;
/// Delay between sweep steps (seconds)
float csDelay = 2.0;
/// Current sweep output value (A)
float csCurrentValue = 0;
/// Sweep field currently being edited (-1 = none)
int csEditField = -1;
/// Text buffer for the active current sweep field editor
String csEditBuffer = "";

// Window geometry & widgets
/// Advanced overlay X position (px)
float advX;
/// Advanced overlay Y position (px)
float advY;
/// Advanced overlay width (px)
float advW;
/// Advanced overlay height (px)
float advH;
/// Close button for the Advanced overlay
AdvButton btnAdvClose;
/// Mode tab button: Sequential Output
AdvButton btnAdvModeSeq;
/// Mode tab button: Voltage Sweep
AdvButton btnAdvModeVS;
/// Mode tab button: Current Sweep
AdvButton btnAdvModeCS;
/// Control button: Start execution
AdvButton btnAdvStart;
/// Control button: Pause execution
AdvButton btnAdvPause;
/// Control button: Continue (resume) execution
AdvButton btnAdvContinue;
/// Control button: Stop execution
AdvButton btnAdvStop;
/// Control button: Execute a single sequential step
AdvButton btnAdvSingleStep;
/// Control button: Clear the sequential table
AdvButton btnAdvClearTable;
/// Loop count increment button
AdvButton btnLoopUp;
/// Loop count decrement button
AdvButton btnLoopDown;

/// Timestamp of the last sweep step
long advLastStepTime = 0;

// ============================================================
// INIT
// ============================================================

/**
 * @brief Initialize the Advanced overlay: compute geometry, create buttons, set default sequential table values.
 */
void initAdvanced() {
  advW = 780; advH = 520;
  advX = (WIN_W - advW) / 2;
  advY = (WIN_H - advH) / 2;

  btnAdvClose = new AdvButton(advX + advW - 30, advY + 5, 24, 20, "X");
  btnAdvClose.bgColor = #7F1D1D; btnAdvClose.hoverColor = #B71C1C;

  float tabY = advY + 32;
  btnAdvModeSeq = new AdvButton(advX + 8, tabY, 120, 26, "Sequential");
  btnAdvModeVS  = new AdvButton(advX + 134, tabY, 120, 26, "V Sweep");
  btnAdvModeCS  = new AdvButton(advX + 260, tabY, 120, 26, "I Sweep");

  float ctrlY = advY + advH - 45;
  btnAdvStart    = new AdvButton(advX + 10,  ctrlY, 90, 30, "Start");
  btnAdvStart.bgColor = #1B5E20; btnAdvStart.hoverColor = #2E7D32;
  btnAdvPause    = new AdvButton(advX + 108, ctrlY, 90, 30, "Pause");
  btnAdvPause.bgColor = #E65100; btnAdvPause.hoverColor = #FF8F00;
  btnAdvContinue = new AdvButton(advX + 206, ctrlY, 90, 30, "Continue");
  btnAdvContinue.bgColor = #1565C0; btnAdvContinue.hoverColor = #1E88E5;
  btnAdvStop     = new AdvButton(advX + 304, ctrlY, 90, 30, "Stop");
  btnAdvStop.bgColor = #7F1D1D; btnAdvStop.hoverColor = #B71C1C;
  btnAdvSingleStep = new AdvButton(advX + 402, ctrlY, 100, 30, "Single Step");
  btnAdvSingleStep.bgColor = #4A148C; btnAdvSingleStep.hoverColor = #7B1FA2;
  btnAdvClearTable = new AdvButton(advX + 510, ctrlY, 90, 30, "Clear");

  btnLoopUp   = new AdvButton(advX + advW - 80, tabY, 24, 12, "+");
  btnLoopDown = new AdvButton(advX + advW - 80, tabY + 14, 24, 12, "-");

  for (int i = 0; i < SEQ_MAX_ROWS; i++) {
    seqVoltage[i] = 5.0; seqCurrent[i] = 1.0; seqDelay[i] = 2.0;
    seqEnabled[i] = (i == 0); seqStatus[i] = 0;
  }
}

// ============================================================
// DRAW
// ============================================================

/**
 * @brief Draw the Advanced overlay if open: dim background, window chrome, mode tabs, content area, control buttons.
 */
void drawAdvanced() {
  if (!advancedOpen) return;

  // Dim overlay + window chrome
  fill(0, 160); noStroke(); rect(0, 0, WIN_W, WIN_H);
  fill(0, 80); rect(advX + 4, advY + 4, advW, advH, 8);
  fill(COL_PANEL); stroke(COL_BORDER); strokeWeight(2);
  rect(advX, advY, advW, advH, 8);
  fill(COL_PANEL_HEADER); noStroke();
  rect(advX + 2, advY + 2, advW - 4, 28, 6, 6, 0, 0);
  fill(COL_TEXT); textAlign(LEFT, CENTER); textSize(13);
  text("Advanced — Programmable Output", advX + 12, advY + 16);

  btnAdvClose.draw();

  // Mode tabs
  btnAdvModeSeq.bgColor = (advMode == 0) ? COL_ACCENT : COL_BTN;
  btnAdvModeVS.bgColor  = (advMode == 1) ? COL_ACCENT : COL_BTN;
  btnAdvModeCS.bgColor  = (advMode == 2) ? COL_ACCENT : COL_BTN;
  btnAdvModeSeq.draw(); btnAdvModeVS.draw(); btnAdvModeCS.draw();

  // Loop count
  fill(COL_TEXT_DIM); textAlign(RIGHT, CENTER); textSize(10);
  text("Loops: " + seqLoopCount + (seqLoopCount == 0 ? " (inf)" : ""), advX + advW - 88, advY + 45);
  btnLoopUp.draw(); btnLoopDown.draw();

  // Running state indicator
  drawStateIndicator();

  // Content area
  float contentY = advY + 64, contentH = advH - 64 - 55;
  switch (advMode) {
    case 0: drawSequentialOutput(advX + 8, contentY, advW - 16, contentH); break;
    case 1: drawVoltageSweep(advX + 8, contentY, advW - 16, contentH); break;
    case 2: drawCurrentSweep(advX + 8, contentY, advW - 16, contentH); break;
  }

  // Control button states
  btnAdvStart.enabled = (advState == ADV_IDLE) && psu.connected;
  btnAdvPause.enabled = (advState == ADV_RUNNING);
  btnAdvContinue.enabled = (advState == ADV_PAUSED);
  btnAdvStop.enabled = (advState != ADV_IDLE);
  btnAdvSingleStep.enabled = (advState == ADV_IDLE || advState == ADV_PAUSED) && psu.connected && advMode == 0;
  btnAdvClearTable.enabled = (advState == ADV_IDLE);

  btnAdvStart.draw(); btnAdvPause.draw(); btnAdvContinue.draw();
  btnAdvStop.draw(); btnAdvClearTable.draw();
  if (advMode == 0) btnAdvSingleStep.draw();
}

/**
 * @brief Draw the running/paused status indicator with pulsing LED and progress text.
 */
void drawStateIndicator() {
  float sx = advX + 400, sy = advY + 45;
  if (advState == ADV_RUNNING) {
    float pulse = sin(millis() * 0.01) * 0.3 + 0.7;
    fill(color(0, 230, 118, (int)(255 * pulse)));
    noStroke(); ellipse(sx, sy, 10, 10);
    fill(COL_ON); textAlign(LEFT, CENTER); textSize(11);
    text("RUNNING", sx + 10, sy);
    if (advMode == 0) {
      text("Step " + (seqCurrentStep + 1) + "/" + countEnabledSteps() + "  Loop " + (seqCurrentLoop + 1) + "/" + (seqLoopCount == 0 ? "inf" : str(seqLoopCount)), sx + 80, sy);
    } else {
      float cv = (advMode == 1) ? vsCurrentValue : csCurrentValue;
      text("Value: " + nf(cv, 0, 3) + " " + ((advMode == 1) ? "V" : "A"), sx + 80, sy);
    }
  } else if (advState == ADV_PAUSED) {
    fill(COL_WARN); noStroke(); ellipse(sx, sy, 10, 10);
    fill(COL_WARN); textAlign(LEFT, CENTER); textSize(11);
    text("PAUSED", sx + 10, sy);
  }
}

// ============================================================
// SEQUENTIAL OUTPUT TABLE
// ============================================================

/**
 * @brief Draw the sequential output table with headers, checkboxes, editable cells, status, and progress bars.
 *
 * @param x  Left edge of the table area (px)
 * @param y  Top edge of the table area (px)
 * @param w  Width of the table area (px)
 * @param h  Height of the table area (px)
 */
void drawSequentialOutput(float x, float y, float w, float h) {
  float[] colX = {x, x+35, x+130, x+250, x+370, x+480, x+580};
  String[] headers = {"En", "No.", "Voltage (V)", "Current (A)", "Delay (s)", "Status", "Progress"};
  float rowH = 32;

  fill(COL_PANEL_HEADER); noStroke();
  rect(x, y, w, 24, 3, 3, 0, 0);
  fill(COL_TEXT); textAlign(LEFT, CENTER); textSize(10);
  for (int c = 0; c < headers.length; c++) text(headers[c], colX[c] + 4, y + 12);

  for (int i = 0; i < SEQ_MAX_ROWS; i++) {
    float ry = y + 26 + i * rowH;
    boolean isCurrent = (advState == ADV_RUNNING && seqCurrentStep == i);
    fill(isCurrent ? #1B3A1B : (i % 2 == 0 ? COL_PANEL_LITE : COL_PANEL));
    stroke(COL_BORDER, 80); strokeWeight(0.5);
    rect(x, ry, w, rowH);

    // Checkbox
    fill(seqEnabled[i] ? COL_ON : COL_DIM); stroke(COL_BORDER); strokeWeight(1);
    rect(colX[0] + 8, ry + 8, 16, 16, 2);
    if (seqEnabled[i]) { fill(#000000); textAlign(CENTER, CENTER); textSize(12); text("v", colX[0] + 16, ry + 15); }

    // Row number
    fill(COL_TEXT_DIM); textAlign(CENTER, CENTER); textSize(11);
    text(str(i + 1), colX[1] + 40, ry + rowH/2);

    // Editable cells
    drawEditableCell(colX[2] + 4, ry + 4, 110, rowH - 8, nf(seqVoltage[i], 0, 3), i, 0, "V");
    drawEditableCell(colX[3] + 4, ry + 4, 110, rowH - 8, nf(seqCurrent[i], 0, 3), i, 1, "A");
    drawEditableCell(colX[4] + 4, ry + 4, 90,  rowH - 8, nf(seqDelay[i], 0, 1), i, 2, "s");

    // Status
    fill(seqStatus[i] == 2 ? COL_ON : (seqStatus[i] == 1 ? COL_WARN : COL_TEXT_DIM));
    textAlign(LEFT, CENTER); textSize(10);
    text(seqStatus[i] == 2 ? "OK" : (seqStatus[i] == 1 ? "Running..." : "Waiting"), colX[5] + 4, ry + rowH/2);

    // Progress bar
    if (isCurrent && advState == ADV_RUNNING) {
      float elapsed = (millis() - seqStepStartTime) / 1000.0;
      float barW = w - colX[6] + x - 12;
      fill(#1A1A25); noStroke(); rect(colX[6] + 4, ry + 10, barW, 12, 3);
      fill(COL_ON); rect(colX[6] + 4, ry + 10, barW * constrain(elapsed / seqDelay[i], 0, 1), 12, 3);
      fill(COL_TEXT); textAlign(CENTER, CENTER); textSize(8);
      text(nf(elapsed, 0, 1) + "/" + nf(seqDelay[i], 0, 1), colX[6] + 4 + barW/2, ry + 16);
    }
  }
}

/**
 * @brief Draw a single editable table cell with optional blinking cursor when active.
 *
 * @param x           Left edge of the cell (px)
 * @param y           Top edge of the cell (px)
 * @param w           Width of the cell (px)
 * @param h           Height of the cell (px)
 * @param displayVal  Formatted value to display when not editing
 * @param row         Row index in the sequential table
 * @param col         Column index (0=voltage, 1=current, 2=delay)
 * @param suffix      Unit suffix string (e.g. "V", "A", "s")
 */
void drawEditableCell(float x, float y, float w, float h, String displayVal, int row, int col, String suffix) {
  boolean editing = (seqEditRow == row && seqEditCol == col);
  fill(editing ? #0D1B2A : COL_INPUT_BG);
  stroke(editing ? COL_ACCENT : COL_BORDER, editing ? 200 : 60);
  strokeWeight(editing ? 1.5 : 0.5);
  rect(x, y, w, h, 2);
  fill(COL_TEXT); textAlign(LEFT, CENTER); textSize(12);
  String display = editing ? seqEditBuffer + (frameCount % 30 < 15 ? "|" : "") : displayVal;
  text(display + " " + suffix, x + 4, y + h/2);
}

// ============================================================
// SWEEP PANELS
// ============================================================

/**
 * @brief Draw the voltage sweep configuration panel with input fields and preview graph.
 *
 * @param x  Left edge of the panel area (px)
 * @param y  Top edge of the panel area (px)
 * @param w  Width of the panel area (px)
 * @param h  Height of the panel area (px)
 */
void drawVoltageSweep(float x, float y, float w, float h) {
  fill(COL_TEXT_DIM); textAlign(LEFT, TOP); textSize(11);
  text("Scan voltage within range at fixed current.", x + 5, y + 5);

  float col1 = x + 20, col2 = x + 300, sY = y + 45, gap = 55;
  drawSweepField(col1, sY,         "Fixed Current:", nf(vsFixedCurrent,0,3), "A", 0, 1);
  drawSweepField(col1, sY+gap,     "Start Voltage:", nf(vsStartVoltage,0,3), "V", 1, 1);
  drawSweepField(col1, sY+gap*2,   "End Voltage:",   nf(vsEndVoltage,0,3),   "V", 2, 1);
  drawSweepField(col2, sY,         "Step Voltage:",  nf(vsStepVoltage,0,3),  "V", 3, 1);
  drawSweepField(col2, sY+gap,     "Delay (sec):",   nf(vsDelay,0,1),        "s", 4, 1);

  fill(COL_TEXT_DIM); textSize(9); textAlign(LEFT, TOP);
  text("V: 0-30  Step: 0.01-30  Delay: 1-86400s", col2, sY + gap * 2);

  drawSweepPreview(x+20, y+h-150, w-40, 130, vsStartVoltage, vsEndVoltage, vsStepVoltage, vsCurrentValue, advMode==1);
}

/**
 * @brief Draw the current sweep configuration panel with input fields and preview graph.
 *
 * @param x  Left edge of the panel area (px)
 * @param y  Top edge of the panel area (px)
 * @param w  Width of the panel area (px)
 * @param h  Height of the panel area (px)
 */
void drawCurrentSweep(float x, float y, float w, float h) {
  fill(COL_TEXT_DIM); textAlign(LEFT, TOP); textSize(11);
  text("Scan current within range at fixed voltage.", x + 5, y + 5);

  float col1 = x + 20, col2 = x + 300, sY = y + 45, gap = 55;
  drawSweepField(col1, sY,         "Fixed Voltage:", nf(csFixedVoltage,0,3), "V", 0, 2);
  drawSweepField(col1, sY+gap,     "Start Current:", nf(csStartCurrent,0,3), "A", 1, 2);
  drawSweepField(col1, sY+gap*2,   "End Current:",   nf(csEndCurrent,0,3),   "A", 2, 2);
  drawSweepField(col2, sY,         "Step Current:",  nf(csStepCurrent,0,3),  "A", 3, 2);
  drawSweepField(col2, sY+gap,     "Delay (sec):",   nf(csDelay,0,1),        "s", 4, 2);

  fill(COL_TEXT_DIM); textSize(9); textAlign(LEFT, TOP);
  text("A: 0-5  Step: 0.001-5  Delay: 1-86400s", col2, sY + gap * 2);

  drawSweepPreview(x+20, y+h-150, w-40, 130, csStartCurrent, csEndCurrent, csStepCurrent, csCurrentValue, advMode==2);
}

/// Sweep field label width (px)
static final float SF_LABEL_W = 110;
/// Sweep field input width (px)
static final float SF_FIELD_W = 140;
/// Sweep field input height (px)
static final float SF_FIELD_H = 28;

/**
 * @brief Draw a labeled input field for sweep parameters.
 *
 * @param x           Left edge of the field group (px)
 * @param y           Top edge of the field group (px)
 * @param label       Text label displayed to the left of the input
 * @param displayVal  Formatted value shown when not editing
 * @param suffix      Unit suffix string (e.g. "V", "A", "s")
 * @param fieldIdx    Index of this field within the sweep (0-4)
 * @param sweepType   Sweep type: 1 = voltage sweep, 2 = current sweep
 */
void drawSweepField(float x, float y, String label, String displayVal, String suffix, int fieldIdx, int sweepType) {
  boolean editing = (sweepType == 1 ? vsEditField : csEditField) == fieldIdx;

  fill(COL_TEXT); textAlign(RIGHT, CENTER); textSize(11);
  text(label, x + SF_LABEL_W - 5, y + SF_FIELD_H/2);

  fill(editing ? #0D1B2A : COL_INPUT_BG);
  stroke(editing ? COL_ACCENT : COL_INPUT_BORDER);
  strokeWeight(editing ? 1.5 : 1);
  rect(x + SF_LABEL_W, y, SF_FIELD_W, SF_FIELD_H, 3);

  fill(COL_TEXT); textAlign(LEFT, CENTER); textSize(13);
  String editBuf = (sweepType == 1) ? vsEditBuffer : csEditBuffer;
  String display = editing ? editBuf + (frameCount % 30 < 15 ? "|" : "") : displayVal;
  text(display + " " + suffix, x + SF_LABEL_W + 6, y + SF_FIELD_H/2);
}

// ============================================================
// SWEEP PREVIEW
// ============================================================

/**
 * @brief Draw the staircase preview graph for a sweep, with optional position marker.
 *
 * @param x           Left edge of the preview area (px)
 * @param y           Top edge of the preview area (px)
 * @param w           Width of the preview area (px)
 * @param h           Height of the preview area (px)
 * @param startVal    Sweep start value
 * @param endVal      Sweep end value
 * @param stepVal     Sweep step increment
 * @param currentVal  Current output value (for the position marker)
 * @param isActive    True if this sweep mode is currently selected and should show the marker
 */
void drawSweepPreview(float x, float y, float w, float h, float startVal, float endVal, float stepVal, float currentVal, boolean isActive) {
  fill(COL_GRAPH_BG); stroke(COL_BORDER); strokeWeight(1);
  rect(x, y, w, h, 3);
  fill(COL_TEXT_DIM); textAlign(LEFT, TOP); textSize(9);
  text("Preview", x + 5, y + 3);

  float gx = x + 35, gy = y + 18, gw = w - 45, gh = h - 28;

  stroke(COL_GRID); strokeWeight(0.5);
  for (int i = 0; i <= 4; i++) { float yy = gy + gh * i / 4.0; line(gx, yy, gx + gw, yy); }

  if (stepVal <= 0) stepVal = 0.01;
  int numSteps = min((int)(abs(endVal - startVal) / stepVal) + 1, 200);
  float minV = min(startVal, endVal), maxV = max(startVal, endVal);
  if (maxV <= minV) maxV = minV + 1;
  float range = maxV - minV;

  fill(COL_TEXT_DIM); textAlign(RIGHT, CENTER); textSize(8);
  for (int i = 0; i <= 4; i++) {
    float yy = gy + gh * i / 4.0;
    text(nf(maxV - range * ((float)i / 4.0), 0, 1), gx - 3, yy);
  }

  // Staircase
  stroke(COL_ACCENT_LITE); strokeWeight(1.5); noFill();
  boolean goingUp = (endVal >= startVal);
  beginShape();
  for (int i = 0; i < numSteps; i++) {
    float val = constrain(goingUp ? startVal + i * stepVal : startVal - i * stepVal, minV, maxV);
    float py = gy + gh * (1.0 - (val - minV) / range);
    vertex(gx + gw * ((float)i / numSteps), py);
    vertex(gx + gw * ((float)(i + 1) / numSteps), py);
  }
  endShape();

  // Position marker
  if (isActive && advState == ADV_RUNNING) {
    float markerY = constrain(gy + gh * (1.0 - (currentVal - minV) / range), gy, gy + gh);
    fill(COL_ON); noStroke(); ellipse(gx + gw / 2, markerY, 8, 8);
    fill(COL_ON, 40); ellipse(gx + gw / 2, markerY, 16, 16);
  }
}

// ============================================================
// EXECUTION ENGINE
// ============================================================

/**
 * @brief Per-frame update: advance the active sequence or sweep if running.
 */
void updateAdvanced() {
  if (advState != ADV_RUNNING || !psu.connected) return;
  long now = millis();
  switch (advMode) {
    case 0: updateSequentialOutput(now); break;
    case 1: case 2: updateSweep(now); break;
  }
}

/**
 * @brief Advance the sequential output state machine by one tick.
 *
 * @param now  Current timestamp in milliseconds
 */
void updateSequentialOutput(long now) {
  if (seqCurrentStep < 0) {
    seqCurrentStep = nextEnabledStep(-1);
    if (seqCurrentStep < 0) { advStop(); return; }
    applySequentialStep(seqCurrentStep);
    return;
  }
  if ((now - seqStepStartTime) >= (long)(seqDelay[seqCurrentStep] * 1000)) {
    seqStatus[seqCurrentStep] = 2;
    int nextStep = nextEnabledStep(seqCurrentStep);
    if (nextStep < 0) {
      seqCurrentLoop++;
      if (seqLoopCount > 0 && seqCurrentLoop >= seqLoopCount) {
        advStop(); setStatus("Sequence completed. " + seqCurrentLoop + " loop(s) done."); return;
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

/** Unified sweep update for both voltage and current sweeps. */
void updateSweep(long now) {
  boolean isVoltage = (advMode == 1);
  float delayMs = (isVoltage ? vsDelay : csDelay) * 1000;
  if ((now - advLastStepTime) < (long) delayMs) return;
  advLastStepTime = now;

  float curVal = isVoltage ? vsCurrentValue : csCurrentValue;
  float startV = isVoltage ? vsStartVoltage : csStartCurrent;
  float endV   = isVoltage ? vsEndVoltage   : csEndCurrent;
  float stepV  = isVoltage ? vsStepVoltage  : csStepCurrent;

  if (isVoltage) { psu.sendSetVoltage(curVal); psu.sendSetCurrent(vsFixedCurrent); }
  else           { psu.sendSetVoltage(csFixedVoltage); psu.sendSetCurrent(curVal); }
  if (!psu.outputOn) { psu.sendOutputOn(); psu.outputOn = true; }
  setStatus((isVoltage ? "V Sweep: " + nf(curVal, 0, 3) + "V" : "I Sweep: " + nf(curVal, 0, 3) + "A"));

  float nextVal = (startV <= endV) ? curVal + stepV : curVal - stepV;
  boolean done = (startV <= endV) ? (nextVal > endV + 0.0001) : (nextVal < endV - 0.0001);
  if (done) {
    advStop();
    setStatus((isVoltage ? "Voltage" : "Current") + " sweep completed.");
  } else {
    if (isVoltage) vsCurrentValue = nextVal; else csCurrentValue = nextVal;
  }
}

/**
 * @brief Apply voltage/current for a sequential step and turn output on.
 *
 * @param step  Index of the sequential step to apply
 */
void applySequentialStep(int step) {
  seqStatus[step] = 1;
  seqStepStartTime = millis();
  psu.sendSetVoltage(seqVoltage[step]);
  psu.sendSetCurrent(seqCurrent[step]);
  if (!psu.outputOn) { psu.sendOutputOn(); psu.outputOn = true; }
  setStatus("Seq step " + (step+1) + ": " + nf(seqVoltage[step],0,3) + "V / " + nf(seqCurrent[step],0,3) + "A");
}

/**
 * @brief Find the next enabled step after the given index.
 *
 * @param after  Index to search after (-1 to start from the beginning)
 * @return       Index of the next enabled step, or -1 if none found
 */
int nextEnabledStep(int after) {
  for (int i = after + 1; i < SEQ_MAX_ROWS; i++) if (seqEnabled[i]) return i;
  return -1;
}

/**
 * @brief Count the number of enabled steps in the sequential table.
 *
 * @return  Number of steps with seqEnabled[i] == true
 */
int countEnabledSteps() {
  int n = 0;
  for (int i = 0; i < SEQ_MAX_ROWS; i++) if (seqEnabled[i]) n++;
  return n;
}

/**
 * @brief Reset all step statuses to 'waiting'.
 */
void resetSeqStatus() { for (int i = 0; i < SEQ_MAX_ROWS; i++) seqStatus[i] = 0; }

// ============================================================
// START / PAUSE / CONTINUE / STOP
// ============================================================

/**
 * @brief Start execution in the current mode.
 */
void advStart() {
  if (!psu.connected) return;
  advState = ADV_RUNNING;
  switch (advMode) {
    case 0: resetSeqStatus(); seqCurrentStep = -1; seqCurrentLoop = 0; setStatus("Sequential output started."); break;
    case 1: vsCurrentValue = vsStartVoltage; advLastStepTime = millis() - (long)(vsDelay * 1000); setStatus("Voltage sweep started."); break;
    case 2: csCurrentValue = csStartCurrent; advLastStepTime = millis() - (long)(csDelay * 1000); setStatus("Current sweep started."); break;
  }
}

/**
 * @brief Pause execution.
 */
void advPause() { advState = ADV_PAUSED; setStatus("Advanced output paused."); }

/**
 * @brief Resume execution from a paused state.
 */
void advContinue() {
  if (advState != ADV_PAUSED) return;
  advState = ADV_RUNNING;
  if (advMode == 0 && seqCurrentStep >= 0) seqStepStartTime = millis();
  else advLastStepTime = millis();
  setStatus("Advanced output resumed.");
}

/**
 * @brief Stop execution and reset state.
 */
void advStop() {
  advState = ADV_IDLE;
  seqCurrentStep = -1;
  if (advMode == 0) resetSeqStatus();
  setStatus("Advanced output stopped.");
}

/**
 * @brief Execute a single step in sequential mode, then pause.
 */
void advSingleStep() {
  if (advMode != 0) return;
  if (advState == ADV_IDLE) {
    seqCurrentStep = nextEnabledStep(-1);
    if (seqCurrentStep < 0) return;
    seqCurrentLoop = 0; resetSeqStatus();
  } else if (advState == ADV_PAUSED) {
    seqStatus[seqCurrentStep] = 2;
    int next = nextEnabledStep(seqCurrentStep);
    if (next < 0) { advStop(); setStatus("Sequence completed (single step)."); return; }
    seqCurrentStep = next;
  }
  advState = ADV_PAUSED;
  applySequentialStep(seqCurrentStep);
  setStatus("Single step: " + (seqCurrentStep + 1));
}

// ============================================================
// INPUT HANDLING
// ============================================================

/**
 * @brief Process mouse clicks on the Advanced overlay: buttons, mode tabs, table cells, sweep fields.
 */
void handleAdvancedClick() {
  if (!advancedOpen) return;

  if (btnAdvClose.clicked()) {
    if (advState != ADV_IDLE) advStop();
    advancedOpen = false;
    return;
  }

  if (advState == ADV_IDLE) {
    if (btnAdvModeSeq.clicked()) advMode = 0;
    if (btnAdvModeVS.clicked())  advMode = 1;
    if (btnAdvModeCS.clicked())  advMode = 2;
  }

  if (btnLoopUp.clicked())   seqLoopCount = min(seqLoopCount + 1, 999);
  if (btnLoopDown.clicked()) seqLoopCount = max(seqLoopCount - 1, 0);

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
    vsEditField = -1; csEditField = -1; seqEditRow = -1; seqEditCol = -1;
  }

  if (advMode == 0) handleSeqTableClick();
  else handleSweepFieldClick(advMode == 1 ? 1 : 2);
}

/**
 * @brief Handle clicks within the sequential output table (checkboxes and editable cells).
 */
void handleSeqTableClick() {
  float tableY = advY + 64 + 26, rowH = 32;
  commitSeqEdit();
  seqEditRow = -1; seqEditCol = -1;

  for (int i = 0; i < SEQ_MAX_ROWS; i++) {
    float ry = tableY + i * rowH;
    if (mouseY < ry || mouseY > ry + rowH) continue;

    if (mouseX >= advX + 16 && mouseX <= advX + 32) { seqEnabled[i] = !seqEnabled[i]; return; }

    float vx = advX + 142;
    if (mouseX >= vx && mouseX <= vx + 110) { seqEditRow = i; seqEditCol = 0; seqEditBuffer = nf(seqVoltage[i], 0, 3); return; }
    float cx = advX + 262;
    if (mouseX >= cx && mouseX <= cx + 110) { seqEditRow = i; seqEditCol = 1; seqEditBuffer = nf(seqCurrent[i], 0, 3); return; }
    float dx = advX + 382;
    if (mouseX >= dx && mouseX <= dx + 90) { seqEditRow = i; seqEditCol = 2; seqEditBuffer = nf(seqDelay[i], 0, 1); return; }
  }
}

/**
 * @brief Commit the current table cell edit buffer to the corresponding data array.
 */
void commitSeqEdit() {
  if (seqEditRow < 0 || seqEditCol < 0) return;
  float val = 0;
  try { val = Float.parseFloat(seqEditBuffer); } catch (Exception e) { return; }
  switch (seqEditCol) {
    case 0: seqVoltage[seqEditRow] = constrain(val, 0, 30); break;
    case 1: seqCurrent[seqEditRow] = constrain(val, 0, 5); break;
    case 2: seqDelay[seqEditRow]   = constrain(val, 0.1, 86400); break;
  }
}

/**
 * @brief Handle clicks on sweep parameter input fields.
 *
 * @param sweepType  Sweep type: 1 = voltage sweep, 2 = current sweep
 */
void handleSweepFieldClick(int sweepType) {
  float x = advX + 8, sY = advY + 64 + 45, gap = 55;
  float col1 = x + 20 + SF_LABEL_W, col2 = x + 300 + SF_LABEL_W;

  commitSweepEdit(sweepType);
  if (sweepType == 1) vsEditField = -1; else csEditField = -1;

  float[][] positions = {{col1, sY}, {col1, sY+gap}, {col1, sY+gap*2}, {col2, sY}, {col2, sY+gap}};
  for (int f = 0; f < 5; f++) {
    if (mouseX >= positions[f][0] && mouseX <= positions[f][0] + SF_FIELD_W &&
        mouseY >= positions[f][1] && mouseY <= positions[f][1] + SF_FIELD_H) {
      if (sweepType == 1) { vsEditField = f; vsEditBuffer = getSweepFieldValue(1, f); }
      else                { csEditField = f; csEditBuffer = getSweepFieldValue(2, f); }
      return;
    }
  }
}

/**
 * @brief Return the current value string for a sweep field.
 *
 * @param type   Sweep type: 1 = voltage sweep, 2 = current sweep
 * @param field  Field index (0-4)
 * @return       Formatted numeric string for the requested field
 */
String getSweepFieldValue(int type, int field) {
  if (type == 1) {
    switch (field) {
      case 0: return nf(vsFixedCurrent, 0, 3);
      case 1: return nf(vsStartVoltage, 0, 3);
      case 2: return nf(vsEndVoltage, 0, 3);
      case 3: return nf(vsStepVoltage, 0, 3);
      case 4: return nf(vsDelay, 0, 1);
    }
  } else {
    switch (field) {
      case 0: return nf(csFixedVoltage, 0, 3);
      case 1: return nf(csStartCurrent, 0, 3);
      case 2: return nf(csEndCurrent, 0, 3);
      case 3: return nf(csStepCurrent, 0, 3);
      case 4: return nf(csDelay, 0, 1);
    }
  }
  return "0";
}

/**
 * @brief Commit the current sweep field edit to the corresponding variable.
 *
 * @param sweepType  Sweep type: 1 = voltage sweep, 2 = current sweep
 */
void commitSweepEdit(int sweepType) {
  int field = (sweepType == 1) ? vsEditField : csEditField;
  if (field < 0) return;
  String buf = (sweepType == 1) ? vsEditBuffer : csEditBuffer;
  float val;
  try { val = Float.parseFloat(buf); } catch (Exception e) { return; }

  if (sweepType == 1) {
    switch (field) {
      case 0: vsFixedCurrent = constrain(val, 0.001, 5); break;
      case 1: vsStartVoltage = constrain(val, 0, 30); break;
      case 2: vsEndVoltage   = constrain(val, 0, 30); break;
      case 3: vsStepVoltage  = constrain(val, 0.01, 30); break;
      case 4: vsDelay        = constrain(val, 1, 86400); break;
    }
    vsEditField = -1;
  } else {
    switch (field) {
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
// KEY HANDLING — shared numeric editor
// ============================================================

/** Edit a string buffer with numeric keys (digits + decimal point). Returns modified buffer or null if key wasn't handled. */
String editNumericBuffer(String buf, char k) {
  if (k == BACKSPACE || k == DELETE) {
    return buf.length() > 0 ? buf.substring(0, buf.length()-1) : buf;
  } else if ((k >= '0' && k <= '9') || k == '.') {
    if (k == '.' && buf.indexOf('.') >= 0) return buf;  // already has decimal
    if (buf.length() < 10) return buf + k;
  }
  return null;  // not a numeric key
}

/**
 * @brief Process keyboard input for the Advanced overlay: numeric editing, tab navigation, escape.
 *
 * @param k      The character of the key pressed
 * @param kCode  The key code of the key pressed
 */
void handleAdvancedKey(char k, int kCode) {
  if (!advancedOpen) return;

  // Sequential table editing
  if (advMode == 0 && seqEditRow >= 0 && seqEditCol >= 0) {
    String result = editNumericBuffer(seqEditBuffer, k);
    if (result != null) { seqEditBuffer = result; return; }
    if (k == ENTER || k == RETURN) { commitSeqEdit(); seqEditRow = -1; seqEditCol = -1; }
    else if (k == TAB) {
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

  // Sweep field editing (unified for V and I sweep)
  int editField = (advMode == 1) ? vsEditField : (advMode == 2) ? csEditField : -1;
  if (editField >= 0) {
    String buf = (advMode == 1) ? vsEditBuffer : csEditBuffer;
    String result = editNumericBuffer(buf, k);
    if (result != null) {
      if (advMode == 1) vsEditBuffer = result; else csEditBuffer = result;
      return;
    }
    if (k == ENTER || k == RETURN || k == TAB) commitSweepEdit(advMode);
    return;
  }

  if (k == ESC) {
    key = 0;
    if (advState != ADV_IDLE) advStop();
    advancedOpen = false;
  }
}
