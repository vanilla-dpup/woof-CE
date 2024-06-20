#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>
#include <linux/uinput.h>
#include <stdlib.h>

int main(int argc, char *argv[])
{
	struct uinput_setup setup = {.name = "altf1"};
	struct input_event event = {0};
	int uinput, ret = EXIT_FAILURE;

	uinput = open("/dev/uinput", O_WRONLY | O_NONBLOCK);
	if (uinput < 0)
		return EXIT_FAILURE;

	if ((ioctl(uinput, UI_SET_EVBIT, EV_KEY) < 0) ||
	    (ioctl(uinput, UI_SET_KEYBIT, KEY_LEFTALT) < 0) ||
	    (ioctl(uinput, UI_SET_KEYBIT, KEY_F1) < 0) ||
	    (ioctl(uinput, UI_DEV_SETUP, &setup) < 0) ||
	    (ioctl(uinput, UI_DEV_CREATE) < 0)) {
		close(uinput);
		return EXIT_FAILURE;
	}

	usleep(100000);

	event.type = EV_KEY;
	event.code = KEY_LEFTALT;
	event.value = 1;

	if (write(uinput, &event, sizeof(event)) != sizeof(event))
		goto end;

	event.code = KEY_F1;

	if (write(uinput, &event, sizeof(event)) != sizeof(event))
		goto end;

	event.type = EV_SYN;
	event.code = SYN_REPORT;
	event.value = 0;

	if (write(uinput, &event, sizeof(event)) != sizeof(event))
		goto end;

	event.type = EV_KEY;
	event.code = KEY_F1;
	event.value = 0;

	if (write(uinput, &event, sizeof(event)) != sizeof(event))
		goto end;

	event.code = KEY_LEFTALT;

	if (write(uinput, &event, sizeof(event)) != sizeof(event))
		goto end;

	event.type = EV_SYN;
	event.code = SYN_REPORT;
	event.value = 0;

	if (write(uinput, &event, sizeof(event)) != sizeof(event))
		goto end;

	ret = EXIT_SUCCESS;

end:
	ioctl(uinput, UI_DEV_DESTROY);
	close(uinput);

	return ret;
}
