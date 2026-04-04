// Protocol.pde — Fnirsi DPS-150 binary serial protocol
// Based on the newfnrs protocol documentation

import processing.serial.*;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

// --- Constants ---
static final int HEADER_REQ      = 0xF1;
static final int HEADER_RESP     = 0xF0;

// Command types
static final int CMD_READ        = 0xA1;
static final int CMD_WRITE       = 0xB0;
static final int CMD_WRITE_BYTE  = 0xB1;
static final int CMD_CONFIG      = 0xC0;
static final int CMD_CONNECT     = 0xC1;

// Registers — verified against DPS-150 hardware
static final int REG_BAUD_RATE   = 0x00;
static final int REG_INPUT_VOLT  = 0xC0;  // Input voltage (streamed, read-only)
static final int REG_SET_VOLT    = 0xC1;  // Voltage setpoint (read/write)
static final int REG_SET_CURR    = 0xC2;  // Current setpoint (read/write)
static final int REG_LIVE_VALUES = 0xC3;  // Live V/A/W (streamed, 12 bytes)
static final int REG_TEMPERATURE = 0xC4;  // Temperature (streamed, read-only)
static final int[] REG_PRESET_V  = {0xC5, 0xC7, 0xC9, 0xCB, 0xCD, 0xCF};
static final int[] REG_PRESET_A  = {0xC6, 0xC8, 0xCA, 0xCC, 0xCE, 0xD0};
static final int REG_OVP         = 0xD1;
static final int REG_OCP         = 0xD2;
static final int REG_OPP         = 0xD3;
static final int REG_OTP         = 0xD4;
static final int REG_BRIGHTNESS  = 0xD6;
static final int REG_CAP_AH      = 0xD9;
static final int REG_CAP_WH      = 0xDA;
static final int REG_OUTPUT      = 0xDB;
static final int REG_PROTECTION  = 0xDC;
static final int REG_MODE        = 0xDD;
static final int REG_MODEL_NAME  = 0xDE;  // Device model string (streamed, 7 bytes)
static final int REG_HW_VERSION  = 0xDF;
static final int REG_FIRMWARE    = 0xE0;
static final int REG_DEVICE_ID   = 0xE1;
static final int REG_MAX_VOLT    = 0xE2;  // Max voltage (streamed)
static final int REG_MAX_CURR    = 0xE3;  // Max current (streamed)
static final int REG_ALL         = 0xFF;  // All params dump (139 bytes)

// Protection status codes
static final int PROT_OK  = 0;
static final int PROT_OVP = 1;
static final int PROT_OCP = 2;
static final int PROT_OPP = 3;
static final int PROT_OTP = 4;
static final int PROT_SCP = 5;

// Mode codes
static final int MODE_CV = 0;
static final int MODE_CC = 1;

// --- Protocol state ---
Serial serialPort;
boolean connected = false;
String connectedPortName = "";

// Live readings
float liveVoltage = 0;
float liveCurrent = 0;
float livePower   = 0;
float temperature = 0;
float capacityAh  = 0;
float capacityWh  = 0;
int   protectionStatus = 0;
int   outputMode  = 0;
boolean outputOn  = false;
float setVoltage  = 0;
float setCurrent  = 0;
float inputVoltage = 0;
float maxVoltage  = 30.0;
float maxCurrent  = 5.0;
String deviceId   = "";
int   brightness  = 10;
String firmwareVersion = "";

// Presets
float[] presetV = new float[6];
float[] presetA = new float[6];

// Protection limits
float ovpLimit = 0;
float ocpLimit = 0;
float oppLimit = 0;
float otpLimit = 0;

// Receive buffer & state machine
int[] rxBuf = new int[512];
int rxPos = 0;
int rxExpectedLen = 0;

// Timing
long lastPollTime = 0;
int pollInterval = 200;
// (full reads now happen as part of the rotating poll cycle)
boolean gotFirstSetpoint = false;

// --- Data logging ---
boolean logging = false;
PrintWriter logWriter;
String logFileName = "";
long logStartTime = 0;
int logSampleCount = 0;

// Graph history
int GRAPH_HISTORY = 600;  // 600 samples = ~2 minutes at 200ms
float[] historyV;
float[] historyA;
float[] historyW;
int historyIndex = 0;
int historyCount = 0;

void initHistory() {
  historyV = new float[GRAPH_HISTORY];
  historyA = new float[GRAPH_HISTORY];
  historyW = new float[GRAPH_HISTORY];
}

void addHistorySample() {
  historyV[historyIndex] = liveVoltage;
  historyA[historyIndex] = liveCurrent;
  historyW[historyIndex] = livePower;
  historyIndex = (historyIndex + 1) % GRAPH_HISTORY;
  if (historyCount < GRAPH_HISTORY) historyCount++;

  // Log to file if active
  if (logging && logWriter != null) {
    float elapsed = (millis() - logStartTime) / 1000.0;
    logWriter.println(nf(elapsed, 0, 3) + "," + nf(liveVoltage, 0, 4) + "," + nf(liveCurrent, 0, 4) + "," + nf(livePower, 0, 4));
    logWriter.flush();
    logSampleCount++;
  }
}

void startLogging() {
  logFileName = "DPS150_log_" + year() + nf(month(),2) + nf(day(),2) + "_" + nf(hour(),2) + nf(minute(),2) + nf(second(),2) + ".csv";
  logWriter = createWriter(logFileName);
  logWriter.println("Time(s),Voltage(V),Current(A),Power(W)");
  logStartTime = millis();
  logSampleCount = 0;
  logging = true;
}

void stopLogging() {
  if (logWriter != null) {
    logWriter.flush();
    logWriter.close();
    logWriter = null;
  }
  logging = false;
}

// --- Checksum ---
int calcChecksum(int[] data, int start, int end) {
  int sum = 0;
  for (int i = start; i < end; i++) {
    sum += data[i];
  }
  return sum & 0xFF;
}

// --- Float conversion (little-endian IEEE 754) ---
byte[] floatToLE(float val) {
  ByteBuffer bb = ByteBuffer.allocate(4);
  bb.order(ByteOrder.LITTLE_ENDIAN);
  bb.putFloat(val);
  return bb.array();
}

float leToFloat(int b0, int b1, int b2, int b3) {
  ByteBuffer bb = ByteBuffer.allocate(4);
  bb.order(ByteOrder.LITTLE_ENDIAN);
  bb.put((byte)b0);
  bb.put((byte)b1);
  bb.put((byte)b2);
  bb.put((byte)b3);
  bb.flip();
  return bb.getFloat();
}

// --- Send raw packet ---
void sendPacket(int cmdType, int register_, int[] data) {
  if (serialPort == null) return;
  int len = (data != null) ? data.length : 0;
  int[] pkt = new int[4 + len + 1];
  pkt[0] = HEADER_REQ;
  pkt[1] = cmdType;
  pkt[2] = register_;
  pkt[3] = len;
  if (data != null) {
    for (int i = 0; i < len; i++) pkt[4 + i] = data[i];
  }
  pkt[pkt.length - 1] = calcChecksum(pkt, 2, pkt.length - 1);
  byte[] out = new byte[pkt.length];
  for (int i = 0; i < pkt.length; i++) out[i] = (byte)(pkt[i] & 0xFF);
  serialPort.write(out);
}

// --- Send helpers ---
void sendConnect() {
  int[] data = {0x01};
  sendPacket(CMD_CONNECT, 0x00, data);
}

void sendDisconnect() {
  int[] data = {0x00};
  sendPacket(CMD_CONNECT, 0x00, data);
}

void sendOutputOn() {
  int[] data = {0x01};
  sendPacket(CMD_WRITE_BYTE, REG_OUTPUT, data);
}

void sendOutputOff() {
  int[] data = {0x00};
  sendPacket(CMD_WRITE_BYTE, REG_OUTPUT, data);
}

void sendSetVoltage(float v) {
  byte[] fb = floatToLE(v);
  int[] data = {fb[0] & 0xFF, fb[1] & 0xFF, fb[2] & 0xFF, fb[3] & 0xFF};
  sendPacket(CMD_WRITE_BYTE, REG_SET_VOLT, data);
}

void sendSetCurrent(float a) {
  byte[] fb = floatToLE(a);
  int[] data = {fb[0] & 0xFF, fb[1] & 0xFF, fb[2] & 0xFF, fb[3] & 0xFF};
  sendPacket(CMD_WRITE_BYTE, REG_SET_CURR, data);
}

void sendReadRegister(int register_) {
  int[] data = {0x00};
  sendPacket(CMD_READ, register_, data);
}

void sendReadLive() {
  sendReadRegister(REG_LIVE_VALUES);
}

void sendWriteFloat(int register_, float val) {
  byte[] fb = floatToLE(val);
  int[] data = {fb[0] & 0xFF, fb[1] & 0xFF, fb[2] & 0xFF, fb[3] & 0xFF};
  sendPacket(CMD_WRITE, register_, data);
}

void sendWriteByte(int register_, int val) {
  int[] data = {val & 0xFF};
  sendPacket(CMD_WRITE_BYTE, register_, data);
}

void sendSetBrightness(int level) {
  sendWriteByte(REG_BRIGHTNESS, level);
}

void sendSetOVP(float val) { sendWriteFloat(REG_OVP, val); }
void sendSetOCP(float val) { sendWriteFloat(REG_OCP, val); }
void sendSetOPP(float val) { sendWriteFloat(REG_OPP, val); }
void sendSetOTP(float val) { sendWriteFloat(REG_OTP, val); }

void sendSavePreset(int slot, float v, float a) {
  if (slot < 0 || slot > 5) return;
  sendWriteFloat(REG_PRESET_V[slot], v);
  sendWriteFloat(REG_PRESET_A[slot], a);
}

void sendLoadPreset(int slot) {
  if (slot < 0 || slot > 5) return;
  sendReadRegister(REG_PRESET_V[slot]);
  sendReadRegister(REG_PRESET_A[slot]);
}

// --- Receive state machine ---
void processSerialByte(int b) {
  rxBuf[rxPos] = b & 0xFF;
  switch (rxPos) {
    case 0:
      if (b == HEADER_RESP) rxPos = 1;
      return;
    case 1: rxPos = 2; return;
    case 2: rxPos = 3; return;
    case 3:
      rxExpectedLen = b & 0xFF;
      rxPos = 4;
      return;
    default:
      rxPos++;
      if (rxPos >= 4 + rxExpectedLen + 1) {
        int expectedChk = calcChecksum(rxBuf, 2, rxPos - 1);
        int actualChk = rxBuf[rxPos - 1];
        if (expectedChk == actualChk) {
          processResponsePacket(rxBuf, rxPos);
        }
        rxPos = 0;
      }
      if (rxPos >= 500) rxPos = 0;
      return;
  }
}

// --- Process a validated response packet ---
// DPS-150 streams: 0xC3 (live V/A/W), 0xC0 (input V), 0xE2 (max V),
//   0xE3 (max A), 0xC4 (temp), 0xDE (model string)
// Also responds to explicit reads: 0xC1 (Vset), 0xC2 (Iset), 0xFF (all)
void processResponsePacket(int[] buf, int len) {
  int reg = buf[2];
  int dataLen = buf[3];

  if (reg == REG_LIVE_VALUES && dataLen >= 12) {
    liveVoltage = leToFloat(buf[4], buf[5], buf[6], buf[7]);
    liveCurrent = leToFloat(buf[8], buf[9], buf[10], buf[11]);
    livePower   = leToFloat(buf[12], buf[13], buf[14], buf[15]);
    addHistorySample();
  }
  else if (reg == REG_INPUT_VOLT && dataLen >= 4) {
    inputVoltage = leToFloat(buf[4], buf[5], buf[6], buf[7]);
  }
  else if (reg == REG_SET_VOLT && dataLen >= 4) {
    setVoltage = leToFloat(buf[4], buf[5], buf[6], buf[7]);
    if (!gotFirstSetpoint) { gotFirstSetpoint = true; onSetpointsReceived(); }
  }
  else if (reg == REG_SET_CURR && dataLen >= 4) {
    setCurrent = leToFloat(buf[4], buf[5], buf[6], buf[7]);
    if (!gotFirstSetpoint) { gotFirstSetpoint = true; onSetpointsReceived(); }
  }
  else if (reg == REG_TEMPERATURE && dataLen >= 4) {
    temperature = leToFloat(buf[4], buf[5], buf[6], buf[7]);
  }
  else if (reg == REG_MAX_VOLT && dataLen >= 4) {
    maxVoltage = leToFloat(buf[4], buf[5], buf[6], buf[7]);
  }
  else if (reg == REG_MAX_CURR && dataLen >= 4) {
    maxCurrent = leToFloat(buf[4], buf[5], buf[6], buf[7]);
  }
  else if (reg == REG_MODEL_NAME && dataLen >= 4) {
    // 0xDE: model name string (e.g. "DPS-150")
    StringBuilder sb = new StringBuilder();
    for (int i = 0; i < dataLen; i++) sb.append((char)buf[4+i]);
    deviceId = sb.toString();
  }
  else if (reg == REG_OUTPUT && dataLen >= 1) {
    // Don't override local state right after user toggled output
    if (millis() - outputToggleTime > 2000) {
      outputOn = (buf[4] == 1);
    }
  }
  else if (reg == REG_MODE && dataLen >= 1) {
    outputMode = buf[4];
  }
  else if (reg == REG_PROTECTION && dataLen >= 1) {
    protectionStatus = buf[4];
  }
  else if (reg == REG_BRIGHTNESS && dataLen >= 1) {
    brightness = buf[4];
  }
  else if (reg == REG_OVP && dataLen >= 4) { ovpLimit = leToFloat(buf[4], buf[5], buf[6], buf[7]); }
  else if (reg == REG_OCP && dataLen >= 4) { ocpLimit = leToFloat(buf[4], buf[5], buf[6], buf[7]); }
  else if (reg == REG_OPP && dataLen >= 4) { oppLimit = leToFloat(buf[4], buf[5], buf[6], buf[7]); }
  else if (reg == REG_OTP && dataLen >= 4) { otpLimit = leToFloat(buf[4], buf[5], buf[6], buf[7]); }
  else if (reg == REG_CAP_AH && dataLen >= 4) { capacityAh = leToFloat(buf[4], buf[5], buf[6], buf[7]); }
  else if (reg == REG_CAP_WH && dataLen >= 4) { capacityWh = leToFloat(buf[4], buf[5], buf[6], buf[7]); }
  else if (reg == REG_ALL && dataLen >= 139) {
    // Bulk dump: offsets verified from test
    // 0: input V, 4: set V, 8: set I, 12: live V, 16: live I, 20: live W, 24: temp
    inputVoltage = leToFloat(buf[4+0], buf[4+1], buf[4+2], buf[4+3]);
    setVoltage   = leToFloat(buf[4+4], buf[4+5], buf[4+6], buf[4+7]);
    setCurrent   = leToFloat(buf[4+8], buf[4+9], buf[4+10], buf[4+11]);
    liveVoltage  = leToFloat(buf[4+12], buf[4+13], buf[4+14], buf[4+15]);
    liveCurrent  = leToFloat(buf[4+16], buf[4+17], buf[4+18], buf[4+19]);
    livePower    = leToFloat(buf[4+20], buf[4+21], buf[4+22], buf[4+23]);
    temperature  = leToFloat(buf[4+24], buf[4+25], buf[4+26], buf[4+27]);
    // Presets at offset 28 (6 pairs of V+A floats = 48 bytes)
    for (int i = 0; i < 6; i++) {
      int off = 4 + 28 + i * 8;
      presetV[i] = leToFloat(buf[off], buf[off+1], buf[off+2], buf[off+3]);
      presetA[i] = leToFloat(buf[off+4], buf[off+5], buf[off+6], buf[off+7]);
    }
    // offset 76: max V, 80: max A
    maxVoltage = leToFloat(buf[4+76], buf[4+77], buf[4+78], buf[4+79]);
    maxCurrent = leToFloat(buf[4+80], buf[4+81], buf[4+82], buf[4+83]);
    // offset 84: OVP, 88: OCP, 92: OPP, 96: OTP
    ovpLimit = leToFloat(buf[4+84], buf[4+85], buf[4+86], buf[4+87]);
    ocpLimit = leToFloat(buf[4+88], buf[4+89], buf[4+90], buf[4+91]);
    oppLimit = leToFloat(buf[4+92], buf[4+93], buf[4+94], buf[4+95]);
    otpLimit = leToFloat(buf[4+96], buf[4+97], buf[4+98], buf[4+99]);
    addHistorySample();
    onSetpointsReceived();
  }

  // Preset registers (individual reads)
  for (int i = 0; i < 6; i++) {
    if (reg == REG_PRESET_V[i] && dataLen >= 4) {
      presetV[i] = leToFloat(buf[4], buf[5], buf[6], buf[7]);
    }
    if (reg == REG_PRESET_A[i] && dataLen >= 4) {
      presetA[i] = leToFloat(buf[4], buf[5], buf[6], buf[7]);
    }
  }
}

// --- Connection management ---
String findPSUPort() {
  String[] ports = Serial.list();
  for (String p : ports) {
    if (p.contains("cu.usbmodem14798A3C")) return p;
  }
  return null;
}

boolean connectToPort(String portName) {
  try {
    serialPort = new Serial((PApplet)DPS150_PSU.this, portName, 115200);
    serialPort.buffer(1);
    connectedPortName = portName;
    delay(100);
    sendConnect();
    delay(500);
    connected = true;
    // Request setpoints and state (staggered so PSU can process each)
    sendReadRegister(REG_SET_VOLT);
    delay(50);
    sendReadRegister(REG_SET_CURR);
    delay(50);
    sendReadRegister(REG_OUTPUT);
    delay(50);
    sendReadRegister(REG_MODE);
    delay(50);
    sendReadRegister(REG_PROTECTION);
    delay(50);
    sendReadRegister(REG_ALL);
    return true;
  } catch (Exception e) {
    println("Connection failed: " + e.getMessage());
    serialPort = null;
    connected = false;
    return false;
  }
}

void disconnectFromPSU() {
  if (logging) stopLogging();
  if (serialPort != null) {
    sendDisconnect();
    delay(100);
    serialPort.stop();
    serialPort = null;
  }
  connected = false;
  connectedPortName = "";
  gotFirstSetpoint = false;
}

// --- Polling ---
int pollCycle = 0;

void pollPSU() {
  if (!connected || serialPort == null) return;
  long now = millis();
  if (now - lastPollTime >= pollInterval) {
    lastPollTime = now;
    sendReadLive();
    // Every 5th cycle (~1s), also request output state and mode
    pollCycle++;
    if (pollCycle % 5 == 0) {
      sendReadRegister(REG_OUTPUT);
      sendReadRegister(REG_MODE);
      sendReadRegister(REG_PROTECTION);
    }
  }
}

String protectionStatusText() {
  switch (protectionStatus) {
    case PROT_OK:  return "OK";
    case PROT_OVP: return "OVP!";
    case PROT_OCP: return "OCP!";
    case PROT_OPP: return "OPP!";
    case PROT_OTP: return "OTP!";
    case PROT_SCP: return "SCP!";
    default: return "???";
  }
}
