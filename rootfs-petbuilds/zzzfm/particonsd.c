#include <stdlib.h>
#include <poll.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>
#include <time.h>
#include <errno.h>
#include <libudev.h>

static void particons(void)
{
	pid_t pid;

	if ((pid = fork()) > 0) waitpid(pid, NULL, 0);
	else if (pid == 0) {
		execlp("particons", "particons", (char *)NULL);
		exit(EXIT_FAILURE);
	}
}

static void delay(void)
{
	struct timespec req = {.tv_nsec = 100000000}, rem;

	while (nanosleep(&req, &rem) < 0 && errno == EINTR) memcpy(&req, &rem, sizeof(struct timespec));
}

int main(int argc, char *argv[])
{
	struct udev *udev;
	struct udev_monitor *mon;
	struct pollfd pfd = {.events = POLLIN};

	particons();
	delay();

	if (!(udev = udev_new())) return EXIT_FAILURE;

	mon = udev_monitor_new_from_netlink(udev, "udev");
	udev_monitor_filter_add_match_subsystem_devtype(mon, "block", NULL);
	udev_monitor_enable_receiving(mon);
	pfd.fd = udev_monitor_get_fd(mon);

	while (1) {
		pfd.revents = 0;

		if (poll(&pfd, 1, -1) <= 0) break;
		if (!(pfd.revents & POLLIN)) break;

		struct udev_device *dev = udev_monitor_receive_device(mon);
		if (!dev) continue;

		const char *action = udev_device_get_action(dev);
		if (action && (strcmp(action, "add") == 0 || strcmp(action, "remove") == 0)) {
			particons();
			delay();
		}

		udev_device_unref(dev);
	}

	udev_monitor_unref(mon);
	udev_unref(udev);
	return EXIT_SUCCESS;
}
