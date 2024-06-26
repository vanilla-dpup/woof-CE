#include <libinput.h>
#include <dlfcn.h>
#include <stdio.h>

static struct libinput_event *(*next)(struct libinput *libinput);

static enum libinput_config_tap_state tap = LIBINPUT_CONFIG_TAP_ENABLED;
static int natural_scroll = 0;
static float accel = 0;
static enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_FLAT;
static enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;
static enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;
static enum libinput_config_drag_state drag = LIBINPUT_CONFIG_DRAG_DISABLED;
static enum libinput_config_dwt_state dwt = LIBINPUT_CONFIG_DWT_DISABLED;
static enum libinput_config_middle_emulation_state middle_emul = LIBINPUT_CONFIG_MIDDLE_EMULATION_DISABLED;
static int left_handed = 0;

__attribute__((constructor))
static void init(void)
{
	static char line[256];
	FILE *fp;
	int val;
	float fval;

	unsetenv("LD_PRELOAD");

	if ((fp = fopen("/root/.libinputrc", "r"))) {
		while (fgets(line, sizeof(line), fp)) {
			if (sscanf(line, "LIBINPUT_DEFAULT_TAP=%d", &val) == 1) {
				tap = val > 0 ? LIBINPUT_CONFIG_TAP_ENABLED : LIBINPUT_CONFIG_TAP_DISABLED;
				continue;
			}

			if (sscanf(line, "LIBINPUT_DEFAULT_NATURAL_SCROLL=%d", &val) == 1) {
				natural_scroll= val;
				continue;
			}

			if (sscanf(line, "LIBINPUT_DEFAULT_ACCELERATION=%f", &fval) == 1) {
				accel = fval;
				continue;
			}

			if (sscanf(line, "LIBINPUT_DEFAULT_ACCELERATION_PROFILE=%d", &val) == 1) {
				accel_profile = (enum libinput_config_accel_profile)val;
				continue;
			}

			if (sscanf(line, "LIBINPUT_DEFAULT_SCROLL_METHOD=%d", &val) == 1) {
				scroll_method = (enum libinput_config_scroll_method)val;
				continue;
			}

			if (sscanf(line, "LIBINPUT_DEFAULT_CLICK_METHOD=%d", &val) == 1) {
				click_method = (enum libinput_config_click_method)val;
				continue;
			}

			if (sscanf(line, "LIBINPUT_DEFAULT_DRAG=%d", &val) == 1) {
				drag = val > 0 ? LIBINPUT_CONFIG_DRAG_ENABLED : LIBINPUT_CONFIG_DRAG_DISABLED;
				continue;
			}

			if (sscanf(line, "LIBINPUT_DEFAULT_DISABLE_WHILE_TYPING=%d", &val) == 1) {
				dwt = val > 0 ? LIBINPUT_CONFIG_DWT_ENABLED : LIBINPUT_CONFIG_DWT_DISABLED;
				continue;
			}

			if (sscanf(line, "LIBINPUT_DEFAULT_MIDDLE_EMULATION=%d", &val) == 1) {
				middle_emul = val > 0 ? LIBINPUT_CONFIG_MIDDLE_EMULATION_ENABLED : LIBINPUT_CONFIG_MIDDLE_EMULATION_DISABLED;
				continue;
			}

			if (sscanf(line, "LIBINPUT_DEFAULT_LEFT_HANDED=%d", &val) == 1)
				left_handed = val;
		}

		fclose(fp);
	}

	next = dlsym(RTLD_NEXT, "libinput_get_event");
}

struct libinput_event *libinput_get_event(struct libinput *libinput)
{
	struct libinput_event *ev;
	struct libinput_device *dev;

	if (!next || !(ev = next(libinput)))
		return NULL;

	if (libinput_event_get_type(ev) != LIBINPUT_EVENT_DEVICE_ADDED || !(dev = libinput_event_get_device(ev)))
		return ev;

	libinput_device_config_tap_set_enabled(dev, tap);
	libinput_device_config_scroll_set_natural_scroll_enabled(dev, natural_scroll);
	libinput_device_config_accel_set_speed(dev, accel);
	libinput_device_config_accel_set_profile(dev, accel_profile);
	libinput_device_config_scroll_set_method(dev, scroll_method);
	libinput_device_config_click_set_method(dev, click_method);
	libinput_device_config_tap_set_drag_enabled(dev, drag);
	libinput_device_config_dwt_set_enabled(dev, dwt);
	libinput_device_config_middle_emulation_set_enabled(dev, middle_emul);
	libinput_device_config_left_handed_set(dev, left_handed);

	return ev;
}
