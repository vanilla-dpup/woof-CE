#include <sched.h>
#include <poll.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>

#define TRIGGER "some 100000 1000000"

int main(int argc, char *argv[]) {
	struct sched_param param;
	struct pollfd pfd = {.events = POLLPRI};

	param.sched_priority = sched_get_priority_min(SCHED_FIFO);
	if (sched_setscheduler(0, SCHED_FIFO, &param) < 0 || (pfd.fd = open("/proc/pressure/memory", O_RDWR)) < 0 || daemon(0, 0) < 0)
		return EXIT_FAILURE;

	if (write(pfd.fd, TRIGGER, sizeof(TRIGGER) -1) != sizeof(TRIGGER) -1) {
		close(pfd.fd);
		return EXIT_FAILURE;
	}

	while (poll(&pfd, 1, -1) > 0 && !(pfd.revents & POLLPRI));

	close(pfd.fd);
	execl("/usr/bin/killall", "/usr/bin/killall", "-9", "sfslock", (char *)NULL);
	return EXIT_FAILURE;
}
