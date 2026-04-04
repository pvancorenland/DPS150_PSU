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

// Registers
static final int REG_BAUD_RATE   = 0x00;
static final int REG_SET_VOLTAGE = 0xC0;
static final int REG_WRITE_VOLT  = 0xC1;
static final int REG_WRITE_CURR  = 0xC2;
static final int REG_LIVE_VALUES = 0xC3;
static final int REG_TEMPERATURE = 0xC4;
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
static final int REG_SET_CURRENT = 0xDE;
static final int REG_SERIAL      = 0xDF;
static final int REG_FIRMWARE    = 0xE0;
static final int REG_DEVICE_ID   = 0xE1;
static final int REG_MAX_VOLT    = 0xE2;
static final int REG_MAX_CURR    = 0xE3;
static final int REG_ALL         = 0xFF;

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
int[] rxBuf = new int[256];
int rxPos = 0;
int rxExpectedLen = 0;

// Timing
long lastPollTime = 0;
int pollInterval = 200;
// (full reads now happen as part of the rotating poll cycle)
boolean gotFirstLive = false;

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
  sendPacket(CMD_WRITE_BYTE, REG_WRITE_VOLT, data);
}

void sendSetCurrent(float a) {
  byte[] fb = floatToLE(a);
  int[] data = {fb[0] & 0xFF, fb[1] & 0xFF, fb[2] & 0xFF, fb[3] & 0xFF};
  sendPacket(CMD_WRITE_BYTE, REG_WRITE_CURR, data);
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
      if (rxPos >= 250) rxPos = 0;
      return;
  }
}

// --- Process a validated response packet ---
// DPS-150 continuously streams these packets (no read requests needed):
//   0xC3 (12 bytes): live V, A, W
//   0xC0 (4 bytes):  input voltage
//   0xE2 (4 bytes):  max voltage (derived from input)
//   0xE3 (4 bytes):  max current
//   0xC4 (4 bytes):  temperature
//   0xDE (7 bytes):  device ID string ("DPS-150")
void processResponsePacket(int[] buf, int len) {
  int reg = buf[2];
  int dataLen = buf[3];

  if (reg == REG_LIVE_VALUES && dataLen >= 12) {
    // Live output: V, A, W
    // Note: first float is set/output voltage (matches PSU Vset even with output OFF)
    // Second float is measured output current (0 with no load — NOT the Iset limit)
    liveVoltage = leToFloat(buf[4], buf[5], buf[6], buf[7]);
    liveCurrent = leToFloat(buf[8], buf[9], buf[10], buf[11]);
    livePower   = leToFloat(buf[12], buf[13], buf[14], buf[15]);

    // On first live frame, sync setVoltage from the live reading
    if (!gotFirstLive) {
      gotFirstLive = true;
      setVoltage = liveVoltage;
      onFirstLiveReceived();
    }
    addHistorySample();
  }
  else if (reg == REG_SET_VOLTAGE && dataLen >= 4) {
    // 0xC0 = input voltage (not set voltage!)
    inputVoltage = leToFloat(buf[4], buf[5], buf[6], buf[7]);
  }
  else if (reg == REG_MAX_VOLT && dataLen >= 4) {
    // 0xE2 = max voltage (derived from input voltage)
    maxVoltage = leToFloat(buf[4], buf[5], buf[6], buf[7]);
  }
  else if (reg == REG_MAX_CURR && dataLen >= 4) {
    // 0xE3 = max current
    maxCurrent = leToFloat(buf[4], buf[5], buf[6], buf[7]);
  }
  else if (reg == REG_TEMPERATURE && dataLen >= 4) {
    // 0xC4 = temperature in °C
    temperature = leToFloat(buf[4], buf[5], buf[6], buf[7]);
  }
  else if (reg == REG_SET_CURRENT && dataLen >= 4) {
    // 0xDE with 7 bytes = device ID string, not a float
    // (handled below)
  }

  // 0xDE with 7 bytes = device ID "DPS-150"
  if (reg == REG_SET_CURRENT && dataLen == 7) {
    StringBuilder sb = new StringBuilder();
    for (int i = 0; i < dataLen; i++) sb.append((char)buf[4+i]);
    deviceId = sb.toString();
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
  gotFirstLive = false;
}

// --- Polling ---
// DPS-150 streams data continuously after connect — no polling needed.
// We just send a periodic read request as a keepalive.
void pollPSU() {
  if (!connected || serialPort == null) return;
  long now = millis();
  if (now - lastPollTime >= pollInterval) {
    lastPollTime = now;
    sendReadLive();
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
