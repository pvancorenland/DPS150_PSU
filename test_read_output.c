/*
 * test_read_output.c — Read output state, mode, protection
 */
#include <stdio.h>
#include <unistd.h>
#include <termios.h>
#include <string.h>
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

void find_reg(int fd, int target_reg, const char *name, int timeout_ms) {
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
    for (int i = 0; i < total - 4; ) {
        if (buf[i] != 0xF0) { i++; continue; }
        int reg = buf[i+2];
        int dlen = buf[i+3];
        int pktlen = 4 + dlen + 1;
        if (i + pktlen > total) break;
        if (reg == target_reg) {
            printf("  %s (0x%02X): dlen=%d, bytes:", name, reg, dlen);
            for (int j = 0; j < dlen; j++) printf(" %02X", buf[i+4+j]);
            printf("\n");
            return;
        }
        i += pktlen;
    }
    printf("  %s (0x%02X): NOT FOUND\n", name, target_reg);
}

int main(int argc, char *argv[]) {
    if (argc < 2) return 1;
    alarm(15);
    int fd = open_port(argv[1]);
    if (fd < 0) return 1;
    { unsigned char junk[4096]; while(read(fd, junk, sizeof(junk)) > 0); }

    write(fd, str_connect, 6);
    usleep(500000);
    { unsigned char junk[4096]; while(read(fd, junk, sizeof(junk)) > 0); }

    printf("Reading output state, mode, protection:\n"); fflush(stdout);
    send_read(fd, 0xDB);
    find_reg(fd, 0xDB, "OUTPUT", 500);

    send_read(fd, 0xDD);
    find_reg(fd, 0xDD, "MODE", 500);

    send_read(fd, 0xDC);
    find_reg(fd, 0xDC, "PROTECTION", 500);

    send_read(fd, 0xD6);
    find_reg(fd, 0xD6, "BRIGHTNESS", 500);

    write(fd, str_disconnect, 6);
    close(fd);
    printf("Done.\n");
    return 0;
}
