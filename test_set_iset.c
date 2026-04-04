/*
 * test_set_iset.c — Set current, then read it back to verify
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

void send_set_current(int fd, float val) {
    unsigned char msg[9] = {0xF1, 0xB1, 0xC2, 0x04};
    memcpy(msg+4, &val, 4);
    unsigned char chk = 0;
    for (int i = 2; i < 8; i++) chk += msg[i];
    msg[8] = chk;
    printf("  TX set current: ");
    for (int i = 0; i < 9; i++) printf("%02X ", msg[i]);
    printf("\n");
    write(fd, msg, 9);
}

/* Find a response packet with the given register, return float value.
 * Searches through streamed data for up to timeout_ms. */
float read_register(int fd, int target_reg, int timeout_ms) {
    unsigned char buf[4096];
    int total = 0;
    int elapsed = 0;
    while (elapsed < timeout_ms && total < (int)sizeof(buf) - 256) {
        fd_set fds; struct timeval tv;
        FD_ZERO(&fds); FD_SET(fd, &fds);
        tv.tv_sec = 0; tv.tv_usec = 50000;
        if (select(fd+1, &fds, NULL, NULL, &tv) > 0) {
            int n = read(fd, buf + total, 256);
            if (n > 0) total += n;
        }
        elapsed += 50;
    }
    /* Parse looking for target_reg */
    for (int i = 0; i < total - 4; ) {
        if (buf[i] != 0xF0) { i++; continue; }
        int reg = buf[i+2];
        int dlen = buf[i+3];
        int pktlen = 4 + dlen + 1;
        if (i + pktlen > total) break;
        if (reg == target_reg && dlen >= 4) {
            float val = to_float(buf + i + 4);
            printf("  RX reg=0x%02X: %.4f\n", reg, val);
            return val;
        }
        i += pktlen;
    }
    printf("  RX reg=0x%02X: NOT FOUND in %d bytes\n", target_reg, total);
    return -1;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s <device>\n", argv[0]);
        return 1;
    }
    alarm(20);
    int fd = open_port(argv[1]);
    if (fd < 0) return 1;
    { unsigned char junk[4096]; while(read(fd, junk, sizeof(junk)) > 0); }

    printf("=== Connect ===\n"); fflush(stdout);
    write(fd, str_connect, 6);
    usleep(500000);
    { unsigned char junk[4096]; while(read(fd, junk, sizeof(junk)) > 0); }

    /* 1. Read current Iset */
    printf("\n=== Read current Iset (0xC2) ===\n"); fflush(stdout);
    send_read(fd, 0xC2);
    float iset_before = read_register(fd, 0xC2, 500);

    /* 2. Set to 2.0A */
    printf("\n=== Set Iset to 2.0A ===\n"); fflush(stdout);
    send_set_current(fd, 2.0f);
    usleep(200000);
    { unsigned char junk[4096]; while(read(fd, junk, sizeof(junk)) > 0); }

    /* 3. Read back Iset */
    printf("\n=== Read Iset after set (0xC2) ===\n"); fflush(stdout);
    send_read(fd, 0xC2);
    float iset_after = read_register(fd, 0xC2, 500);

    printf("\n=== Result: Iset before=%.4f, after=%.4f ===\n", iset_before, iset_after);
    if (iset_after > 1.99 && iset_after < 2.01) {
        printf("SUCCESS: Current setpoint changed!\n");
    } else {
        printf("FAILED: Current setpoint did NOT change.\n");
    }

    /* 4. Set back to 1.0A */
    printf("\n=== Restore Iset to 1.0A ===\n"); fflush(stdout);
    send_set_current(fd, 1.0f);
    usleep(200000);
    { unsigned char junk[4096]; while(read(fd, junk, sizeof(junk)) > 0); }
    send_read(fd, 0xC2);
    float iset_restored = read_register(fd, 0xC2, 500);
    printf("Restored: %.4f\n", iset_restored);

    write(fd, str_disconnect, 6);
    close(fd);
    printf("\nDone.\n");
    return 0;
}
