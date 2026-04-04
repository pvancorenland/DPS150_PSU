/**
 * @file GUI.pde
 * @brief Full GUI layout matching the official Fnirsi PC software style.
 *
 * Interactive widgets use ControlP5; display-only widgets are custom.
 */

// ============================================================
// GUI WIDGETS — Display-only (custom)
// ============================================================

String[] availablePorts;
int selectedPortIndex = 0;
String selectedPortName = "";

CircularGauge gaugeVoltage, gaugeCurrent;
Slider sliderVset, sliderIset;
DigitalReadout readoutPower, readoutSetV, readoutSetA;
ScrollingGraph graph;
StatusBadge badgeCV, badgeCC;
Panel panelPresets, panelInfo, panelProtection;

String statusMessage = "Ready";
long statusTime = 0;
long outputToggleTime = 0;

// ============================================================
// LAYOUT CONSTANTS
// ============================================================
static final int WIN_W = 1100, WIN_H = 720;
static final int TOP_BAR_H = 40, LEFT_W = 620, RIGHT_W = 470;

// ============================================================
// Cached CP5 controller references (avoid per-frame string lookups)
// ============================================================
Group grpConnected;
Controller cPortPrev, cPortNext, cConnToggle, cRefreshPorts, cOpenAdvanced;
Controller cGraphV, cGraphA, cGraphW, cStartLog, cStopLog;
Toggle cOutput;
Textfield cTfSetV, cTfSetA, cTfOVP, cTfOCP, cTfOPP, cTfOTP;
Slider cBrightness;

// Previous state — avoid redundant updates every frame
boolean prevShowV = true, prevShowA = true, prevShowW = false;
boolean prevConnState = false;

void setStatus(String msg) {
  statusMessage = msg;
  statusTime = millis();
}

// ============================================================
// THEME HELPERS
// ============================================================

void applyTheme(Controller c, int bg, int fg, int active) {
  c.setColorBackground(bg);
  c.setColorForeground(fg);
  c.setColorActive(active);
  c.setColorCaptionLabel(color(0xE0, 0xE0, 0xE8));
}

// Pre-computed theme colors
static final int TH_DARK_BG = 0xFF2E3B55, TH_DARK_FG = 0xFF3D5070, TH_DARK_ACT = 0xFF4A6590;
static final int TH_GREEN_BG = 0xFF1B5E20, TH_GREEN_FG = 0xFF2E7D32, TH_GREEN_ACT = 0xFF43A047;
static final int TH_RED_BG = 0xFF7F1D1D, TH_RED_FG = 0xFFB71C1C, TH_RED_ACT = 0xFFD32F2F;

void applyDarkTheme(Controller c)  { applyTheme(c, TH_DARK_BG, TH_DARK_FG, TH_DARK_ACT); }
void applyGreenTheme(Controller c) { applyTheme(c, TH_GREEN_BG, TH_GREEN_FG, TH_GREEN_ACT); }
void applyRedTheme(Controller c)   { applyTheme(c, TH_RED_BG, TH_RED_FG, TH_RED_ACT); }

void styleCp5Textfield(Textfield tf) {
  tf.setColorBackground(color(0x17, 0x17, 0x22));
  tf.setColorForeground(color(0x4A, 0x90, 0xD9));
  tf.setColorActive(color(0x4A, 0x90, 0xD9));
  tf.setColorCaptionLabel(color(0x88, 0x88, 0x99));
  tf.setColorValueLabel(color(0xE0, 0xE0, 0xE8));
  tf.setAutoClear(false);
}

// ============================================================
// INIT
// ============================================================

void initGUI() {
  refreshPorts();

  Controller c;

  // --- Top bar ---
  cPortPrev = cp5.addButton("btnPortPrev").setPosition(180, 8).setSize(22, 24).setLabel("<");
  applyDarkTheme(cPortPrev);
  cPortNext = cp5.addButton("btnPortNext").setPosition(560, 8).setSize(22, 24).setLabel(">");
  applyDarkTheme(cPortNext);
  cConnToggle = cp5.addButton("btnConnToggle").setPosition(600, 6).setSize(90, 28).setLabel("Connect");
  applyGreenTheme(cConnToggle);
  cRefreshPorts = cp5.addButton("btnRefreshPorts").setPosition(796, 6).setSize(70, 28).setLabel("Refresh");
  applyDarkTheme(cRefreshPorts);
  cOpenAdvanced = cp5.addButton("btnOpenAdvanced").setPosition(WIN_W - 100, 6).setSize(90, 28).setLabel("Advanced");
  applyTheme(cOpenAdvanced, 0xFF4A148C, 0xFF7B1FA2, 0xFF9C27B0);

  // --- Connected-only group ---
  grpConnected = cp5.addGroup("grpConnected").setPosition(0, 0).setSize(WIN_W, WIN_H).hideBar().hide();

  // --- Gauges ---
  gaugeVoltage = new CircularGauge(155, 175, 120, "OUTPUT VOLTAGE", "V", 0, 30, COL_VOLT, COL_VOLT_DIM);
  gaugeCurrent = new CircularGauge(430, 175, 120, "OUTPUT CURRENT", "A", 0, 5, COL_CURR, COL_CURR_DIM);
  gaugeCurrent.majorTicks = 5;
  sliderVset = cp5.addSlider("sliderVset").setPosition(278, 70).setSize(24, 220)
    .setRange(0, 30).setValue(0).setLabel("Vset").setGroup(grpConnected);
  sliderVset.setColorBackground(color(0x1A, 0x1A, 0x25));
  sliderVset.setColorForeground(COL_VOLT);
  sliderVset.setColorActive(COL_VOLT);
  sliderIset = cp5.addSlider("sliderIset").setPosition(553, 70).setSize(24, 220)
    .setRange(0, 5).setValue(0).setLabel("Iset").setGroup(grpConnected);
  sliderIset.setColorBackground(color(0x1A, 0x1A, 0x25));
  sliderIset.setColorForeground(COL_CURR);
  sliderIset.setColorActive(COL_CURR);

  // --- Readouts ---
  readoutPower = new DigitalReadout(180, 305, 200, 32, "W", "POWER", COL_POWER);
  readoutSetV  = new DigitalReadout(30, 305, 140, 32, "V", "SET", COL_VOLT);
  readoutSetA  = new DigitalReadout(400, 305, 140, 32, "A", "SET", COL_CURR);

  // --- Graph ---
  graph = new ScrollingGraph(15, 350, LEFT_W - 20, 230);

  cGraphV = cp5.addButton("btnGraphV").setPosition(20, 585).setSize(55, 20).setLabel("Voltage").setGroup(grpConnected);
  applyTheme(cGraphV, 0xFF664D00, 0xFF806000, 0xFF997300);
  cGraphA = cp5.addButton("btnGraphA").setPosition(80, 585).setSize(55, 20).setLabel("Current").setGroup(grpConnected);
  applyTheme(cGraphA, 0xFF005662, 0xFF00707D, 0xFF008A98);
  cGraphW = cp5.addButton("btnGraphW").setPosition(140, 585).setSize(50, 20).setLabel("Power").setGroup(grpConnected);
  applyTheme(cGraphW, 0xFF1B5E20, 0xFF2E7D32, 0xFF43A047);

  cStartLog = cp5.addButton("btnStartLog").setPosition(350, 585).setSize(80, 20).setLabel("Start Log").setGroup(grpConnected);
  applyGreenTheme(cStartLog);
  cStopLog = cp5.addButton("btnStopLog").setPosition(440, 585).setSize(75, 20).setLabel("Stop Log").setGroup(grpConnected);
  applyRedTheme(cStopLog);

  // --- Output toggle ---
  float rx = LEFT_W + 15;
  cOutput = (Toggle) cp5.addToggle("btnOutput").setPosition(rx, 50).setSize((int)(RIGHT_W - 30), 52)
    .setValue(false).setGroup(grpConnected);
  cOutput.setColorBackground(color(0x3E, 0x1A, 0x1A));
  cOutput.setColorForeground(color(0x00, 0xE6, 0x76));
  cOutput.setColorActive(color(0x1B, 0x43, 0x32));
  cOutput.setColorCaptionLabel(color(0xE0, 0xE0, 0xE8));
  cOutput.getCaptionLabel().setText("OUTPUT").align(ControlP5.CENTER, ControlP5.CENTER);

  badgeCV = new StatusBadge(rx, 108, 50, 22, "CV", COL_VOLT);
  badgeCC = new StatusBadge(rx + 56, 108, 50, 22, "CC", COL_CURR);

  // --- Set controls ---
  float setY = 145;
  cTfSetV = cp5.addTextfield("tfSetVoltage").setPosition(rx, setY + 18).setSize(150, 30)
    .setLabel("Set Voltage (0-30V)").setGroup(grpConnected);
  styleCp5Textfield(cTfSetV);
  cTfSetA = cp5.addTextfield("tfSetCurrent").setPosition(rx + 230, setY + 18).setSize(150, 30)
    .setLabel("Set Current (0-5A)").setGroup(grpConnected);
  styleCp5Textfield(cTfSetA);

  int[][] adjBtns = {
    {(int)(rx+155), (int)(setY+18), 30, 14},  // voltUp
    {(int)(rx+155), (int)(setY+34), 30, 14},  // voltDown
    {(int)(rx+190), (int)(setY+18), 30, 14},  // voltUpFine
    {(int)(rx+190), (int)(setY+34), 30, 14},  // voltDownFine
    {(int)(rx+385), (int)(setY+18), 30, 14},  // currUp
    {(int)(rx+385), (int)(setY+34), 30, 14},  // currDown
    {(int)(rx+420), (int)(setY+18), 30, 14},  // currUpFine
    {(int)(rx+420), (int)(setY+34), 30, 14},  // currDownFine
  };
  String[] adjNames = {"btnVoltUp","btnVoltDown","btnVoltUpFine","btnVoltDownFine",
                       "btnCurrUp","btnCurrDown","btnCurrUpFine","btnCurrDownFine"};
  String[] adjLabels = {"+.1","-.1","+.01","-.01","+.1","-.1","+.01","-.01"};
  for (int i = 0; i < 8; i++) {
    c = cp5.addButton(adjNames[i]).setPosition(adjBtns[i][0], adjBtns[i][1])
      .setSize(adjBtns[i][2], adjBtns[i][3]).setLabel(adjLabels[i]).setGroup(grpConnected);
    applyDarkTheme(c);
  }

  c = cp5.addButton("btnApply").setPosition(rx, setY + 55).setSize((int)(RIGHT_W - 30), 30)
    .setLabel("APPLY SETTINGS").setGroup(grpConnected);
  applyGreenTheme(c);

  // --- Presets ---
  float presetY = setY + 95;
  panelPresets = new Panel(rx, presetY, RIGHT_W - 30, 175, "Express Data — Presets");
  for (int i = 0; i < 6; i++) {
    float px = panelPresets.contentX() + (i % 3) * 148;
    float py = panelPresets.contentY() + (i / 3) * 72;
    c = cp5.addButton("btnPresetLoad" + i).setPosition(px + 85, py + 2).setSize(45, 18).setLabel("Load").setGroup(grpConnected);
    applyTheme(c, 0xFF1A3A5C, 0xFF255078, 0xFF306694);
    c = cp5.addButton("btnPresetSave" + i).setPosition(px + 85, py + 24).setSize(45, 18).setLabel("Save").setGroup(grpConnected);
    applyTheme(c, 0xFF3A2A1A, 0xFF503A25, 0xFF664A30);
  }

  // --- Info panel ---
  float infoY = presetY + 185;
  panelInfo = new Panel(rx, infoY, (RIGHT_W - 40)/2, 175, "Device Info");
  c = cp5.addButton("btnRefreshAll").setPosition(rx + 5, infoY + 150).setSize(80, 20).setLabel("Refresh All").setGroup(grpConnected);
  applyDarkTheme(c);

  // --- Protection panel ---
  panelProtection = new Panel(rx + (RIGHT_W - 40)/2 + 10, infoY, (RIGHT_W - 40)/2, 175, "Protection");
  float px2 = panelProtection.contentX();
  float py2 = panelProtection.contentY();

  cTfOVP = cp5.addTextfield("tfOVP").setPosition(px2, py2 + 14).setSize(90, 22).setLabel("OVP (V)").setGroup(grpConnected);
  styleCp5Textfield(cTfOVP);
  cTfOCP = cp5.addTextfield("tfOCP").setPosition(px2, py2 + 56).setSize(90, 22).setLabel("OCP (A)").setGroup(grpConnected);
  styleCp5Textfield(cTfOCP);
  cTfOPP = cp5.addTextfield("tfOPP").setPosition(px2, py2 + 98).setSize(90, 22).setLabel("OPP (W)").setGroup(grpConnected);
  styleCp5Textfield(cTfOPP);
  cTfOTP = cp5.addTextfield("tfOTP").setPosition(px2 + 110, py2 + 14).setSize(80, 22).setLabel("OTP (C)").setGroup(grpConnected);
  styleCp5Textfield(cTfOTP);

  c = cp5.addButton("btnApplyProtection").setPosition(px2 + 110, py2 + 56).setSize(80, 22).setLabel("Apply").setGroup(grpConnected);
  applyGreenTheme(c);

  cBrightness = cp5.addSlider("sliderBrightness").setPosition(px2 + 110, py2 + 98).setSize(80, 20)
    .setRange(0, 20).setValue(10).setLabel("Brightness").setGroup(grpConnected);

  c = cp5.addButton("btnApplyBrightness").setPosition(px2 + 110, py2 + 125).setSize(80, 18).setLabel("Set").setGroup(grpConnected);
  applyGreenTheme(c);

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
  selectedPortName = (availablePorts.length > 0) ? availablePorts[selectedPortIndex] : "";
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
    text((availablePorts.length > 0) ? availablePorts[selectedPortIndex] : "(no ports found)", 381, 20);
  }

  // Top bar visibility — only update when connection state changes
  boolean conn = psu.connected;
  if (conn != prevConnState) {
    prevConnState = conn;
    cPortPrev.setVisible(!conn);
    cPortNext.setVisible(!conn);
    cRefreshPorts.setVisible(!conn);
    cOpenAdvanced.setVisible(conn);
    if (conn) {
      cConnToggle.setLabel("Disconnect");
      applyRedTheme(cConnToggle);
      grpConnected.show();
    } else {
      cConnToggle.setLabel("Connect");
      applyGreenTheme(cConnToggle);
      grpConnected.hide();
    }
  }
  cConnToggle.setLock(!conn && availablePorts.length == 0);

  if (!conn) {
    fill(COL_TEXT_DIM);
    textAlign(CENTER, CENTER);
    textSize(18);
    text("FNIRSI DPS-150 Power Supply Control", WIN_W / 2, WIN_H / 2 - 30);
    textSize(12);
    text("Select a serial port and click Connect", WIN_W / 2, WIN_H / 2 + 10);
  }

  if (conn) {
    drawConnectedGUI();
  }

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
  textAlign(RIGHT, CENTER);
  text("DPS-150 Control  |  " + nf(frameRate, 0, 0) + " fps", WIN_W - 10, WIN_H - 11);
}

/** Draw the connected-state GUI (gauges, graph, controls). Separated for clarity. */
void drawConnectedGUI() {
  float rx = LEFT_W + 15;

  // ---- LEFT SIDE ----
  stroke(COL_BORDER);
  strokeWeight(1);
  line(LEFT_W + 5, TOP_BAR_H + 5, LEFT_W + 5, WIN_H - 5);
  fill(COL_PANEL, 80);
  noStroke();
  rect(10, TOP_BAR_H + 8, LEFT_W - 15, 255, 6);

  gaugeVoltage.value = psu.liveVoltage;
  gaugeCurrent.value = psu.liveCurrent;
  gaugeVoltage.draw();
  gaugeCurrent.draw();

  // Sync Vset/Iset sliders from PSU (only when not being dragged)
  if (!sliderVset.isMouseOver()) {
    sliderVset.setBroadcast(false);
    sliderVset.setValue(psu.setVoltage);
    sliderVset.setBroadcast(true);
  }
  if (!sliderIset.isMouseOver()) {
    sliderIset.setBroadcast(false);
    sliderIset.setValue(psu.setCurrent);
    sliderIset.setBroadcast(true);
  }

  readoutPower.setValue(psu.livePower, 3, 2);
  readoutSetV.setValue(psu.setVoltage, 2, 3);
  readoutSetA.setValue(psu.setCurrent, 1, 3);
  readoutPower.draw();
  readoutSetV.draw();
  readoutSetA.draw();

  graph.draw();

  // Update graph toggle colors only when state changes
  if (graph.showVoltage != prevShowV) {
    cGraphV.setColorBackground(graph.showVoltage ? 0xFF664D00 : 0xFF2A2A35);
    prevShowV = graph.showVoltage;
  }
  if (graph.showCurrent != prevShowA) {
    cGraphA.setColorBackground(graph.showCurrent ? 0xFF005662 : 0xFF2A2A35);
    prevShowA = graph.showCurrent;
  }
  if (graph.showPower != prevShowW) {
    cGraphW.setColorBackground(graph.showPower ? 0xFF1B5E20 : 0xFF2A2A35);
    prevShowW = graph.showPower;
  }

  cStartLog.setLock(psu.logging);
  cStopLog.setLock(!psu.logging);

  if (psu.logging) {
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
  // Sync output toggle — skip for 2s after user click to avoid fighting
  if ((millis() - outputToggleTime) > 2000 && cOutput.getState() != psu.outputOn) {
    cOutput.setBroadcast(false);
    cOutput.setState(psu.outputOn);
    cOutput.setBroadcast(true);
  }

  badgeCV.active = (psu.outputMode == MODE_CV);
  badgeCC.active = (psu.outputMode == MODE_CC);
  badgeCV.draw();
  badgeCC.draw();

  // Protection status text
  textAlign(LEFT, CENTER);
  if (psu.protectionStatus != PROT_OK) {
    fill(COL_OFF);
    textSize(12);
    text(psu.protectionStatusText(), rx + 120, 119);
  } else {
    fill(COL_ON, 150);
    textSize(10);
    text("Normal", rx + 120, 119);
  }

  // Presets
  panelPresets.draw();
  for (int i = 0; i < 6; i++) {
    float ppx = panelPresets.contentX() + (i % 3) * 148;
    float ppy = panelPresets.contentY() + (i / 3) * 72;
    fill(COL_PANEL_LITE);
    stroke(COL_BORDER);
    strokeWeight(0.5);
    rect(ppx, ppy, 140, 65, 3);
    textAlign(LEFT, TOP);
    textSize(10);
    fill(COL_ACCENT);
    text("P" + (i+1), ppx + 5, ppy + 4);
    textSize(13);
    fill(COL_VOLT);
    text(nf(psu.presetV[i], 0, 2) + " V", ppx + 5, ppy + 20);
    fill(COL_CURR);
    text(nf(psu.presetA[i], 0, 2) + " A", ppx + 5, ppy + 40);
  }

  // Info panel
  panelInfo.draw();
  float ix = panelInfo.contentX();
  float iy = panelInfo.contentY();
  textAlign(LEFT, TOP);
  textSize(10);
  String[][] info = {
    {"Input V:", nf(psu.inputVoltage, 0, 2) + " V"},
    {"Temperature:", nf(psu.temperature, 0, 1) + " C"},
    {"Max Voltage:", nf(psu.maxVoltage, 0, 1) + " V"},
    {"Max Current:", nf(psu.maxCurrent, 0, 1) + " A"},
    {"Device:", psu.deviceId.length() > 0 ? psu.deviceId : "--"},
  };
  for (String[] row : info) {
    fill(COL_TEXT_DIM); text(row[0], ix, iy);
    fill(COL_TEXT);     text(row[1], ix + 75, iy);
    iy += (iy < panelInfo.contentY() + 32) ? 16 : 14;
  }
  fill(COL_TEXT_DIM); text("Mode:", ix, iy);
  fill(psu.outputMode == MODE_CV ? COL_VOLT : COL_CURR);
  text(psu.outputMode == MODE_CV ? "CV" : "CC", ix + 75, iy);

  // Protection panel
  panelProtection.draw();

  // Brightness slider is synced once in onSetpointsReceived(), not every frame
}

// ============================================================
// CP5 EVENT HANDLING
// ============================================================

void handleCp5Event(ControlEvent e) {
  String name = e.getController().getName();

  // --- Top bar ---
  if (name.equals("btnPortPrev")) {
    if (!psu.connected && selectedPortIndex > 0) {
      selectedPortIndex--;
      selectedPortName = availablePorts[selectedPortIndex];
    }
  }
  else if (name.equals("btnPortNext")) {
    if (!psu.connected && selectedPortIndex < availablePorts.length - 1) {
      selectedPortIndex++;
      selectedPortName = availablePorts[selectedPortIndex];
    }
  }
  else if (name.equals("btnRefreshPorts")) {
    refreshPorts();
    setStatus("Ports refreshed. Found " + availablePorts.length + " port(s).");
  }
  else if (name.equals("btnConnToggle")) {
    if (psu.connected) {
      psu.disconnectFromPSU();
      setStatus("Disconnected.");
    } else if (availablePorts.length > 0) {
      setStatus("Connecting to " + availablePorts[selectedPortIndex] + "...");
      if (psu.connectToPort(availablePorts[selectedPortIndex])) {
        setStatus("Connected to " + psu.connectedPortName + " — Set V/A values and click Apply.");
      } else {
        setStatus("Connection failed!");
      }
    }
  }
  else if (name.equals("btnOpenAdvanced")) { advancedOpen = true; }

  // --- Output toggle ---
  else if (name.equals("btnOutput")) {
    if (psu.connected) {
      boolean newState = ((Toggle) e.getController()).getState();
      if (newState) { psu.sendOutputOn(); psu.outputOn = true; setStatus("Output ON"); }
      else          { psu.sendOutputOff(); psu.outputOn = false; setStatus("Output OFF"); }
      outputToggleTime = millis();
    }
  }

  // --- Voltage / Current adjust ---
  else if (name.equals("btnVoltUp"))       adjustTf(cTfSetV, 0.1, 0, 30);
  else if (name.equals("btnVoltDown"))     adjustTf(cTfSetV, -0.1, 0, 30);
  else if (name.equals("btnVoltUpFine"))   adjustTf(cTfSetV, 0.01, 0, 30);
  else if (name.equals("btnVoltDownFine")) adjustTf(cTfSetV, -0.01, 0, 30);
  else if (name.equals("btnCurrUp"))       adjustTf(cTfSetA, 0.1, 0, 5);
  else if (name.equals("btnCurrDown"))     adjustTf(cTfSetA, -0.1, 0, 5);
  else if (name.equals("btnCurrUpFine"))   adjustTf(cTfSetA, 0.01, 0, 5);
  else if (name.equals("btnCurrDownFine")) adjustTf(cTfSetA, -0.01, 0, 5);

  // --- Apply / textfield submit ---
  else if (name.equals("btnApply") || name.equals("tfSetVoltage") || name.equals("tfSetCurrent")) {
    applySetpoints();
  }

  // --- Presets ---
  else if (name.startsWith("btnPresetLoad")) {
    int i = name.charAt(name.length()-1) - '0';
    if (psu.connected) {
      psu.sendLoadPreset(i);
      cTfSetV.setText(nf(psu.presetV[i], 0, 3));
      cTfSetA.setText(nf(psu.presetA[i], 0, 3));
      setStatus("Loaded preset " + (i+1));
    }
  }
  else if (name.startsWith("btnPresetSave")) {
    int i = name.charAt(name.length()-1) - '0';
    if (psu.connected) {
      float v = parseTf(cTfSetV), a = parseTf(cTfSetA);
      psu.sendSavePreset(i, v, a);
      psu.presetV[i] = v;
      psu.presetA[i] = a;
      setStatus("Saved preset " + (i+1) + ": " + nf(v,0,2) + "V / " + nf(a,0,2) + "A");
    }
  }

  // --- Info refresh ---
  else if (name.equals("btnRefreshAll")) {
    if (psu.connected) {
      psu.gotFirstSetpoint = false;
      psu.sendReadRegister(REG_ALL);
      setStatus("Refreshing all parameters...");
    }
  }

  // --- Protection ---
  else if (name.equals("tfOVP") || name.equals("tfOCP") || name.equals("tfOPP") || name.equals("tfOTP") || name.equals("btnApplyProtection")) {
    applyProtection();
  }

  // --- Brightness ---
  else if (name.equals("sliderBrightness")) { /* wait for Set click */ }
  else if (name.equals("btnApplyBrightness")) {
    if (psu.connected) {
      int brt = (int) cBrightness.getValue();
      psu.brightness = brt;
      psu.sendSetBrightness(brt);
      setStatus("Brightness set to " + brt);
    }
  }

  // --- Vset / Iset sliders ---
  else if (name.equals("sliderVset")) {
    if (psu.connected) {
      float v = sliderVset.getValue();
      psu.sendSetVoltage(v);
      psu.setVoltage = v;
      cTfSetV.setText(nf(v, 0, 3));
      setStatus("Voltage set to " + nf(v, 0, 3) + "V");
    }
  }
  else if (name.equals("sliderIset")) {
    if (psu.connected) {
      float a = sliderIset.getValue();
      psu.sendSetCurrent(a);
      psu.setCurrent = a;
      cTfSetA.setText(nf(a, 0, 3));
      setStatus("Current set to " + nf(a, 0, 3) + "A");
    }
  }

  // --- Graph toggles ---
  else if (name.equals("btnGraphV")) { graph.showVoltage = !graph.showVoltage; }
  else if (name.equals("btnGraphA")) { graph.showCurrent = !graph.showCurrent; }
  else if (name.equals("btnGraphW")) { graph.showPower   = !graph.showPower; }

  // --- Logging ---
  else if (name.equals("btnStartLog")) {
    if (psu.connected && !psu.logging) { psu.startLogging(); setStatus("Logging started: " + psu.logFileName); }
  }
  else if (name.equals("btnStopLog")) {
    if (psu.logging) { psu.stopLogging(); setStatus("Logging stopped. " + psu.logSampleCount + " samples saved."); }
  }
}

// ============================================================
// HELPERS
// ============================================================

float parseTf(Textfield tf) {
  try { return Float.parseFloat(tf.getText().trim()); }
  catch (Exception e) { return 0; }
}

void adjustTf(Textfield tf, float delta, float lo, float hi) {
  tf.setText(nf(constrain(parseTf(tf) + delta, lo, hi), 0, 3));
}

void applySetpoints() {
  if (!psu.connected) return;
  float v = constrain(parseTf(cTfSetV), 0, psu.maxVoltage);
  float a = parseTf(cTfSetA);
  if (a < 0.001) a = psu.setCurrent;
  a = constrain(a, 0, psu.maxCurrent);
  psu.sendSetVoltage(v);
  delay(100);
  psu.sendSetCurrent(a);
  psu.setVoltage = v;
  psu.setCurrent = a;
  cTfSetV.setText(nf(v, 0, 3));
  cTfSetA.setText(nf(a, 0, 3));
  setStatus("Applied: " + nf(v,0,3) + "V / " + nf(a,0,3) + "A");
}

void applyProtection() {
  if (!psu.connected) return;
  psu.sendSetOVP(parseTf(cTfOVP));
  psu.sendSetOCP(parseTf(cTfOCP));
  psu.sendSetOPP(parseTf(cTfOPP));
  psu.sendSetOTP(parseTf(cTfOTP));
  setStatus("Protection limits applied.");
}

void onSetpointsReceived() {
  cTfSetV.setText(nf(psu.setVoltage, 0, 3));
  cTfSetA.setText(nf(psu.setCurrent, 0, 3));
  cTfOVP.setText(nf(psu.ovpLimit, 0, 3));
  cTfOCP.setText(nf(psu.ocpLimit, 0, 3));
  cTfOPP.setText(nf(psu.oppLimit, 0, 3));
  cTfOTP.setText(nf(psu.otpLimit, 0, 3));
  cBrightness.setBroadcast(false);
  cBrightness.setValue(psu.brightness);
  cBrightness.setBroadcast(true);
  sliderVset.setBroadcast(false);
  sliderVset.setValue(psu.setVoltage);
  sliderVset.setBroadcast(true);
  sliderIset.setBroadcast(false);
  sliderIset.setValue(psu.setCurrent);
  sliderIset.setBroadcast(true);
  setStatus("Set: " + nf(psu.setVoltage, 0, 3) + "V / " + nf(psu.setCurrent, 0, 3) + "A");
}

void handleMouseWheel(float e) {
  if (mouseX >= graph.x && mouseX <= graph.x + graph.w &&
      mouseY >= graph.y && mouseY <= graph.y + graph.h) {
    float factor = (e > 0) ? 1.2 : (1.0 / 1.2);
    graph.voltScale = constrain(graph.voltScale * factor, 1, 60);
    graph.currScale = constrain(graph.currScale * factor, 0.1, 20);
  }
}
