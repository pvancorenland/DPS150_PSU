// GUI.pde — Full layout matching official Fnirsi software style
// Left: Gauges + graph | Right: Controls + presets + info

// ============================================================
// GUI WIDGETS
// ============================================================

// --- Connection bar ---
String[] availablePorts;
int selectedPortIndex = 0;
String selectedPortName = "";
Button btnPortPrev, btnPortNext;
Button btnConnect, btnDisconnect, btnRefreshPorts;

// --- Gauges ---
CircularGauge gaugeVoltage, gaugeCurrent;

// --- Digital readouts ---
DigitalReadout readoutPower, readoutSetV, readoutSetA;

// --- Graph ---
ScrollingGraph graph;
Button btnGraphV, btnGraphA, btnGraphW;

// --- Output toggle ---
ToggleButton btnOutput;

// --- Mode badges ---
StatusBadge badgeCV, badgeCC;

// --- Set controls ---
TextField tfSetVoltage, tfSetCurrent;
Button btnApply;
Button btnVoltUp, btnVoltDown, btnVoltUpFine, btnVoltDownFine;
Button btnCurrUp, btnCurrDown, btnCurrUpFine, btnCurrDownFine;

// --- Preset panel ---
Panel panelPresets;
Button[] btnPresetLoad = new Button[6];
Button[] btnPresetSave = new Button[6];

// --- Info panel ---
Panel panelInfo;
Button btnRefreshAll;

// --- Protection panel ---
Panel panelProtection;
TextField tfOVP, tfOCP, tfOPP, tfOTP;
Button btnApplyProtection;

// --- Brightness ---
Slider sliderBrightness;
Button btnApplyBrightness;

// --- Logging ---
Button btnStartLog, btnStopLog;

// --- Advanced window ---
Button btnOpenAdvanced;

// --- Status bar ---
String statusMessage = "Ready";
long statusTime = 0;
long outputToggleTime = 0;  // suppress poll overriding outputOn right after toggle

// ============================================================
// LAYOUT CONSTANTS
// ============================================================
static final int WIN_W = 1100;
static final int WIN_H = 720;
static final int TOP_BAR_H = 40;
static final int LEFT_W = 620;
static final int RIGHT_W = 470;

void setStatus(String msg) {
  statusMessage = msg;
  statusTime = millis();
}

// ============================================================
// INIT
// ============================================================
void initGUI() {
  // Scan ports
  refreshPorts();

  // --- Top bar ---
  btnPortPrev    = new Button(180, 8, 22, 24, "<");
  btnPortNext    = new Button(560, 8, 22, 24, ">");
  btnConnect     = new Button(600, 6, 90, 28, "Connect");
  btnConnect.bgColor = #1B5E20; btnConnect.hoverColor = #2E7D32;
  btnDisconnect  = new Button(698, 6, 90, 28, "Disconnect");
  btnDisconnect.bgColor = #7F1D1D; btnDisconnect.hoverColor = #B71C1C;
  btnRefreshPorts = new Button(796, 6, 70, 28, "Refresh");

  // --- Circular gauges ---
  gaugeVoltage = new CircularGauge(155, 175, 120, "OUTPUT VOLTAGE", "V", 0, 30, COL_VOLT, COL_VOLT_DIM);
  gaugeCurrent = new CircularGauge(430, 175, 120, "OUTPUT CURRENT", "A", 0, 5, COL_CURR, COL_CURR_DIM);
  gaugeCurrent.majorTicks = 5;

  // --- Digital readouts (below gauges) ---
  readoutPower = new DigitalReadout(180, 305, 200, 32, "W", "POWER", COL_POWER);
  readoutSetV  = new DigitalReadout(30, 305, 140, 32, "V", "SET", COL_VOLT);
  readoutSetA  = new DigitalReadout(400, 305, 140, 32, "A", "SET", COL_CURR);

  // --- Graph ---
  graph = new ScrollingGraph(15, 350, LEFT_W - 20, 230);
  btnGraphV = new Button(20, 585, 55, 20, "Voltage");
  btnGraphV.bgColor = COL_VOLT_DIM;
  btnGraphA = new Button(80, 585, 55, 20, "Current");
  btnGraphA.bgColor = COL_CURR_DIM;
  btnGraphW = new Button(140, 585, 50, 20, "Power");
  btnGraphW.bgColor = COL_POWER_DIM;

  // Logging buttons
  btnStartLog = new Button(350, 585, 80, 20, "Start Log");
  btnStartLog.bgColor = #1B5E20;
  btnStopLog  = new Button(440, 585, 75, 20, "Stop Log");
  btnStopLog.bgColor = #7F1D1D;

  // --- Right side: Output toggle ---
  float rx = LEFT_W + 15;
  btnOutput = new ToggleButton(rx, 50, RIGHT_W - 30, 52);

  // Mode badges
  badgeCV = new StatusBadge(rx, 108, 50, 22, "CV", COL_VOLT);
  badgeCC = new StatusBadge(rx + 56, 108, 50, 22, "CC", COL_CURR);

  // Protection status badge area (right of CV/CC)
  // (drawn inline in drawGUI)

  // --- Set controls ---
  float setY = 145;
  tfSetVoltage = new TextField(rx, setY + 18, 150, 30, "Set Voltage (0-30V)", "V");
  tfSetVoltage.maxVal = 30.0;
  tfSetCurrent = new TextField(rx + 230, setY + 18, 150, 30, "Set Current (0-5A)", "A");
  tfSetCurrent.maxVal = 5.0;

  btnVoltUp       = new Button(rx + 155, setY + 18, 30, 14, "+.1");
  btnVoltDown     = new Button(rx + 155, setY + 34, 30, 14, "-.1");
  btnVoltUpFine   = new Button(rx + 190, setY + 18, 30, 14, "+.01");
  btnVoltDownFine = new Button(rx + 190, setY + 34, 30, 14, "-.01");

  btnCurrUp       = new Button(rx + 385, setY + 18, 30, 14, "+.1");
  btnCurrDown     = new Button(rx + 385, setY + 34, 30, 14, "-.1");
  btnCurrUpFine   = new Button(rx + 420, setY + 18, 30, 14, "+.01");
  btnCurrDownFine = new Button(rx + 420, setY + 34, 30, 14, "-.01");

  btnApply = new Button(rx, setY + 55, RIGHT_W - 30, 30, "APPLY SETTINGS");
  btnApply.bgColor = #1B5E20; btnApply.hoverColor = #2E7D32;

  // --- Presets panel ---
  float presetY = setY + 95;
  panelPresets = new Panel(rx, presetY, RIGHT_W - 30, 175, "Express Data — Presets");
  for (int i = 0; i < 6; i++) {
    float px = panelPresets.contentX() + (i % 3) * 148;
    float py = panelPresets.contentY() + (i / 3) * 72;
    btnPresetLoad[i] = new Button(px + 85, py + 2, 45, 18, "Load");
    btnPresetLoad[i].bgColor = #1A3A5C;
    btnPresetSave[i] = new Button(px + 85, py + 24, 45, 18, "Save");
    btnPresetSave[i].bgColor = #3A2A1A;
  }

  // --- Info panel ---
  float infoY = presetY + 185;
  panelInfo = new Panel(rx, infoY, (RIGHT_W - 40)/2, 175, "Device Info");
  btnRefreshAll = new Button(rx + 5, infoY + 150, 80, 20, "Refresh All");

  // --- Protection panel ---
  panelProtection = new Panel(rx + (RIGHT_W - 40)/2 + 10, infoY, (RIGHT_W - 40)/2, 175, "Protection");
  float px2 = panelProtection.contentX();
  float py2 = panelProtection.contentY();
  tfOVP = new TextField(px2, py2 + 14, 90, 22, "OVP (V)", "V");
  tfOVP.maxVal = 33;
  tfOCP = new TextField(px2, py2 + 56, 90, 22, "OCP (A)", "A");
  tfOCP.maxVal = 5.5;
  tfOPP = new TextField(px2, py2 + 98, 90, 22, "OPP (W)", "W");
  tfOPP.maxVal = 160;
  tfOTP = new TextField(px2 + 110, py2 + 14, 80, 22, "OTP (C)", "C");
  tfOTP.maxVal = 80;
  btnApplyProtection = new Button(px2 + 110, py2 + 56, 80, 22, "Apply");
  btnApplyProtection.bgColor = #1B5E20;

  // Brightness slider
  sliderBrightness = new Slider(px2 + 110, py2 + 108, 80, 16, "Brightness", 0, 20);
  btnApplyBrightness = new Button(px2 + 110, py2 + 130, 80, 18, "Set");
  btnApplyBrightness.bgColor = #1B5E20;

  // Advanced button (top bar, far right)
  btnOpenAdvanced = new Button(WIN_W - 100, 6, 90, 28, "Advanced");
  btnOpenAdvanced.bgColor = #4A148C;
  btnOpenAdvanced.hoverColor = #7B1FA2;

  // Init advanced window
  initAdvanced();
}

void refreshPorts() {
  availablePorts = Serial.list();
  selectedPortIndex = 0;
  for (int i = 0; i < availablePorts.length; i++) {
    if (availablePorts[i].contains("cu.usbmodem14798A3C")) {
      selectedPortIndex = i;
      break;
    }
  }
  if (availablePorts.length > 0) {
    selectedPortName = availablePorts[selectedPortIndex];
  } else {
    selectedPortName = "";
  }
}

// ============================================================
// DRAW
// ============================================================
void drawGUI() {
  background(COL_BG);

  // ---- TOP BAR ----
  fill(COL_PANEL);
  noStroke();
  rect(0, 0, WIN_W, TOP_BAR_H);
  // Bottom edge line
  stroke(COL_BORDER);
  strokeWeight(1);
  line(0, TOP_BAR_H, WIN_W, TOP_BAR_H);

  // Connection LED
  float ledPulse = psu.connected ? (sin(millis() * 0.005) * 0.3 + 0.7) : 0.3;
  fill(psu.connected ? color(COL_ON, (int)(255*ledPulse)) : #661111);
  noStroke();
  ellipse(14, 20, 10, 10);
  if (psu.connected) {
    fill(COL_ON, 30);
    ellipse(14, 20, 20, 20);
  }

  // Port display
  fill(COL_TEXT);
  textAlign(LEFT, CENTER);
  textSize(11);
  if (psu.connected) {
    text("Connected: " + psu.connectedPortName, 26, 20);
  } else {
    text("Port:", 26, 20);
    fill(COL_INPUT_BG);
    stroke(COL_INPUT_BORDER);
    rect(206, 8, 350, 24, 3);
    fill(COL_TEXT);
    noStroke();
    textAlign(CENTER, CENTER);
    textSize(10);
    String pName = (availablePorts.length > 0) ? availablePorts[selectedPortIndex] : "(no ports found)";
    text(pName, 381, 20);
    btnPortPrev.draw();
    btnPortNext.draw();
  }
  btnConnect.enabled = !psu.connected && availablePorts.length > 0;
  btnDisconnect.enabled = psu.connected;
  btnConnect.draw();
  btnDisconnect.draw();
  if (!psu.connected) btnRefreshPorts.draw();
  if (psu.connected) btnOpenAdvanced.draw();

  // ---- DISCONNECTED STATE ----
  if (!psu.connected) {
    fill(COL_TEXT_DIM);
    textAlign(CENTER, CENTER);
    textSize(18);
    text("FNIRSI DPS-150 Power Supply Control", WIN_W / 2, WIN_H / 2 - 30);
    textSize(12);
    text("Select a serial port and click Connect", WIN_W / 2, WIN_H / 2 + 10);
  }

  // ---- CONNECTED: full GUI ----
  if (psu.connected) {

  // ---- LEFT SIDE: Gauges ----
  // Subtle divider
  stroke(COL_BORDER);
  strokeWeight(1);
  line(LEFT_W + 5, TOP_BAR_H + 5, LEFT_W + 5, WIN_H - 5);

  // Gauge background panels
  fill(COL_PANEL, 80);
  noStroke();
  rect(10, TOP_BAR_H + 8, LEFT_W - 15, 255, 6);

  gaugeVoltage.value = psu.liveVoltage;
  gaugeCurrent.value = psu.liveCurrent;
  gaugeVoltage.draw();
  gaugeCurrent.draw();

  // Digital readouts
  readoutPower.setValue(psu.livePower, 3, 2);
  readoutSetV.setValue(psu.setVoltage, 2, 3);
  readoutSetA.setValue(psu.setCurrent, 1, 3);
  readoutPower.draw();
  readoutSetV.draw();
  readoutSetA.draw();

  // ---- Graph ----
  graph.draw();

  // Graph toggle buttons
  btnGraphV.bgColor = graph.showVoltage ? COL_VOLT_DIM : #2A2A35;
  btnGraphA.bgColor = graph.showCurrent ? COL_CURR_DIM : #2A2A35;
  btnGraphW.bgColor = graph.showPower   ? COL_POWER_DIM : #2A2A35;
  btnGraphV.draw();
  btnGraphA.draw();
  btnGraphW.draw();

  // Logging buttons
  btnStartLog.enabled = !psu.logging;
  btnStopLog.enabled = psu.logging;
  btnStartLog.draw();
  btnStopLog.draw();

  // Logging status
  if (psu.logging) {
    fill(COL_OFF);
    float blink = sin(millis() * 0.008) > 0 ? 255 : 100;
    fill(color(255, 50, 50, (int)blink));
    noStroke();
    ellipse(535, 595, 8, 8);
    fill(COL_TEXT_DIM);
    textAlign(LEFT, CENTER);
    textSize(9);
    text("REC " + psu.logSampleCount + " samples", 542, 595);
  }

  // ---- RIGHT SIDE ----
  float rx = LEFT_W + 15;

  // Output toggle
  btnOutput.state = psu.outputOn;
  btnOutput.draw();

  // CV/CC badges
  badgeCV.active = (psu.outputMode == MODE_CV);
  badgeCC.active = (psu.outputMode == MODE_CC);
  badgeCV.draw();
  badgeCC.draw();

  // Protection status
  if (psu.protectionStatus != PROT_OK) {
    fill(COL_OFF);
    textAlign(LEFT, CENTER);
    textSize(12);
    text(psu.protectionStatusText(), rx + 120, 119);
  } else {
    fill(COL_ON, 150);
    textAlign(LEFT, CENTER);
    textSize(10);
    text("Normal", rx + 120, 119);
  }

  // --- Set controls ---
  tfSetVoltage.draw();
  tfSetCurrent.draw();
  btnVoltUp.draw(); btnVoltDown.draw();
  btnVoltUpFine.draw(); btnVoltDownFine.draw();
  btnCurrUp.draw(); btnCurrDown.draw();
  btnCurrUpFine.draw(); btnCurrDownFine.draw();
  btnApply.draw();

  // --- Presets ---
  panelPresets.draw();
  for (int i = 0; i < 6; i++) {
    float ppx = panelPresets.contentX() + (i % 3) * 148;
    float ppy = panelPresets.contentY() + (i / 3) * 72;

    // Preset card
    fill(COL_PANEL_LITE);
    stroke(COL_BORDER);
    strokeWeight(0.5);
    rect(ppx, ppy, 140, 65, 3);

    // Preset number
    fill(COL_ACCENT);
    textAlign(LEFT, TOP);
    textSize(10);
    text("P" + (i+1), ppx + 5, ppy + 4);

    // Values
    fill(COL_VOLT);
    textSize(13);
    text(nf(psu.presetV[i], 0, 2) + " V", ppx + 5, ppy + 20);
    fill(COL_CURR);
    text(nf(psu.presetA[i], 0, 2) + " A", ppx + 5, ppy + 40);

    btnPresetLoad[i].draw();
    btnPresetSave[i].draw();
  }

  // --- Info panel ---
  panelInfo.draw();
  float ix = panelInfo.contentX();
  float iy = panelInfo.contentY();
  fill(COL_TEXT_DIM);
  textAlign(LEFT, TOP);
  textSize(10);
  text("Input V:", ix, iy);
  fill(COL_TEXT); text(nf(psu.inputVoltage, 0, 2) + " V", ix + 75, iy);
  iy += 16;
  fill(COL_TEXT_DIM); text("Temperature:", ix, iy);
  fill(COL_TEXT); text(nf(psu.temperature, 0, 1) + " C", ix + 75, iy);
  iy += 16;
  fill(COL_TEXT_DIM); text("Max Voltage:", ix, iy);
  fill(COL_TEXT); text(nf(psu.maxVoltage, 0, 1) + " V", ix + 75, iy);
  iy += 14;
  fill(COL_TEXT_DIM); text("Max Current:", ix, iy);
  fill(COL_TEXT); text(nf(psu.maxCurrent, 0, 1) + " A", ix + 75, iy);
  iy += 14;
  fill(COL_TEXT_DIM); text("Device:", ix, iy);
  fill(COL_TEXT); text(psu.deviceId.length() > 0 ? psu.deviceId : "--", ix + 75, iy);
  iy += 14;
  fill(COL_TEXT_DIM); text("Mode:", ix, iy);
  fill(psu.outputMode == MODE_CV ? COL_VOLT : COL_CURR);
  text(psu.outputMode == MODE_CV ? "CV" : "CC", ix + 75, iy);
  btnRefreshAll.draw();

  // --- Protection panel ---
  panelProtection.draw();
  tfOVP.draw(); tfOCP.draw(); tfOPP.draw(); tfOTP.draw();
  btnApplyProtection.draw();
  sliderBrightness.value = psu.brightness;
  sliderBrightness.draw();
  btnApplyBrightness.draw();

  } // end if (psu.connected)

  // ---- STATUS BAR ----
  fill(COL_PANEL);
  noStroke();
  rect(0, WIN_H - 22, WIN_W, 22);
  stroke(COL_BORDER);
  line(0, WIN_H - 22, WIN_W, WIN_H - 22);
  fill(COL_TEXT_DIM);
  textAlign(LEFT, CENTER);
  textSize(10);
  text(statusMessage, 8, WIN_H - 11);

  // Right side of status bar
  fill(COL_TEXT_DIM);
  textAlign(RIGHT, CENTER);
  text("DPS-150 Control  |  " + nf(frameRate, 0, 0) + " fps", WIN_W - 10, WIN_H - 11);

  // ---- ADVANCED OVERLAY (drawn last, on top) ----
  drawAdvanced();
  updateAdvanced();
}

// ============================================================
// INPUT HANDLING
// ============================================================
void handleGUIClick() {
  // --- Advanced window (handles its own clicks when open) ---
  if (advancedOpen) {
    handleAdvancedClick();
    return;  // block clicks to main GUI while advanced is open
  }

  // --- Advanced button ---
  if (btnOpenAdvanced.clicked()) {
    advancedOpen = true;
    return;
  }

  // --- Top bar ---
  if (!psu.connected) {
    if (btnPortPrev.clicked() && selectedPortIndex > 0) {
      selectedPortIndex--;
      selectedPortName = availablePorts[selectedPortIndex];
    }
    if (btnPortNext.clicked() && selectedPortIndex < availablePorts.length - 1) {
      selectedPortIndex++;
      selectedPortName = availablePorts[selectedPortIndex];
    }
    if (btnRefreshPorts.clicked()) {
      refreshPorts();
      setStatus("Ports refreshed. Found " + availablePorts.length + " port(s).");
    }
  }

  if (btnConnect.clicked() && availablePorts.length > 0) {
    setStatus("Connecting to " + availablePorts[selectedPortIndex] + "...");
    if (psu.connectToPort(availablePorts[selectedPortIndex])) {
      setStatus("Connected to " + psu.connectedPortName + " — Set V/A values and click Apply.");
    } else {
      setStatus("Connection failed!");
    }
  }
  if (btnDisconnect.clicked()) {
    psu.disconnectFromPSU();
    setStatus("Disconnected.");
  }

  // --- Output toggle ---
  if (psu.connected && btnOutput.clicked()) {
    println("OUTPUT CLICK: outputOn=" + psu.outputOn + " -> " + !psu.outputOn);
    if (psu.outputOn) { psu.sendOutputOff(); psu.outputOn = false; setStatus("Output OFF"); }
    else { psu.sendOutputOn(); psu.outputOn = true; setStatus("Output ON"); }
    outputToggleTime = millis();
  }

  // --- Text field focus ---
  boolean anyProtFocused = false;
  tfSetVoltage.focused = tfSetVoltage.clicked();
  tfSetCurrent.focused = tfSetCurrent.clicked();

  // --- Voltage / Current adjust ---
  if (btnVoltUp.clicked())       adjustField(tfSetVoltage, 0.1);
  if (btnVoltDown.clicked())     adjustField(tfSetVoltage, -0.1);
  if (btnVoltUpFine.clicked())   adjustField(tfSetVoltage, 0.01);
  if (btnVoltDownFine.clicked()) adjustField(tfSetVoltage, -0.01);
  if (btnCurrUp.clicked())       adjustField(tfSetCurrent, 0.1);
  if (btnCurrDown.clicked())     adjustField(tfSetCurrent, -0.1);
  if (btnCurrUpFine.clicked())   adjustField(tfSetCurrent, 0.01);
  if (btnCurrDownFine.clicked()) adjustField(tfSetCurrent, -0.01);

  // --- Apply ---
  if (btnApply.clicked() && psu.connected) {
    float v = constrain(tfSetVoltage.getFloat(), 0, psu.maxVoltage);
    float a = tfSetCurrent.getFloat();
    // Don't send 0A — use existing setCurrent if field is empty
    if (a < 0.001 && tfSetCurrent.value.length() == 0) {
      a = psu.setCurrent;
    }
    a = constrain(a, 0, psu.maxCurrent);
    psu.sendSetVoltage(v);
    delay(100);  // PSU needs time between commands
    psu.sendSetCurrent(a);
    // Update local state immediately so displays reflect the change
    psu.setVoltage = v;
    psu.setCurrent = a;
    tfSetVoltage.setFloat(v);
    tfSetCurrent.setFloat(a);
    println("APPLY: V=" + nf(v,0,3) + " A=" + nf(a,0,3));
    setStatus("Applied: " + nf(v,0,3) + "V / " + nf(a,0,3) + "A");
  }

  // --- Presets ---
  for (int i = 0; i < 6; i++) {
    if (btnPresetLoad[i].clicked() && psu.connected) {
      psu.sendLoadPreset(i);
      tfSetVoltage.setFloat(psu.presetV[i]);
      tfSetCurrent.setFloat(psu.presetA[i]);
      setStatus("Loaded preset " + (i+1));
    }
    if (btnPresetSave[i].clicked() && psu.connected) {
      float v = tfSetVoltage.getFloat();
      float a = tfSetCurrent.getFloat();
      psu.sendSavePreset(i, v, a);
      psu.presetV[i] = v;
      psu.presetA[i] = a;
      setStatus("Saved preset " + (i+1) + ": " + nf(v,0,2) + "V / " + nf(a,0,2) + "A");
    }
  }

  // --- Info refresh ---
  if (btnRefreshAll.clicked() && psu.connected) {
    psu.gotFirstSetpoint = false;
    psu.sendReadRegister(REG_ALL);
    setStatus("Refreshing all parameters...");
  }

  // --- Protection ---
  if (tfOVP.clicked()) { tfOVP.focused = true; anyProtFocused = true; }
  if (tfOCP.clicked()) { tfOCP.focused = true; anyProtFocused = true; }
  if (tfOPP.clicked()) { tfOPP.focused = true; anyProtFocused = true; }
  if (tfOTP.clicked()) { tfOTP.focused = true; anyProtFocused = true; }
  if (anyProtFocused) {
    tfSetVoltage.focused = false;
    tfSetCurrent.focused = false;
  }

  if (btnApplyProtection.clicked() && psu.connected) {
    psu.sendSetOVP(tfOVP.getFloat());
    psu.sendSetOCP(tfOCP.getFloat());
    psu.sendSetOPP(tfOPP.getFloat());
    psu.sendSetOTP(tfOTP.getFloat());
    setStatus("Protection limits applied.");
  }

  // --- Brightness ---
  if (sliderBrightness.pressedOn()) sliderBrightness.dragging = true;
  if (btnApplyBrightness.clicked() && psu.connected) {
    psu.brightness = (int) sliderBrightness.value;
    psu.sendSetBrightness(psu.brightness);
    setStatus("Brightness set to " + psu.brightness);
  }

  // --- Graph toggles ---
  if (btnGraphV.clicked()) graph.showVoltage = !graph.showVoltage;
  if (btnGraphA.clicked()) graph.showCurrent = !graph.showCurrent;
  if (btnGraphW.clicked()) graph.showPower   = !graph.showPower;

  // --- Logging ---
  if (btnStartLog.clicked() && psu.connected && !psu.logging) {
    psu.startLogging();
    setStatus("Logging started: " + psu.logFileName);
  }
  if (btnStopLog.clicked() && psu.logging) {
    psu.stopLogging();
    setStatus("Logging stopped. " + psu.logSampleCount + " samples saved.");
  }
}

void handleGUIRelease() {
  sliderBrightness.dragging = false;
}

void handleGUIKey(char k, int kCode) {
  // Advanced window gets keys first
  if (advancedOpen) {
    handleAdvancedKey(k, kCode);
    return;
  }

  tfSetVoltage.handleKey(k, kCode);
  tfSetCurrent.handleKey(k, kCode);
  tfOVP.handleKey(k, kCode);
  tfOCP.handleKey(k, kCode);
  tfOPP.handleKey(k, kCode);
  tfOTP.handleKey(k, kCode);

  // Enter to apply
  if (k == ENTER || k == RETURN) {
    if ((tfSetVoltage.focused || tfSetCurrent.focused) && psu.connected) {
      float v = constrain(tfSetVoltage.getFloat(), 0, psu.maxVoltage);
      float a = tfSetCurrent.getFloat();
      if (a < 0.001 && tfSetCurrent.value.length() == 0) a = psu.setCurrent;
      a = constrain(a, 0, psu.maxCurrent);
      psu.sendSetVoltage(v);
      delay(100);  // PSU needs time between commands
      psu.sendSetCurrent(a);
      psu.setVoltage = v;
      psu.setCurrent = a;
      tfSetVoltage.setFloat(v);
      tfSetCurrent.setFloat(a);
      println("APPLY (Enter): V=" + nf(v,0,3) + " A=" + nf(a,0,3));
      setStatus("Applied: " + nf(v,0,3) + "V / " + nf(a,0,3) + "A");
    }
  }
}

// Called when setpoints are received from PSU (after connect or ALL dump)
void onSetpointsReceived() {
  tfSetVoltage.setFloat(psu.setVoltage);
  tfSetCurrent.setFloat(psu.setCurrent);
  tfOVP.setFloat(psu.ovpLimit);
  tfOCP.setFloat(psu.ocpLimit);
  tfOPP.setFloat(psu.oppLimit);
  tfOTP.setFloat(psu.otpLimit);
  println("Setpoints received: V=" + nf(psu.setVoltage, 0, 3) + " A=" + nf(psu.setCurrent, 0, 3));
  setStatus("Set: " + nf(psu.setVoltage, 0, 3) + "V / " + nf(psu.setCurrent, 0, 3) + "A");
}

void adjustField(TextField tf, float delta) {
  float val = constrain(tf.getFloat() + delta, tf.minVal, tf.maxVal);
  tf.setFloat(val);
}

// ============================================================
// MOUSE WHEEL for graph zoom
// ============================================================
void handleMouseWheel(float e) {
  // Zoom voltage scale with mouse wheel when over graph
  if (mouseX >= graph.x && mouseX <= graph.x + graph.w &&
      mouseY >= graph.y && mouseY <= graph.y + graph.h) {
    if (e > 0) {
      graph.voltScale = min(graph.voltScale * 1.2, 60);
      graph.currScale = min(graph.currScale * 1.2, 20);
    } else {
      graph.voltScale = max(graph.voltScale / 1.2, 1);
      graph.currScale = max(graph.currScale / 1.2, 0.1);
    }
  }
}
