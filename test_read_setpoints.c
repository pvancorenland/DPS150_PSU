/*
 * test_read_setpoints.c — Request and read Vset (0xC1) and Iset (0xC2)
 * PSU should have V=5.00, I=1.000 set.
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

float to_float(unsigned char *b) {
    float f; memcpy(&f, b, 4); return f;
}

void send_read(int fd, int reg) {
    unsigned char msg[6];
    msg[0] = 0xF1;
    msg[1] = 0xA1;
    msg[2] = reg;
    msg[3] = 0x01;
    msg[4] = 0x00;
    msg[5] = (msg[2] + msg[3] + msg[4]) & 0xFF;
    printf("  TX read 0x%02X: ", reg);
    for (int i = 0; i < 6; i++) printf("%02X ", msg[i]);
    printf("\n");
    write(fd, msg, 6);
}

/* Read and parse all packets for up to timeout_ms, print each one */
void drain_packets(int fd, int timeout_ms) {
    unsigned char buf[4096];
    int total = 0;
    /* Use select() for non-blocking reads with timeout */
    int elapsed = 0;
    while (elapsed < timeout_ms && total < (int)sizeof(buf) - 256) {
        fd_set fds;
        struct timeval tv;
        FD_ZERO(&fds);
        FD_SET(fd, &fds);
        tv.tv_sec = 0;
        tv.tv_usec = 50000; /* 50ms chunks */
        int ret = select(fd + 1, &fds, NULL, NULL, &tv);
        elapsed += 50;
        if (ret > 0) {
            int n = read(fd, buf + total, 256);
            if (n > 0) total += n;
        }
    }

    /* Parse packets */
    for (int i = 0; i < total - 4; ) {
        if (buf[i] != 0xF0) { i++; continue; }
        int cmd = buf[i+1];
        int reg = buf[i+2];
        int dlen = buf[i+3];
        int pktlen = 4 + dlen + 1;
        if (i + pktlen > total) break;

        printf("  RX: cmd=0x%02X reg=0x%02X dlen=%d", cmd, reg, dlen);
        if (dlen >= 4) printf("  f1=%.4f", to_float(buf+i+4));
        if (dlen >= 8) printf("  f2=%.4f", to_float(buf+i+8));
        if (dlen >= 12) printf("  f3=%.4f", to_float(buf+i+12));
        if (dlen >= 4 && dlen <= 7) {
            printf("  raw:");
            for (int j = 0; j < dlen; j++) printf(" %02X", buf[i+4+j]);
        }
        printf("\n");
        i += pktlen;
    }
    fflush(stdout);
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

    printf("\n=== Request Vset (0xC1) ===\n"); fflush(stdout);
    send_read(fd, 0xC1);
    drain_packets(fd, 500);

    printf("\n=== Request Iset (0xC2) ===\n"); fflush(stdout);
    send_read(fd, 0xC2);
    drain_packets(fd, 500);

    printf("\n=== Request ALL (0xFF) ===\n"); fflush(stdout);
    send_read(fd, 0xFF);
    drain_packets(fd, 500);

    printf("\n=== Disconnect ===\n"); fflush(stdout);
    write(fd, str_disconnect, 6);
    close(fd);
    printf("Done.\n");
    return 0;
}
