/*
 * test_live_stream.c — Read live frames continuously, try different read commands
 * to find where set voltage vs set current come from.
 *
 * PSU should have V=5.00, I=1.000 set, output OFF, no load.
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
    tio.c_cc[VTIME] = 3;
    tcsetattr(fd, TCSAFLUSH, &tio);
    tcflush(fd, TCIOFLUSH);
    return fd;
}

float to_float(unsigned char *b) {
    float f;
    memcpy(&f, b, 4);
    return f;
}

void dump_hex(unsigned char *buf, int len) {
    for (int i = 0; i < len; i++) printf("%02X ", buf[i]);
}

/* Read all available data from serial, print any complete packets found.
 * Returns number of packets found. */
int drain_and_print(int fd, int max_packets) {
    unsigned char raw[4096];
    int total = 0;
    int packets = 0;

    /* Read all available data */
    while (total < (int)sizeof(raw) - 256) {
        int n = read(fd, raw + total, 256);
        if (n <= 0) break;
        total += n;
    }

    if (total == 0) {
        printf("  (no data)\n");
        return 0;
    }

    printf("  Raw %d bytes: ", total);
    dump_hex(raw, total > 80 ? 80 : total);
    if (total > 80) printf("...");
    printf("\n");

    /* Find packets starting with F0 */
    for (int i = 0; i < total - 4 && packets < max_packets; ) {
        if (raw[i] != 0xF0) { i++; continue; }
        int cmd = raw[i+1];
        int reg = raw[i+2];
        int dlen = raw[i+3];
        int pktlen = 4 + dlen + 1;
        if (i + pktlen > total) break;

        printf("  PKT: cmd=0x%02X reg=0x%02X dlen=%d  data: ", cmd, reg, dlen);
        for (int j = 0; j < dlen && j < 32; j++) printf("%02X ", raw[i+4+j]);

        if (dlen >= 4) printf(" | f1=%.4f", to_float(raw+i+4));
        if (dlen >= 8) printf(" f2=%.4f", to_float(raw+i+8));
        if (dlen >= 12) printf(" f3=%.4f", to_float(raw+i+12));
        printf("\n");

        packets++;
        i += pktlen;
    }

    fflush(stdout);
    return packets;
}

void send_read(int fd, int reg) {
    unsigned char msg[6];
    msg[0] = 0xF1;
    msg[1] = 0xA1;
    msg[2] = reg;
    msg[3] = 0x01;
    msg[4] = 0x00;
    msg[5] = (msg[2] + msg[3] + msg[4]) & 0xFF;
    write(fd, msg, 6);
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s <device>\n", argv[0]);
        return 1;
    }
    alarm(30);
    int fd = open_port(argv[1]);
    if (fd < 0) return 1;

    /* Drain stale */
    { unsigned char junk[4096]; while(read(fd, junk, sizeof(junk)) > 0); }

    printf("=== Connect ===\n"); fflush(stdout);
    write(fd, str_connect, 6);
    usleep(500000);

    /* 1. Just wait and see if PSU sends anything without being asked */
    printf("\n=== Passive listen (1s, no requests sent) ===\n"); fflush(stdout);
    usleep(1000000);
    drain_and_print(fd, 10);

    /* 2. Send read for 0xC3 (live) */
    printf("\n=== Read 0xC3 (live values) ===\n"); fflush(stdout);
    send_read(fd, 0xC3);
    usleep(200000);
    drain_and_print(fd, 5);

    /* 3. Try 0xC0 */
    printf("\n=== Read 0xC0 (set voltage?) ===\n"); fflush(stdout);
    send_read(fd, 0xC0);
    usleep(200000);
    drain_and_print(fd, 5);

    /* 4. Try 0xDE */
    printf("\n=== Read 0xDE (set current?) ===\n"); fflush(stdout);
    send_read(fd, 0xDE);
    usleep(200000);
    drain_and_print(fd, 5);

    /* 5. Try B0 command type instead of A1 for reads */
    printf("\n=== Read with cmd=0xB0 reg=0xC0 ===\n"); fflush(stdout);
    {
        unsigned char msg[6] = {0xF1, 0xB0, 0xC0, 0x01, 0x00, 0};
        msg[5] = (msg[2] + msg[3] + msg[4]) & 0xFF;
        write(fd, msg, 6);
    }
    usleep(200000);
    drain_and_print(fd, 5);

    /* 6. Try the fnirsi_psu approach: just read status continuously */
    printf("\n=== Read 0xC3 x3 rapid ===\n"); fflush(stdout);
    send_read(fd, 0xC3);
    usleep(50000);
    send_read(fd, 0xC3);
    usleep(50000);
    send_read(fd, 0xC3);
    usleep(300000);
    drain_and_print(fd, 10);

    /* 7. Now set current to 2.0A and see if the live frame changes */
    printf("\n=== Set current to 2.0A ===\n"); fflush(stdout);
    {
        float val = 2.0f;
        unsigned char msg[9] = {0xF1, 0xB1, 0xC2, 0x04};
        memcpy(msg+4, &val, 4);
        unsigned char chk = 0;
        for (int i = 2; i < 8; i++) chk += msg[i];
        msg[8] = chk;
        write(fd, msg, 9);
    }
    usleep(200000);

    printf("\n=== Read 0xC3 after set current ===\n"); fflush(stdout);
    send_read(fd, 0xC3);
    usleep(200000);
    drain_and_print(fd, 5);

    /* 8. Set it back to 1.0A */
    printf("\n=== Set current back to 1.0A ===\n"); fflush(stdout);
    {
        float val = 1.0f;
        unsigned char msg[9] = {0xF1, 0xB1, 0xC2, 0x04};
        memcpy(msg+4, &val, 4);
        unsigned char chk = 0;
        for (int i = 2; i < 8; i++) chk += msg[i];
        msg[8] = chk;
        write(fd, msg, 9);
    }
    usleep(200000);
    send_read(fd, 0xC3);
    usleep(200000);
    drain_and_print(fd, 5);

    /* Disconnect */
    printf("\n=== Disconnect ===\n"); fflush(stdout);
    write(fd, str_disconnect, 6);
    close(fd);
    printf("Done.\n");
    return 0;
}
