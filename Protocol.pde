/**
 * @file Protocol.pde
 * @brief Serial protocol layer for the FNIRSI DPS-150 power supply.
 *
 * Defines the binary packet format, register map, and the DPS150Protocol class
 * that encapsulates all communication state and methods.  A single global
 * instance @c psu is created for use by all other tabs.
 *
 * Packet format (request):  F1 <cmd> <reg> <len> [data...] <chk>
 * Packet format (response): F0 <cmd> <reg> <len> [data...] <chk>
 *
 * Checksum = sum of bytes from reg through last data byte, AND 0xFF.
 */

import processing.serial.*;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;

// ============================================================
// Protocol Constants (sketch-level, shared across all tabs)
// ============================================================

/** @name Packet Headers
 *  @{ */
static final int HEADER_REQ      = 0xF1;  ///< Request packet header (host → PSU)
static final int HEADER_RESP     = 0xF0;  ///< Response packet header (PSU → host)
/** @} */

/** @name Command Types
 *  @{ */
static final int CMD_READ        = 0xA1;  ///< Read register
static final int CMD_WRITE       = 0xB0;  ///< Write register (float payload)
static final int CMD_WRITE_BYTE  = 0xB1;  ///< Write register (byte/float payload, used for set-points)
static final int CMD_CONFIG      = 0xC0;  ///< Configuration command
static final int CMD_CONNECT     = 0xC1;  ///< Connect / disconnect handshake
/** @} */

/** @name Register Addresses
 *  Verified against DPS-150 hardware.
 *  @{ */
static final int REG_BAUD_RATE   = 0x00;  ///< Baud rate setting
static final int REG_INPUT_VOLT  = 0xC0;  ///< Input voltage (streamed, read-only)
static final int REG_SET_VOLT    = 0xC1;  ///< Voltage set-point (read/write)
static final int REG_SET_CURR    = 0xC2;  ///< Current set-point (read/write)
static final int REG_LIVE_VALUES = 0xC3;  ///< Live V/A/W triple (streamed, 12 bytes)
static final int REG_TEMPERATURE = 0xC4;  ///< Temperature in °C (streamed)
static final int[] REG_PRESET_V  = {0xC5, 0xC7, 0xC9, 0xCB, 0xCD, 0xCF};  ///< Preset voltage slots 1-6
static final int[] REG_PRESET_A  = {0xC6, 0xC8, 0xCA, 0xCC, 0xCE, 0xD0};  ///< Preset current slots 1-6
static final int REG_OVP         = 0xD1;  ///< Over-voltage protection limit
static final int REG_OCP         = 0xD2;  ///< Over-current protection limit
static final int REG_OPP         = 0xD3;  ///< Over-power protection limit
static final int REG_OTP         = 0xD4;  ///< Over-temperature protection limit
static final int REG_BRIGHTNESS  = 0xD6;  ///< Display brightness (0-20)
static final int REG_CAP_AH      = 0xD9;  ///< Accumulated capacity in Ah
static final int REG_CAP_WH      = 0xDA;  ///< Accumulated energy in Wh
static final int REG_OUTPUT      = 0xDB;  ///< Output on/off state
static final int REG_PROTECTION  = 0xDC;  ///< Active protection status code
static final int REG_MODE        = 0xDD;  ///< Operating mode (CV/CC)
static final int REG_MODEL_NAME  = 0xDE;  ///< Model name string (streamed, 7 bytes)
static final int REG_HW_VERSION  = 0xDF;  ///< Hardware version
static final int REG_FIRMWARE    = 0xE0;  ///< Firmware version
static final int REG_DEVICE_ID   = 0xE1;  ///< Device ID
static final int REG_MAX_VOLT    = 0xE2;  ///< Maximum voltage capability (streamed)
static final int REG_MAX_CURR    = 0xE3;  ///< Maximum current capability (streamed)
static final int REG_ALL         = 0xFF;  ///< Bulk dump of all parameters (139 bytes)
/** @} */

/** @name Protection Status Codes
 *  @{ */
static final int PROT_OK  = 0;  ///< No protection active
static final int PROT_OVP = 1;  ///< Over-voltage protection triggered
static final int PROT_OCP = 2;  ///< Over-current protection triggered
static final int PROT_OPP = 3;  ///< Over-power protection triggered
static final int PROT_OTP = 4;  ///< Over-temperature protection triggered
static final int PROT_SCP = 5;  ///< Short-circuit protection triggered
/** @} */

/** @name Operating Mode Codes
 *  @{ */
static final int MODE_CV = 0;   ///< Constant Voltage mode
static final int MODE_CC = 1;   ///< Constant Current mode
/** @} */

/** Global protocol instance used by all tabs. */
DPS150Protocol psu = new DPS150Protocol();

// ============================================================
/**
 * @class DPS150Protocol
 * @brief Encapsulates all DPS-150 serial protocol state and methods.
 *
 * Handles connection management, packet send/receive, register parsing,
 * polling, data-logging, and graph-history buffering.  Public fields
 * expose the latest readings for the GUI to display; public methods
 * provide write-back commands for controlling the PSU.
 *
 * ### Usage
 * @code
 *   psu.connectToPort("/dev/cu.usbmodem...");
 *   psu.sendSetVoltage(5.0);
 *   psu.sendOutputOn();
 * @endcode
 */
// ============================================================
class DPS150Protocol {

  // ---- Connection ------------------------------------------------

  /** Active serial port, or null when disconnected. */
  Serial serialPort;
  /** True while a connection to the PSU is established. */
  boolean connected = false;
  /** System name of the connected serial port (e.g. "/dev/cu.usbmodem..."). */
  String connectedPortName = "";

  // ---- Live Readings ---------------------------------------------

  float liveVoltage = 0;    ///< Most recent output voltage (V)
  float liveCurrent = 0;    ///< Most recent output current (A)
  float livePower   = 0;    ///< Most recent output power (W)
  float temperature = 0;    ///< Internal temperature (°C)
  float capacityAh  = 0;    ///< Accumulated capacity (Ah)
  float capacityWh  = 0;    ///< Accumulated energy (Wh)
  int   protectionStatus = 0; ///< Active protection code (PROT_OK..PROT_SCP)
  int   outputMode  = 0;    ///< Current regulation mode (MODE_CV or MODE_CC)
  boolean outputOn  = false; ///< True when output is enabled
  float setVoltage  = 0;    ///< Configured voltage set-point (V)
  float setCurrent  = 0;    ///< Configured current set-point (A)
  float inputVoltage = 0;   ///< DC input voltage (V)
  float maxVoltage  = 30.0; ///< Maximum output voltage (V)
  float maxCurrent  = 5.0;  ///< Maximum output current (A)
  String deviceId   = "";   ///< Model name string (e.g. "DPS-150")
  int   brightness  = 10;   ///< Display brightness level (0-20)
  String firmwareVersion = ""; ///< Firmware version string

  // ---- Presets ---------------------------------------------------

  float[] presetV = new float[6]; ///< Voltage presets P1-P6
  float[] presetA = new float[6]; ///< Current presets P1-P6

  // ---- Protection Limits -----------------------------------------

  float ovpLimit = 0; ///< Over-voltage protection threshold (V)
  float ocpLimit = 0; ///< Over-current protection threshold (A)
  float oppLimit = 0; ///< Over-power protection threshold (W)
  float otpLimit = 0; ///< Over-temperature protection threshold (°C)

  // ---- Receive State Machine -------------------------------------

  /** @cond INTERNAL */
  int[] rxBuf = new int[512];
  int rxPos = 0;
  int rxExpectedLen = 0;
  /** @endcond */

  // ---- Timing / Polling ------------------------------------------

  long lastPollTime = 0;     ///< millis() timestamp of last poll
  int pollInterval = 200;    ///< Polling interval in milliseconds
  boolean gotFirstSetpoint = false; ///< True after first set-point response
  int pollCycle = 0;         ///< Rotating poll counter

  // ---- Data Logging ----------------------------------------------

  boolean logging = false;       ///< True while CSV logging is active
  PrintWriter logWriter;         ///< Output stream for the CSV log file
  String logFileName = "";       ///< Name of the current log file
  long logStartTime = 0;        ///< millis() when logging started
  int logSampleCount = 0;       ///< Number of samples written so far

  // ---- Graph History ---------------------------------------------

  int GRAPH_HISTORY = 600;  ///< Ring-buffer size (600 samples ≈ 2 min at 200 ms)
  float[] historyV;          ///< Voltage history ring-buffer
  float[] historyA;          ///< Current history ring-buffer
  float[] historyW;          ///< Power history ring-buffer
  int historyIndex = 0;      ///< Next write position in the ring-buffer
  int historyCount = 0;      ///< Number of valid samples in the ring-buffer

  // ================================================================
  // History & Logging
  // ================================================================

  /** Allocate the graph history ring-buffers.  Call once from setup(). */
  void initHistory() {
    historyV = new float[GRAPH_HISTORY];
    historyA = new float[GRAPH_HISTORY];
    historyW = new float[GRAPH_HISTORY];
  }

  /**
   * Append the current live V/A/W readings to the history ring-buffer
   * and, if logging is active, write a CSV row.
   */
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

  /**
   * Start CSV data logging.
   *
   * Creates a timestamped file (e.g. "DPS150_log_20260403_143022.csv")
   * in the sketch folder with columns: Time(s), Voltage(V), Current(A), Power(W).
   */
  void startLogging() {
    logFileName = "DPS150_log_" + year() + nf(month(),2) + nf(day(),2) + "_" + nf(hour(),2) + nf(minute(),2) + nf(second(),2) + ".csv";
    logWriter = createWriter(logFileName);
    logWriter.println("Time(s),Voltage(V),Current(A),Power(W)");
    logStartTime = millis();
    logSampleCount = 0;
    logging = true;
  }

  /** Stop CSV data logging and close the file. */
  void stopLogging() {
    if (logWriter != null) {
      logWriter.flush();
      logWriter.close();
      logWriter = null;
    }
    logging = false;
  }

  // ================================================================
  // Checksum & Float Conversion
  // ================================================================

  /**
   * Compute the DPS-150 checksum over a sub-range of a byte array.
   * @param data  Array of byte values
   * @param start Start index (inclusive)
   * @param end   End index (exclusive)
   * @return      Low 8 bits of the sum
   */
  int calcChecksum(int[] data, int start, int end) {
    int sum = 0;
    for (int i = start; i < end; i++) {
      sum += data[i];
    }
    return sum & 0xFF;
  }

  /**
   * Convert a float to a 4-byte little-endian IEEE 754 array.
   * @param val Float value to convert
   * @return    4-byte array in little-endian order
   */
  byte[] floatToLE(float val) {
    ByteBuffer bb = ByteBuffer.allocate(4);
    bb.order(ByteOrder.LITTLE_ENDIAN);
    bb.putFloat(val);
    return bb.array();
  }

  /**
   * Reconstruct a float from four little-endian bytes.
   * @param b0 Byte 0 (LSB)
   * @param b1 Byte 1
   * @param b2 Byte 2
   * @param b3 Byte 3 (MSB)
   * @return   Decoded float value
   */
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

  // ================================================================
  // Send Methods
  // ================================================================

  /**
   * Build and transmit a raw protocol packet.
   * @param cmdType   Command byte (CMD_READ, CMD_WRITE, CMD_WRITE_BYTE, etc.)
   * @param register_ Target register address
   * @param data      Payload bytes (may be null for zero-length payloads)
   */
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

  /** Send the connection handshake (must be first command after opening the port). */
  void sendConnect() {
    int[] data = {0x01};
    sendPacket(CMD_CONNECT, 0x00, data);
  }

  /** Send the disconnection handshake (call before closing the port). */
  void sendDisconnect() {
    int[] data = {0x00};
    sendPacket(CMD_CONNECT, 0x00, data);
  }

  /** Enable the power output. */
  void sendOutputOn() {
    int[] data = {0x01};
    sendPacket(CMD_WRITE_BYTE, REG_OUTPUT, data);
  }

  /** Disable the power output. */
  void sendOutputOff() {
    int[] data = {0x00};
    sendPacket(CMD_WRITE_BYTE, REG_OUTPUT, data);
  }

  /**
   * Set the output voltage.
   * @param v Desired voltage in volts (0 – maxVoltage)
   */
  void sendSetVoltage(float v) {
    byte[] fb = floatToLE(v);
    int[] data = {fb[0] & 0xFF, fb[1] & 0xFF, fb[2] & 0xFF, fb[3] & 0xFF};
    sendPacket(CMD_WRITE_BYTE, REG_SET_VOLT, data);
  }

  /**
   * Set the output current limit.
   * @param a Desired current in amps (0 – maxCurrent)
   */
  void sendSetCurrent(float a) {
    byte[] fb = floatToLE(a);
    int[] data = {fb[0] & 0xFF, fb[1] & 0xFF, fb[2] & 0xFF, fb[3] & 0xFF};
    sendPacket(CMD_WRITE_BYTE, REG_SET_CURR, data);
  }

  /**
   * Request a register read from the PSU.
   * @param register_ Register address to read
   */
  void sendReadRegister(int register_) {
    int[] data = {0x00};
    sendPacket(CMD_READ, register_, data);
  }

  /** Request the live V/A/W triple (convenience wrapper). */
  void sendReadLive() {
    sendReadRegister(REG_LIVE_VALUES);
  }

  /**
   * Write a float value to a register using CMD_WRITE.
   * @param register_ Target register
   * @param val       Float value to write
   */
  void sendWriteFloat(int register_, float val) {
    byte[] fb = floatToLE(val);
    int[] data = {fb[0] & 0xFF, fb[1] & 0xFF, fb[2] & 0xFF, fb[3] & 0xFF};
    sendPacket(CMD_WRITE, register_, data);
  }

  /**
   * Write a single byte to a register using CMD_WRITE_BYTE.
   * @param register_ Target register
   * @param val       Byte value (0-255)
   */
  void sendWriteByte(int register_, int val) {
    int[] data = {val & 0xFF};
    sendPacket(CMD_WRITE_BYTE, register_, data);
  }

  /**
   * Set the PSU display brightness.
   * @param level Brightness level (0-20)
   */
  void sendSetBrightness(int level) {
    sendWriteByte(REG_BRIGHTNESS, level);
  }

  /** @name Protection Limit Write Methods
   *  @{ */
  void sendSetOVP(float val) { sendWriteFloat(REG_OVP, val); } ///< Set over-voltage limit
  void sendSetOCP(float val) { sendWriteFloat(REG_OCP, val); } ///< Set over-current limit
  void sendSetOPP(float val) { sendWriteFloat(REG_OPP, val); } ///< Set over-power limit
  void sendSetOTP(float val) { sendWriteFloat(REG_OTP, val); } ///< Set over-temperature limit
  /** @} */

  /**
   * Save a voltage/current pair to a preset slot on the PSU.
   * @param slot Preset index (0-5)
   * @param v    Voltage value
   * @param a    Current value
   */
  void sendSavePreset(int slot, float v, float a) {
    if (slot < 0 || slot > 5) return;
    sendWriteFloat(REG_PRESET_V[slot], v);
    sendWriteFloat(REG_PRESET_A[slot], a);
  }

  /**
   * Request the PSU to send the V/A values stored in a preset slot.
   * @param slot Preset index (0-5)
   */
  void sendLoadPreset(int slot) {
    if (slot < 0 || slot > 5) return;
    sendReadRegister(REG_PRESET_V[slot]);
    sendReadRegister(REG_PRESET_A[slot]);
  }

  // ================================================================
  // Receive State Machine
  // ================================================================

  /**
   * Feed one byte from the serial port into the packet reassembly
   * state machine.  When a complete, checksum-valid packet is received
   * it is dispatched to processResponsePacket().
   *
   * @param b Raw byte value (0-255)
   */
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

  // ================================================================
  /**
   * Decode a validated response packet and update the corresponding
   * instance fields.
   *
   * Handles both continuously-streamed registers (C3, C0, E2, E3, C4, DE)
   * and explicitly-requested registers (C1, C2, FF, individual presets,
   * protection limits, etc.).
   *
   * @param buf Raw packet bytes (header through checksum)
   * @param len Total number of bytes in buf
   */
  // ================================================================
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
      StringBuilder sb = new StringBuilder();
      for (int i = 0; i < dataLen; i++) sb.append((char)buf[4+i]);
      deviceId = sb.toString();
    }
    else if (reg == REG_OUTPUT && dataLen >= 1) {
      outputOn = (buf[4] == 1);
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
      // Bulk dump — offsets verified from hardware testing
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
      maxVoltage = leToFloat(buf[4+76], buf[4+77], buf[4+78], buf[4+79]);
      maxCurrent = leToFloat(buf[4+80], buf[4+81], buf[4+82], buf[4+83]);
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

  // ================================================================
  // Connection Management
  // ================================================================

  /**
   * Scan available serial ports for one matching the DPS-150 USB descriptor.
   * @return Port name if found, null otherwise
   */
  String findPSUPort() {
    String[] ports = Serial.list();
    for (String p : ports) {
      if (p.contains("cu.usbmodem14798A3C")) return p;
    }
    return null;
  }

  /**
   * Open a serial connection to the PSU and perform the initial handshake.
   *
   * After connecting, requests set-points, output state, mode, protection
   * status, and a full register dump.  Staggered delays allow the PSU
   * time to process each request.
   *
   * @param portName System serial port path
   * @return true on success, false on failure
   */
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

  /**
   * Gracefully disconnect from the PSU.
   *
   * Stops any active logging, sends the disconnect handshake, and
   * closes the serial port.
   */
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

  // ================================================================
  // Polling
  // ================================================================

  /**
   * Periodic poll — call from draw().
   *
   * Requests live readings every #pollInterval ms.  Every 5th cycle
   * (~1 s) also requests mode and protection status.
   */
  void pollPSU() {
    if (!connected || serialPort == null) return;
    long now = millis();
    if (now - lastPollTime >= pollInterval) {
      lastPollTime = now;
      sendReadLive();
      pollCycle++;
      if (pollCycle % 5 == 0) {
        sendReadRegister(REG_MODE);
        sendReadRegister(REG_PROTECTION);
      }
    }
  }

  /**
   * Return a short human-readable label for the current protection status.
   * @return Status string such as "OK", "OVP!", "OCP!", etc.
   */
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
}
