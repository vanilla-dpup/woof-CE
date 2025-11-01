#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
    int fd;
    ssize_t len;

    if ((fd = open("/sys/power/state", O_WRONLY)) < 0) return EXIT_FAILURE;
    len = write(fd, "mem", 3);
    close(fd);
    return len == 3 ? EXIT_SUCCESS : EXIT_FAILURE;
}
