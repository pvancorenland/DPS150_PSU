/*
 * test_read_regs.c — Read various registers to find set voltage vs input voltage
 */
#include <stdio.h>
#include <unistd.h>
#include <termios.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <signal.h>

unsigned char str_connect[] = {0xF1, 0xC1, 0x00, 0x01, 0x01, 0x02};
unsigned char str_disconnect[] = {0xF1, 0xC1, 0x00, 0x01, 0x00, 0x01};

int open_port(const char *dev) {
    int fd = open(dev, O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fd < 0) { perror("open"); return -1; }
    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK);
    struct termios tio;
    tcgetattr(fd, &tio);
    cfsetispeed(&tio, B115200);
    cfsetospeed(&tio, B115200);
    tio.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
    tio.c_oflag &= ~(OPOST);
    tio.c_cflag &= ~(CSIZE | PARENB);
    tio.c_cflag |= (CS8 | CLOCAL | CREAD);
    tio.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
    tio.c_cc[VMIN] = 0;
    tio.c_cc[VTIME] = 5;
    tcsetattr(fd, TCSAFLUSH, &tio);
    tcflush(fd, TCIOFLUSH);
    return fd;
}

void dump_hex(const char *label, unsigned char *buf, int len) {
    printf("  %s: ", label);
    for (int i = 0; i < len; i++) printf("%02X ", buf[i]);
    printf("\n");
}

float to_float(unsigned char *b) {
    float f;
    memcpy(&f, b, 4);
    return f;
}

/* Read one response packet, return total length or 0 on timeout */
int read_response(int fd, unsigned char *buf, int bufsize) {
    int i = 0;
    int expected = 0;
    for (int attempt = 0; attempt < 300; attempt++) {
        if (read(fd, buf + i, 1) != 1) { usleep(5000); continue; }
        if (i == 0 && buf[0] != 0xF0) continue;
        i++;
        if (i == 4) expected = buf[3];  /* data length */
        if (i >= 4 && i >= 4 + expected + 1) return i;
        if (i >= bufsize - 1) { i = 0; continue; }
    }
    return 0;
}

/* Send a read request for a single register */
void send_read(int fd, int reg) {
    unsigned char msg[6];
    msg[0] = 0xF1;
    msg[1] = 0xA1;  /* CMD_READ */
    msg[2] = reg;
    msg[3] = 0x01;
    msg[4] = 0x00;
    msg[5] = (msg[2] + msg[3] + msg[4]) & 0xFF;
    write(fd, msg, 6);
}

void read_and_print(int fd, int reg, const char *name) {
    /* Drain any stale data */
    { unsigned char junk[256]; while(read(fd, junk, sizeof(junk)) > 0); }

    send_read(fd, reg);
    usleep(100000);

    unsigned char buf[256];
    int len = read_response(fd, buf, sizeof(buf));
    if (len == 0) {
        printf("  REG 0x%02X (%s): NO RESPONSE\n", reg, name);
        return;
    }
    dump_hex("raw", buf, len);
    int dataLen = buf[3];
    printf("  REG 0x%02X (%s): dataLen=%d", reg, name, dataLen);
    if (dataLen >= 4) {
        printf("  float=%.4f", to_float(buf + 4));
    }
    if (dataLen >= 1 && dataLen < 4) {
        printf("  byte=%d (0x%02X)", buf[4], buf[4]);
    }
    if (dataLen >= 8) {
        printf("  float2=%.4f", to_float(buf + 8));
    }
    if (dataLen >= 12) {
        printf("  float3=%.4f", to_float(buf + 12));
    }
    printf("\n\n");
    fflush(stdout);
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s <device>\n", argv[0]);
        return 1;
    }
    alarm(30);
    int fd = open_port(argv[1]);
    if (fd < 0) return 1;
    printf("Port opened.\n"); fflush(stdout);

    /* Connect */
    write(fd, str_connect, 6);
    usleep(500000);
    printf("Connected.\n\n"); fflush(stdout);

    /* Read registers 0xC0 through 0xC4 */
    read_and_print(fd, 0xC0, "SET_VOLTAGE (0xC0)");
    read_and_print(fd, 0xC1, "WRITE_VOLT (0xC1)");
    read_and_print(fd, 0xC2, "WRITE_CURR (0xC2)");
    read_and_print(fd, 0xC3, "LIVE_VALUES (0xC3)");
    read_and_print(fd, 0xC4, "TEMPERATURE (0xC4)");

    /* 0xDE = SET_CURRENT in newfnrs docs */
    read_and_print(fd, 0xDE, "SET_CURRENT (0xDE)");

    /* Output and mode */
    read_and_print(fd, 0xDB, "OUTPUT (0xDB)");
    read_and_print(fd, 0xDD, "MODE (0xDD)");
    read_and_print(fd, 0xDC, "PROTECTION (0xDC)");

    /* Protection limits */
    read_and_print(fd, 0xD1, "OVP (0xD1)");
    read_and_print(fd, 0xD2, "OCP (0xD2)");
    read_and_print(fd, 0xD3, "OPP (0xD3)");
    read_and_print(fd, 0xD4, "OTP (0xD4)");

    /* Brightness, capacity */
    read_and_print(fd, 0xD6, "BRIGHTNESS (0xD6)");
    read_and_print(fd, 0xD9, "CAP_AH (0xD9)");
    read_and_print(fd, 0xDA, "CAP_WH (0xDA)");

    /* Max V/A, firmware */
    read_and_print(fd, 0xE0, "FIRMWARE (0xE0)");
    read_and_print(fd, 0xE2, "MAX_VOLT (0xE2)");
    read_and_print(fd, 0xE3, "MAX_CURR (0xE3)");

    /* The big read-all */
    read_and_print(fd, 0xFF, "ALL (0xFF)");

    /* Disconnect */
    write(fd, str_disconnect, 6);
    close(fd);
    printf("Done.\n");
    return 0;
}
