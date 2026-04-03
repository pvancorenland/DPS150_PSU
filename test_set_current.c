/*
 * test_set_current.c — Minimal test: set V+A, turn on, read live, turn off
 */
#include <stdio.h>
#include <unistd.h>
#include <termios.h>
#include <string.h>
#include <stdlib.h>
#include <fcntl.h>
#include <signal.h>

unsigned char str_connect[]    = {0xF1, 0xC1, 0x00, 0x01, 0x01, 0x02};
unsigned char str_on[]         = {0xF1, 0xB1, 0xDB, 0x01, 0x01, 0xDD};
unsigned char str_off[]        = {0xF1, 0xB1, 0xDB, 0x01, 0x00, 0xDC};
unsigned char str_disconnect[] = {0xF1, 0xC1, 0x00, 0x01, 0x00, 0x01};

void switch_to_raw(int fd) {
    struct termios raw;
    tcgetattr(fd, &raw);
    raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
    raw.c_oflag &= ~(OPOST);
    raw.c_cflag |= (CS8);
    raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 8;
    tcsetattr(fd, TCSAFLUSH, &raw);
}

unsigned char calc_checksum(unsigned char *b, int len) {
    unsigned char c = 0;
    for (int i = 2; i < len; i++) c += b[i];
    return c;
}

void dump_hex(const char *label, unsigned char *buf, int len) {
    printf("  %s: ", label);
    for (int i = 0; i < len; i++) printf("%02X ", buf[i]);
    printf("\n");
}

/* Read one live status frame (syncs on F0 A1 C3 0C) */
int read_live(int fd) {
    int i = 0;
    unsigned char buf[32];
    for (int attempt = 0; attempt < 200; attempt++) {
        if (read(fd, buf+i, 1) != 1) { usleep(5000); continue; }
        i++;
        switch(i) {
            case 1: if (buf[0] != 0xF0) i=0; break;
            case 2: if (buf[1] != 0xA1) i=0; break;
            case 3: if (buf[2] != 0xC3) i=0; break;
            case 4: if (buf[3] != 0x0C) i=0; break;
            case 17:
                dump_hex("RX", buf, 17);
                printf("  Live: V=%.3f  A=%.3f  W=%.3f\n",
                    *(float*)(buf+4), *(float*)(buf+8), *(float*)(buf+12));
                return 1;
        }
        if (i > 20) { i = 0; }
    }
    printf("  Timeout reading live status\n");
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc < 4) {
        printf("Usage: %s <device> <voltage> <current>\n", argv[0]);
        return 1;
    }
    float val_v, val_a;
    sscanf(argv[2], "%f", &val_v);
    sscanf(argv[3], "%f", &val_a);

    signal(SIGALRM, SIG_DFL);
    alarm(15);
    printf("Opening %s ...\n", argv[1]);
    fflush(stdout);
    int fd = open(argv[1], O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (fd < 0) { perror("open"); return 1; }
    /* Clear non-blocking after open */
    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK);
    printf("Port opened.\n");
    fflush(stdout);

    /* Set baud rate */
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

    /* Drain any stale data */
    { unsigned char junk[256]; while(read(fd, junk, sizeof(junk)) > 0); }

    /* Connect */
    printf("1. Connect\n"); fflush(stdout);
    write(fd, str_connect, 6);
    usleep(200000);

    /* Set voltage: F1 B1 C1 04 [float LE] [chk] */
    printf("2. Set voltage = %.3f V\n", val_v); fflush(stdout);
    {
        unsigned char msg[9] = {0xF1, 0xB1, 0xC1, 0x04};
        memcpy(msg+4, &val_v, 4);
        msg[8] = calc_checksum(msg, 8);
        dump_hex("TX", msg, 9);
        write(fd, msg, 9);
    }
    usleep(100000);

    /* Set current: F1 B1 C2 04 [float LE] [chk] */
    printf("3. Set current = %.3f A (method 1: B1/C2)\n", val_a); fflush(stdout);
    {
        unsigned char msg[9] = {0xF1, 0xB1, 0xC2, 0x04};
        memcpy(msg+4, &val_a, 4);
        msg[8] = calc_checksum(msg, 8);
        dump_hex("TX", msg, 9);
        write(fd, msg, 9);
    }
    usleep(100000);

    /* Turn on */
    printf("4. Output ON\n"); fflush(stdout);
    write(fd, str_on, 6);
    usleep(500000);

    /* Read live */
    printf("5. Read live status\n"); fflush(stdout);
    read_live(fd);

    /* Turn off */
    printf("6. Output OFF\n"); fflush(stdout);
    write(fd, str_off, 6);
    usleep(100000);

    /* Now try alternate method for current: F1 B0 DE 04 [float] [chk] */
    printf("7. Set current = %.3f A (method 2: B0/DE)\n", val_a); fflush(stdout);
    {
        unsigned char msg[9] = {0xF1, 0xB0, 0xDE, 0x04};
        memcpy(msg+4, &val_a, 4);
        msg[8] = calc_checksum(msg, 8);
        dump_hex("TX", msg, 9);
        write(fd, msg, 9);
    }
    usleep(100000);

    /* Turn on again */
    printf("8. Output ON\n"); fflush(stdout);
    write(fd, str_on, 6);
    usleep(500000);

    /* Read live */
    printf("9. Read live status (after method 2)\n"); fflush(stdout);
    read_live(fd);

    /* Turn off and disconnect */
    printf("10. Output OFF + Disconnect\n"); fflush(stdout);
    write(fd, str_off, 6);
    usleep(100000);
    write(fd, str_disconnect, 6);
    close(fd);
    printf("Done.\n");
    return 0;
}
