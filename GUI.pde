/**
 * @file GUI.pde
 * @brief Full GUI layout matching the official Fnirsi PC software style.
 *
 * Left side: circular gauges, digital readouts, scrolling graph.
 * Right side: output toggle, set-point controls, presets, device info,
 * protection settings, brightness slider, and logging controls.
 *
 * Interactive widgets use ControlP5; display-only widgets are custom.
 */

// ============================================================
// GUI WIDGETS — Display-only (custom)
// ============================================================

/// @name Connection Bar
/// @{
String[] availablePorts;
int selectedPortIndex = 0;
String selectedPortName = "";
/// @}

/// @name Gauge Widgets
/// @{
CircularGauge gaugeVoltage, gaugeCurrent;
VerticalBar barVmax, barImax;
/// @}

/// @name Digital Readout Widgets
/// @{
DigitalReadout readoutPower, readoutSetV, readoutSetA;
/// @}

/// @name Graph Widget
/// @{
ScrollingGraph graph;
/// @}

/// @name Mode Badges
/// @{
StatusBadge badgeCV, badgeCC;
/// @}

/// @name Panels
/// @{
Panel panelPresets;
Panel panelInfo;
Panel panelProtection;
/// @}

/// @name Status Bar
/// @{
String statusMessage = "Ready";
long statusTime = 0;
long outputToggleTime = 0;
/// @}

// ============================================================
// LAYOUT CONSTANTS
// ============================================================
static final int WIN_W = 1100;
static final int WIN_H = 720;
static final int TOP_BAR_H = 40;
static final int LEFT_W = 620;
static final int RIGHT_W = 470;

// ============================================================
// CP5 Group for connected-only widgets
// ============================================================
Group grpConnected;

/**
 * Update the status bar message.
 * @param msg Text to display
 */
void setStatus(String msg) {
  statusMessage = msg;
  statusTime = millis();
}

// ============================================================
// THEME HELPERS
// ============================================================

void applyDarkTheme(Controller c) {
  c.setColorBackground(color(0x2E, 0x3B, 0x55));   // COL_BTN
  c.setColorForeground(color(0x3D, 0x50, 0x70));   // COL_BTN_HOVER
  c.setColorActive(color(0x4A, 0x65, 0x90));        // COL_BTN_ACTIVE
  c.setColorCaptionLabel(color(0xE0, 0xE0, 0xE8));
}

void applyGreenTheme(Controller c) {
  c.setColorBackground(color(0x1B, 0x5E, 0x20));
  c.setColorForeground(color(0x2E, 0x7D, 0x32));
  c.setColorActive(color(0x43, 0xA0, 0x47));
  c.setColorCaptionLabel(color(0xE0, 0xE0, 0xE8));
}

void applyRedTheme(Controller c) {
  c.setColorBackground(color(0x7F, 0x1D, 0x1D));
  c.setColorForeground(color(0xB7, 0x1C, 0x1C));
  c.setColorActive(color(0xD3, 0x2F, 0x2F));
  c.setColorCaptionLabel(color(0xE0, 0xE0, 0xE8));
}

void styleCp5Textfield(Textfield tf) {
  tf.setColorBackground(color(0x17, 0x17, 0x22));   // COL_INPUT_BG
  tf.setColorForeground(color(0x4A, 0x90, 0xD9));   // COL_ACCENT (focus border)
  tf.setColorActive(color(0x4A, 0x90, 0xD9));
  tf.setColorCaptionLabel(color(0x88, 0x88, 0x99)); // COL_TEXT_DIM
  tf.setColorValueLabel(color(0xE0, 0xE0, 0xE8));   // COL_TEXT
  tf.setAutoClear(false);
}

// ============================================================
// INIT
// ============================================================

/** Initialise all GUI widgets and perform initial port scan. */
void initGUI() {
  // Scan ports
  refreshPorts();

  // --- Top bar buttons (always visible) ---
  Controller c;

  c = cp5.addButton("btnPortPrev").setPosition(180, 8).setSize(22, 24).setLabel("<");
  applyDarkTheme(c);

  c = cp5.addButton("btnPortNext").setPosition(560, 8).setSize(22, 24).setLabel(">");
  applyDarkTheme(c);

  c = cp5.addButton("btnConnect").setPosition(600, 6).setSize(90, 28).setLabel("Connect");
  applyGreenTheme(c);

  c = cp5.addButton("btnDisconnect").setPosition(698, 6).setSize(90, 28).setLabel("Disconnect");
  applyRedTheme(c);

  c = cp5.addButton("btnRefreshPorts").setPosition(796, 6).setSize(70, 28).setLabel("Refresh");
  applyDarkTheme(c);

  c = cp5.addButton("btnOpenAdvanced").setPosition(WIN_W - 100, 6).setSize(90, 28).setLabel("Advanced");
  c.setColorBackground(color(0x4A, 0x14, 0x8C));
  c.setColorForeground(color(0x7B, 0x1F, 0xA2));
  c.setColorActive(color(0x9C, 0x27, 0xB0));
  c.setColorCaptionLabel(color(0xE0, 0xE0, 0xE8));

  // --- Connected-only group ---
  grpConnected = cp5.addGroup("grpConnected").setPosition(0, 0).setSize(WIN_W, WIN_H).hideBar().hide();

  // --- Circular gauges ---
  gaugeVoltage = new CircularGauge(155, 175, 120, "OUTPUT VOLTAGE", "V", 0, 30, COL_VOLT, COL_VOLT_DIM);
  gaugeCurrent = new CircularGauge(430, 175, 120, "OUTPUT CURRENT", "A", 0, 5, COL_CURR, COL_CURR_DIM);
  gaugeCurrent.majorTicks = 5;

  // --- Vmax / Imax vertical bars ---
  barVmax = new VerticalBar(278, 70, 24, 220, "Vmax", "V", 0, 30, COL_VOLT);
  barImax = new VerticalBar(553, 70, 24, 220, "Imax", "A", 0, 5.1, COL_CURR);

  // --- Digital readouts ---
  readoutPower = new DigitalReadout(180, 305, 200, 32, "W", "POWER", COL_POWER);
  readoutSetV  = new DigitalReadout(30, 305, 140, 32, "V", "SET", COL_VOLT);
  readoutSetA  = new DigitalReadout(400, 305, 140, 32, "A", "SET", COL_CURR);

  // --- Graph ---
  graph = new ScrollingGraph(15, 350, LEFT_W - 20, 230);

  // Graph toggle buttons
  c = cp5.addButton("btnGraphV").setPosition(20, 585).setSize(55, 20).setLabel("Voltage").setGroup(grpConnected);
  c.setColorBackground(color(0x66, 0x4D, 0x00));  // COL_VOLT_DIM
  c.setColorForeground(color(0x80, 0x60, 0x00));
  c.setColorActive(color(0x99, 0x73, 0x00));
  c.setColorCaptionLabel(color(0xE0, 0xE0, 0xE8));

  c = cp5.addButton("btnGraphA").setPosition(80, 585).setSize(55, 20).setLabel("Current").setGroup(grpConnected);
  c.setColorBackground(color(0x00, 0x56, 0x62));  // COL_CURR_DIM
  c.setColorForeground(color(0x00, 0x70, 0x7D));
  c.setColorActive(color(0x00, 0x8A, 0x98));
  c.setColorCaptionLabel(color(0xE0, 0xE0, 0xE8));

  c = cp5.addButton("btnGraphW").setPosition(140, 585).setSize(50, 20).setLabel("Power").setGroup(grpConnected);
  c.setColorBackground(color(0x1B, 0x5E, 0x20));  // COL_POWER_DIM
  c.setColorForeground(color(0x2E, 0x7D, 0x32));
  c.setColorActive(color(0x43, 0xA0, 0x47));
  c.setColorCaptionLabel(color(0xE0, 0xE0, 0xE8));

  // Logging buttons
  c = cp5.addButton("btnStartLog").setPosition(350, 585).setSize(80, 20).setLabel("Start Log").setGroup(grpConnected);
  applyGreenTheme(c);

  c = cp5.addButton("btnStopLog").setPosition(440, 585).setSize(75, 20).setLabel("Stop Log").setGroup(grpConnected);
  applyRedTheme(c);

  // --- Right side: Output toggle ---
  float rx = LEFT_W + 15;

  c = cp5.addToggle("btnOutput").setPosition(rx, 50).setSize((int)(RIGHT_W - 30), 52)
    .setMode(ControlP5.SWITCH).setValue(false).setGroup(grpConnected);
  c.setColorBackground(color(0x3E, 0x1A, 0x1A));  // OFF bg
  c.setColorForeground(color(0x00, 0xE6, 0x76));   // ON indicator
  c.setColorActive(color(0x1B, 0x43, 0x32));        // ON bg
  c.setColorCaptionLabel(color(0xE0, 0xE0, 0xE8));
  c.getCaptionLabel().setText("OUTPUT").align(ControlP5.CENTER, ControlP5.CENTER);

  // Mode badges
  badgeCV = new StatusBadge(rx, 108, 50, 22, "CV", COL_VOLT);
  badgeCC = new StatusBadge(rx + 56, 108, 50, 22, "CC", COL_CURR);

  // --- Set controls ---
  float setY = 145;

  Textfield tf;
  tf = cp5.addTextfield("tfSetVoltage").setPosition(rx, setY + 18).setSize(150, 30)
    .setLabel("Set Voltage (0-30V)").setGroup(grpConnected);
  styleCp5Textfield(tf);

  tf = cp5.addTextfield("tfSetCurrent").setPosition(rx + 230, setY + 18).setSize(150, 30)
    .setLabel("Set Current (0-5A)").setGroup(grpConnected);
  styleCp5Textfield(tf);

  // Voltage adjust buttons
  c = cp5.addButton("btnVoltUp").setPosition(rx + 155, setY + 18).setSize(30, 14).setLabel("+.1").setGroup(grpConnected);
  applyDarkTheme(c);
  c = cp5.addButton("btnVoltDown").setPosition(rx + 155, setY + 34).setSize(30, 14).setLabel("-.1").setGroup(grpConnected);
  applyDarkTheme(c);
  c = cp5.addButton("btnVoltUpFine").setPosition(rx + 190, setY + 18).setSize(30, 14).setLabel("+.01").setGroup(grpConnected);
  applyDarkTheme(c);
  c = cp5.addButton("btnVoltDownFine").setPosition(rx + 190, setY + 34).setSize(30, 14).setLabel("-.01").setGroup(grpConnected);
  applyDarkTheme(c);

  // Current adjust buttons
  c = cp5.addButton("btnCurrUp").setPosition(rx + 385, setY + 18).setSize(30, 14).setLabel("+.1").setGroup(grpConnected);
  applyDarkTheme(c);
  c = cp5.addButton("btnCurrDown").setPosition(rx + 385, setY + 34).setSize(30, 14).setLabel("-.1").setGroup(grpConnected);
  applyDarkTheme(c);
  c = cp5.addButton("btnCurrUpFine").setPosition(rx + 420, setY + 18).setSize(30, 14).setLabel("+.01").setGroup(grpConnected);
  applyDarkTheme(c);
  c = cp5.addButton("btnCurrDownFine").setPosition(rx + 420, setY + 34).setSize(30, 14).setLabel("-.01").setGroup(grpConnected);
  applyDarkTheme(c);

  // Apply button
  c = cp5.addButton("btnApply").setPosition(rx, setY + 55).setSize((int)(RIGHT_W - 30), 30).setLabel("APPLY SETTINGS").setGroup(grpConnected);
  applyGreenTheme(c);

  // --- Presets panel ---
  float presetY = setY + 95;
  panelPresets = new Panel(rx, presetY, RIGHT_W - 30, 175, "Express Data — Presets");
  for (int i = 0; i < 6; i++) {
    float px = panelPresets.contentX() + (i % 3) * 148;
    float py = panelPresets.contentY() + (i / 3) * 72;

    c = cp5.addButton("btnPresetLoad" + i).setPosition(px + 85, py + 2).setSize(45, 18).setLabel("Load").setGroup(grpConnected);
    c.setColorBackground(color(0x1A, 0x3A, 0x5C));
    c.setColorForeground(color(0x25, 0x50, 0x78));
    c.setColorActive(color(0x30, 0x66, 0x94));
    c.setColorCaptionLabel(color(0xE0, 0xE0, 0xE8));

    c = cp5.addButton("btnPresetSave" + i).setPosition(px + 85, py + 24).setSize(45, 18).setLabel("Save").setGroup(grpConnected);
    c.setColorBackground(color(0x3A, 0x2A, 0x1A));
    c.setColorForeground(color(0x50, 0x3A, 0x25));
    c.setColorActive(color(0x66, 0x4A, 0x30));
    c.setColorCaptionLabel(color(0xE0, 0xE0, 0xE8));
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

  tf = cp5.addTextfield("tfOVP").setPosition(px2, py2 + 14).setSize(90, 22).setLabel("OVP (V)").setGroup(grpConnected);
  styleCp5Textfield(tf);
  tf = cp5.addTextfield("tfOCP").setPosition(px2, py2 + 56).setSize(90, 22).setLabel("OCP (A)").setGroup(grpConnected);
  styleCp5Textfield(tf);
  tf = cp5.addTextfield("tfOPP").setPosition(px2, py2 + 98).setSize(90, 22).setLabel("OPP (W)").setGroup(grpConnected);
  styleCp5Textfield(tf);
  tf = cp5.addTextfield("tfOTP").setPosition(px2 + 110, py2 + 14).setSize(80, 22).setLabel("OTP (C)").setGroup(grpConnected);
  styleCp5Textfield(tf);

  c = cp5.addButton("btnApplyProtection").setPosition(px2 + 110, py2 + 56).setSize(80, 22).setLabel("Apply").setGroup(grpConnected);
  applyGreenTheme(c);

  // Brightness slider
  c = cp5.addSlider("sliderBrightness").setPosition(px2 + 110, py2 + 100).setSize(80, 16)
    .setRange(0, 20).setValue(10).setNumberOfTickMarks(21).snapToTickMarks(true)
    .setLabel("Brightness").setGroup(grpConnected);
  c.setColorBackground(color(0x1A, 0x1A, 0x25));
  c.setColorForeground(color(0x4A, 0x90, 0xD9));
  c.setColorActive(color(0x6B, 0xB0, 0xFF));
  c.setColorCaptionLabel(color(0x88, 0x88, 0x99));
  c.setColorValueLabel(color(0xE0, 0xE0, 0xE8));

  c = cp5.addButton("btnApplyBrightness").setPosition(px2 + 110, py2 + 125).setSize(80, 18).setLabel("Set").setGroup(grpConnected);
  applyGreenTheme(c);

  // Advanced button visible only when connected — but it's in top bar, handle via draw visibility
  // btnOpenAdvanced is not in grpConnected since we control it manually

  // Init advanced window
  initAdvanced();
}

/** Refresh the list of available serial ports and auto-select the DPS-150 if found. */
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

/**
 * Draw the entire GUI (custom widgets only — cp5 draws itself after this).
 */
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
    String pName = (availablePorts.length > 0) ? availablePorts[selectedPortIndex] : "(no ports found)";
    text(pName, 381, 20);
  }

  // Top bar button visibility
  cp5.getController("btnPortPrev").setVisible(!psu.connected);
  cp5.getController("btnPortNext").setVisible(!psu.connected);
  cp5.getController("btnConnect").setLock(psu.connected || availablePorts.length == 0);
  cp5.getController("btnDisconnect").setLock(!psu.connected);
  cp5.getController("btnRefreshPorts").setVisible(!psu.connected);
  cp5.getController("btnOpenAdvanced").setVisible(psu.connected);

  // Show/hide connected group
  if (psu.connected && !grpConnected.isVisible()) grpConnected.show();
  if (!psu.connected && grpConnected.isVisible()) grpConnected.hide();

  // ---- DISCONNECTED STATE ----
  if (!psu.connected) {
    fill(COL_TEXT_DIM);
    textAlign(CENTER, CENTER);
    textSize(18);
    text("FNIRSI DPS-150 Power Supply Control", WIN_W / 2, WIN_H / 2 - 30);
    textSize(12);
    text("Select a serial port and click Connect", WIN_W / 2, WIN_H / 2 + 10);
  }

  // ---- CONNECTED: custom widgets ----
  if (psu.connected) {

    // ---- LEFT SIDE: Gauges ----
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

    // Vmax / Imax bars
    barVmax.value = psu.maxVoltage;
    barImax.value = psu.maxCurrent;
    barVmax.draw();
    barImax.draw();

    // Digital readouts
    readoutPower.setValue(psu.livePower, 3, 2);
    readoutSetV.setValue(psu.setVoltage, 2, 3);
    readoutSetA.setValue(psu.setCurrent, 1, 3);
    readoutPower.draw();
    readoutSetV.draw();
    readoutSetA.draw();

    // ---- Graph ----
    graph.draw();

    // Update graph toggle button colors
    cp5.getController("btnGraphV").setColorBackground(graph.showVoltage ? color(0x66, 0x4D, 0x00) : color(0x2A, 0x2A, 0x35));
    cp5.getController("btnGraphA").setColorBackground(graph.showCurrent ? color(0x00, 0x56, 0x62) : color(0x2A, 0x2A, 0x35));
    cp5.getController("btnGraphW").setColorBackground(graph.showPower   ? color(0x1B, 0x5E, 0x20) : color(0x2A, 0x2A, 0x35));

    // Logging status
    cp5.getController("btnStartLog").setLock(psu.logging);
    cp5.getController("btnStopLog").setLock(!psu.logging);

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

    // Sync output toggle from PSU (avoid feedback loop)
    Toggle outToggle = (Toggle) cp5.getController("btnOutput");
    if (outToggle.getState() != psu.outputOn) {
      outToggle.setBroadcast(false);
      outToggle.setState(psu.outputOn);
      outToggle.setBroadcast(true);
    }

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

    // --- Presets ---
    panelPresets.draw();
    for (int i = 0; i < 6; i++) {
      float ppx = panelPresets.contentX() + (i % 3) * 148;
      float ppy = panelPresets.contentY() + (i / 3) * 72;

      fill(COL_PANEL_LITE);
      stroke(COL_BORDER);
      strokeWeight(0.5);
      rect(ppx, ppy, 140, 65, 3);

      fill(COL_ACCENT);
      textAlign(LEFT, TOP);
      textSize(10);
      text("P" + (i+1), ppx + 5, ppy + 4);

      fill(COL_VOLT);
      textSize(13);
      text(nf(psu.presetV[i], 0, 2) + " V", ppx + 5, ppy + 20);
      fill(COL_CURR);
      text(nf(psu.presetA[i], 0, 2) + " A", ppx + 5, ppy + 40);
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

    // --- Protection panel ---
    panelProtection.draw();

    // Sync brightness slider from PSU (only when not being interacted with)
    Slider brSlider = (Slider) cp5.getController("sliderBrightness");
    if (!brSlider.isMouseOver()) {
      brSlider.setBroadcast(false);
      brSlider.setValue(psu.brightness);
      brSlider.setBroadcast(true);
    }

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

  fill(COL_TEXT_DIM);
  textAlign(RIGHT, CENTER);
  text("DPS-150 Control  |  " + nf(frameRate, 0, 0) + " fps", WIN_W - 10, WIN_H - 11);
}

// ============================================================
// CP5 EVENT HANDLING
// ============================================================

/**
 * Handle all ControlP5 events by controller name.
 */
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
  else if (name.equals("btnConnect")) {
    if (!psu.connected && availablePorts.length > 0) {
      setStatus("Connecting to " + availablePorts[selectedPortIndex] + "...");
      if (psu.connectToPort(availablePorts[selectedPortIndex])) {
        setStatus("Connected to " + psu.connectedPortName + " — Set V/A values and click Apply.");
      } else {
        setStatus("Connection failed!");
      }
    }
  }
  else if (name.equals("btnDisconnect")) {
    if (psu.connected) {
      psu.disconnectFromPSU();
      setStatus("Disconnected.");
    }
  }
  else if (name.equals("btnOpenAdvanced")) {
    advancedOpen = true;
  }

  // --- Output toggle ---
  else if (name.equals("btnOutput")) {
    if (psu.connected) {
      boolean newState = ((Toggle) e.getController()).getState();
      println("OUTPUT CLICK: outputOn=" + psu.outputOn + " -> " + newState);
      if (newState) { psu.sendOutputOn(); psu.outputOn = true; setStatus("Output ON"); }
      else { psu.sendOutputOff(); psu.outputOn = false; setStatus("Output OFF"); }
      outputToggleTime = millis();
    }
  }

  // --- Voltage / Current adjust ---
  else if (name.equals("btnVoltUp"))       adjustCp5Field("tfSetVoltage", 0.1, 0, 30);
  else if (name.equals("btnVoltDown"))     adjustCp5Field("tfSetVoltage", -0.1, 0, 30);
  else if (name.equals("btnVoltUpFine"))   adjustCp5Field("tfSetVoltage", 0.01, 0, 30);
  else if (name.equals("btnVoltDownFine")) adjustCp5Field("tfSetVoltage", -0.01, 0, 30);
  else if (name.equals("btnCurrUp"))       adjustCp5Field("tfSetCurrent", 0.1, 0, 5);
  else if (name.equals("btnCurrDown"))     adjustCp5Field("tfSetCurrent", -0.1, 0, 5);
  else if (name.equals("btnCurrUpFine"))   adjustCp5Field("tfSetCurrent", 0.01, 0, 5);
  else if (name.equals("btnCurrDownFine")) adjustCp5Field("tfSetCurrent", -0.01, 0, 5);

  // --- Apply settings ---
  else if (name.equals("btnApply")) {
    applySetpoints();
  }
  else if (name.equals("tfSetVoltage") || name.equals("tfSetCurrent")) {
    // Textfield submit on Enter
    applySetpoints();
  }

  // --- Presets ---
  else if (name.startsWith("btnPresetLoad")) {
    int i = Integer.parseInt(name.substring("btnPresetLoad".length()));
    if (psu.connected) {
      psu.sendLoadPreset(i);
      ((Textfield) cp5.getController("tfSetVoltage")).setText(nf(psu.presetV[i], 0, 3));
      ((Textfield) cp5.getController("tfSetCurrent")).setText(nf(psu.presetA[i], 0, 3));
      setStatus("Loaded preset " + (i+1));
    }
  }
  else if (name.startsWith("btnPresetSave")) {
    int i = Integer.parseInt(name.substring("btnPresetSave".length()));
    if (psu.connected) {
      float v = parseCp5Float("tfSetVoltage");
      float a = parseCp5Float("tfSetCurrent");
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
  else if (name.equals("tfOVP") || name.equals("tfOCP") || name.equals("tfOPP") || name.equals("tfOTP")) {
    // Textfield submit on Enter — apply protection
    applyProtection();
  }
  else if (name.equals("btnApplyProtection")) {
    applyProtection();
  }

  // --- Brightness ---
  else if (name.equals("sliderBrightness")) {
    // Value changed — do nothing until Set is clicked
  }
  else if (name.equals("btnApplyBrightness")) {
    if (psu.connected) {
      int brt = (int) ((Slider) cp5.getController("sliderBrightness")).getValue();
      psu.brightness = brt;
      psu.sendSetBrightness(brt);
      setStatus("Brightness set to " + brt);
    }
  }

  // --- Graph toggles ---
  else if (name.equals("btnGraphV")) { graph.showVoltage = !graph.showVoltage; }
  else if (name.equals("btnGraphA")) { graph.showCurrent = !graph.showCurrent; }
  else if (name.equals("btnGraphW")) { graph.showPower   = !graph.showPower; }

  // --- Logging ---
  else if (name.equals("btnStartLog")) {
    if (psu.connected && !psu.logging) {
      psu.startLogging();
      setStatus("Logging started: " + psu.logFileName);
    }
  }
  else if (name.equals("btnStopLog")) {
    if (psu.logging) {
      psu.stopLogging();
      setStatus("Logging stopped. " + psu.logSampleCount + " samples saved.");
    }
  }
}

// ============================================================
// HELPER FUNCTIONS
// ============================================================

/** Parse a float from a cp5 textfield, return 0 on error. */
float parseCp5Float(String tfName) {
  try {
    return Float.parseFloat(((Textfield) cp5.getController(tfName)).getText().trim());
  } catch (Exception e) {
    return 0;
  }
}

/** Adjust a cp5 textfield value by delta, clamped to min/max. */
void adjustCp5Field(String tfName, float delta, float minVal, float maxVal) {
  float val = constrain(parseCp5Float(tfName) + delta, minVal, maxVal);
  ((Textfield) cp5.getController(tfName)).setText(nf(val, 0, 3));
}

/** Apply voltage/current setpoints from text fields. */
void applySetpoints() {
  if (!psu.connected) return;
  float v = constrain(parseCp5Float("tfSetVoltage"), 0, psu.maxVoltage);
  float a = parseCp5Float("tfSetCurrent");
  if (a < 0.001) a = psu.setCurrent;
  a = constrain(a, 0, psu.maxCurrent);
  psu.sendSetVoltage(v);
  delay(100);
  psu.sendSetCurrent(a);
  psu.setVoltage = v;
  psu.setCurrent = a;
  ((Textfield) cp5.getController("tfSetVoltage")).setText(nf(v, 0, 3));
  ((Textfield) cp5.getController("tfSetCurrent")).setText(nf(a, 0, 3));
  println("APPLY: V=" + nf(v,0,3) + " A=" + nf(a,0,3));
  setStatus("Applied: " + nf(v,0,3) + "V / " + nf(a,0,3) + "A");
}

/** Apply protection limits from text fields. */
void applyProtection() {
  if (!psu.connected) return;
  psu.sendSetOVP(parseCp5Float("tfOVP"));
  psu.sendSetOCP(parseCp5Float("tfOCP"));
  psu.sendSetOPP(parseCp5Float("tfOPP"));
  psu.sendSetOTP(parseCp5Float("tfOTP"));
  setStatus("Protection limits applied.");
}

/**
 * Callback invoked when set-point values are received from the PSU.
 */
void onSetpointsReceived() {
  ((Textfield) cp5.getController("tfSetVoltage")).setText(nf(psu.setVoltage, 0, 3));
  ((Textfield) cp5.getController("tfSetCurrent")).setText(nf(psu.setCurrent, 0, 3));
  ((Textfield) cp5.getController("tfOVP")).setText(nf(psu.ovpLimit, 0, 3));
  ((Textfield) cp5.getController("tfOCP")).setText(nf(psu.ocpLimit, 0, 3));
  ((Textfield) cp5.getController("tfOPP")).setText(nf(psu.oppLimit, 0, 3));
  ((Textfield) cp5.getController("tfOTP")).setText(nf(psu.otpLimit, 0, 3));
  println("Setpoints received: V=" + nf(psu.setVoltage, 0, 3) + " A=" + nf(psu.setCurrent, 0, 3));
  setStatus("Set: " + nf(psu.setVoltage, 0, 3) + "V / " + nf(psu.setCurrent, 0, 3) + "A");
}

// ============================================================
// MOUSE WHEEL for graph zoom
// ============================================================

/**
 * Zoom the graph voltage and current scales with the mouse wheel.
 * @param e Scroll amount (positive = zoom out, negative = zoom in)
 */
void handleMouseWheel(float e) {
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
