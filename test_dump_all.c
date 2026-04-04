/*
 * test_dump_all.c — Dump the full 0xFF ALL response with offset labels
 * Run with output ON, then again with output OFF to find the output state byte.
 */
#include <stdio.h>
#include <unistd.h>
#include <termios.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/select.h>

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

float to_float(unsigned char *b) { float f; memcpy(&f, b, 4); return f; }

void send_read(int fd, int reg) {
    unsigned char msg[6] = {0xF1, 0xA1, reg, 0x01, 0x00, 0};
    msg[5] = (msg[2] + msg[3] + msg[4]) & 0xFF;
    write(fd, msg, 6);
}

int main(int argc, char *argv[]) {
    if (argc < 2) { printf("Usage: %s <device>\n", argv[0]); return 1; }
    alarm(15);
    int fd = open_port(argv[1]);
    if (fd < 0) return 1;
    { unsigned char junk[4096]; while(read(fd, junk, sizeof(junk)) > 0); }

    write(fd, str_connect, 6);
    usleep(500000);
    { unsigned char junk[4096]; while(read(fd, junk, sizeof(junk)) > 0); }

    printf("=== Request ALL (0xFF) ===\n"); fflush(stdout);
    send_read(fd, 0xFF);

    /* Collect data */
    unsigned char buf[4096];
    int total = 0;
    for (int elapsed = 0; elapsed < 1000; elapsed += 50) {
        fd_set fds; struct timeval tv;
        FD_ZERO(&fds); FD_SET(fd, &fds);
        tv.tv_sec = 0; tv.tv_usec = 50000;
        if (select(fd+1, &fds, NULL, NULL, &tv) > 0) {
            int n = read(fd, buf + total, 256);
            if (n > 0) total += n;
        }
    }

    /* Find the ALL response packet */
    for (int i = 0; i < total - 4; ) {
        if (buf[i] != 0xF0) { i++; continue; }
        int reg = buf[i+2];
        int dlen = buf[i+3];
        int pktlen = 4 + dlen + 1;
        if (i + pktlen > total) break;

        if (reg == 0xFF && dlen >= 100) {
            unsigned char *d = buf + i + 4;  /* data starts here */
            printf("ALL response: %d data bytes\n\n", dlen);

            /* Print as floats in groups of 4 */
            printf("Known offsets:\n");
            printf("  [  0] Input V:  %.4f\n", to_float(d+0));
            printf("  [  4] Set V:    %.4f\n", to_float(d+4));
            printf("  [  8] Set I:    %.4f\n", to_float(d+8));
            printf("  [ 12] Live V:   %.4f\n", to_float(d+12));
            printf("  [ 16] Live I:   %.4f\n", to_float(d+16));
            printf("  [ 20] Live W:   %.4f\n", to_float(d+20));
            printf("  [ 24] Temp:     %.4f\n", to_float(d+24));
            printf("  [ 28] P1 V:     %.4f\n", to_float(d+28));
            printf("  [ 32] P1 I:     %.4f\n", to_float(d+32));
            printf("  [ 36] P2 V:     %.4f\n", to_float(d+36));
            printf("  [ 40] P2 I:     %.4f\n", to_float(d+40));
            printf("  [ 44] P3 V:     %.4f\n", to_float(d+44));
            printf("  [ 48] P3 I:     %.4f\n", to_float(d+48));
            printf("  [ 52] P4 V:     %.4f\n", to_float(d+52));
            printf("  [ 56] P4 I:     %.4f\n", to_float(d+56));
            printf("  [ 60] P5 V:     %.4f\n", to_float(d+60));
            printf("  [ 64] P5 I:     %.4f\n", to_float(d+64));
            printf("  [ 68] P6 V:     %.4f\n", to_float(d+68));
            printf("  [ 72] P6 I:     %.4f\n", to_float(d+72));
            printf("  [ 76] Max V:    %.4f\n", to_float(d+76));
            printf("  [ 80] Max I:    %.4f\n", to_float(d+80));
            printf("  [ 84] OVP:      %.4f\n", to_float(d+84));
            printf("  [ 88] OCP:      %.4f\n", to_float(d+88));
            printf("  [ 92] OPP:      %.4f\n", to_float(d+92));
            printf("  [ 96] OTP:      %.4f\n", to_float(d+96));

            printf("\nRemaining bytes (offset 100+):\n");
            for (int j = 100; j < dlen; j++) {
                printf("  [%3d] 0x%02X (%3d)", j, d[j], d[j]);
                if (j + 3 < dlen) printf("  float=%.4f", to_float(d+j));
                printf("\n");
            }

            printf("\nFull hex dump:\n");
            for (int j = 0; j < dlen; j++) {
                if (j % 16 == 0) printf("  %3d: ", j);
                printf("%02X ", d[j]);
                if (j % 16 == 15) printf("\n");
            }
            printf("\n");
            break;
        }
        i += pktlen;
    }

    write(fd, str_disconnect, 6);
    close(fd);
    printf("Done.\n");
    return 0;
}
