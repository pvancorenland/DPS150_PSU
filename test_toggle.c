/*
 * test_toggle.c — Toggle output ON, read state, toggle OFF, read state
 */
#include <stdio.h>
#include <unistd.h>
#include <termios.h>
#include <string.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/select.h>

unsigned char str_connect[] = {0xF1, 0xC1, 0x00, 0x01, 0x01, 0x02};
unsigned char str_on[]  = {0xF1, 0xB1, 0xDB, 0x01, 0x01, 0xDD};
unsigned char str_off[] = {0xF1, 0xB1, 0xDB, 0x01, 0x00, 0xDC};
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
    tio.c_cc[VMIN] = 0; tio.c_cc[VTIME] = 3;
    tcsetattr(fd, TCSAFLUSH, &tio);
    tcflush(fd, TCIOFLUSH);
    return fd;
}

void send_read(int fd, int reg) {
    unsigned char msg[6] = {0xF1, 0xA1, reg, 0x01, 0x00, 0};
    msg[5] = (msg[2] + msg[3] + msg[4]) & 0xFF;
    write(fd, msg, 6);
}

int find_byte_reg(int fd, int target_reg, int timeout_ms) {
    unsigned char buf[4096];
    int total = 0;
    for (int elapsed = 0; elapsed < timeout_ms; elapsed += 50) {
        fd_set fds; struct timeval tv;
        FD_ZERO(&fds); FD_SET(fd, &fds);
        tv.tv_sec = 0; tv.tv_usec = 50000;
        if (select(fd+1, &fds, NULL, NULL, &tv) > 0) {
            int n = read(fd, buf + total, 256);
            if (n > 0) total += n;
        }
    }
    printf("  [%d bytes received] packets: ", total);
    for (int i = 0; i < total - 4; ) {
        if (buf[i] != 0xF0) { i++; continue; }
        int reg = buf[i+2], dlen = buf[i+3], pktlen = 4 + dlen + 1;
        if (i + pktlen > total) break;
        printf("0x%02X(%d) ", reg, dlen);
        if (reg == target_reg && dlen >= 1) {
            printf("\n");
            return buf[i+4];
        }
        i += pktlen;
    }
    printf("\n");
    return -1;
}

int main(int argc, char *argv[]) {
    if (argc < 2) return 1;
    alarm(15);
    int fd = open_port(argv[1]);
    if (fd < 0) return 1;
    { unsigned char junk[4096]; while(read(fd, junk, sizeof(junk)) > 0); }

    /* Disconnect first in case PSU is in a stale session */
    write(fd, str_disconnect, 6);
    usleep(200000);
    { unsigned char junk[4096]; while(read(fd, junk, sizeof(junk)) > 0); }
    write(fd, str_connect, 6);
    usleep(500000);

    /* Verify stream is active by checking for any data */
    {
        unsigned char tmp[4096];
        int total = 0;
        for (int elapsed = 0; elapsed < 500; elapsed += 50) {
            fd_set fds; struct timeval tv;
            FD_ZERO(&fds); FD_SET(fd, &fds);
            tv.tv_sec = 0; tv.tv_usec = 50000;
            if (select(fd+1, &fds, NULL, NULL, &tv) > 0) {
                int n = read(fd, tmp + total, 256);
                if (n > 0) total += n;
            }
        }
        printf("Stream check: %d bytes received after connect\n", total);
        fflush(stdout);
    }

    /* Read initial state */
    send_read(fd, 0xDB);
    int state0 = find_byte_reg(fd, 0xDB, 500);
    printf("Initial output state: %d\n", state0); fflush(stdout);

    /* Turn ON */
    printf("Sending ON...\n"); fflush(stdout);
    write(fd, str_on, 6);
    usleep(500000);
    { unsigned char junk[4096]; while(read(fd, junk, sizeof(junk)) > 0); }
    send_read(fd, 0xDB);
    int state1 = find_byte_reg(fd, 0xDB, 500);
    printf("After ON: %d\n", state1); fflush(stdout);

    /* Turn OFF */
    printf("Sending OFF...\n"); fflush(stdout);
    write(fd, str_off, 6);
    usleep(500000);
    { unsigned char junk[4096]; while(read(fd, junk, sizeof(junk)) > 0); }
    send_read(fd, 0xDB);
    int state2 = find_byte_reg(fd, 0xDB, 500);
    printf("After OFF: %d\n", state2); fflush(stdout);

    write(fd, str_disconnect, 6);
    close(fd);
    printf("Done.\n");
    return 0;
}
