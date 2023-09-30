# Configuration Files

## /etc/environment

This file defines environment variables for the user's interactive shell and all descendant processes, including the compositor.

Among other things, this file defines the dwl background and window border color.

## ~/.libinputrc

This file defines input device (mouse and touchpad) settings.

For example, to enable left-handed mode:

	LIBINPUT_DEFAULT_LEFT_HANDED=1

## ~/.xkbrc

This file defines keyboard settings.

For example, to enable English and Hebrew with Alt+Shift to switch between the two:

	XKB_DEFAULT_LAYOUT=us,il
	XKB_DEFAULT_OPTIONS=grp:alt_shift_toggle

## ~/.config/autostart/swayidle.desktop

This configures auto-start of swayidle, which turns off the screen after 600 seconds of inactivity.

You can disable swayidle by deleting this file, or change the interval via ~/.config/swayidle/config.

## ~/.config/autostart/swaybg.desktop

This configures auto-start of swaybg and defines the background color or image to display.

## /etc/init.d/trim

This script runs at boot time and implements periodic TRIM.

To disable it:

	chmod -x /etc/init.d/trim

## /etc/rc.d/rc.local

This script can be used to run extra initialization steps at the end of the boot process.

## /etc/eventmanager

This file determines whether or not to offer the user to save on shutdown, when using PUPMODE 13.

To disable the prompt and skip saving on shutdown:

	ASKTOSAVE=false

## ~/.dwlinitrc

This script runs as dwl's child process and handles application auto-start.

## /var/local/xwin_disable_xerrs_log_flag

Delete this file to enable logging of compositor errors to /tmp/xerrs.log.
