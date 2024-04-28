#!/bin/bash
# suspend.sh 28sep09 by shinobar
# 12feb10 pass poweroff
# 23apr12 fix was not suspend from acpi_poweroff.sh
#20140526 shinobar: avoid multiple run
#20140629 shinobar: ACPI_CONFIG
ACPI_CONFIG=/etc/acpi/acpi.conf
[ -s "$ACPI_CONFIG" ] && . "$ACPI_CONFIG"

case "$(awk '{print $2}' /proc/acpi/button/lid/LID0/state)" in
# if the lid is closed:
#  if an external monitor is connected and enabled:
#   turn off the internal display
#  otherwise
#   suspend and let the screen locker take care of turning off the internal display while locked
closed)
  if [ -n "`comm -12 <(grep -l '^connected$' /sys/class/drm/*/status | cut -f 5 -d / | sort) <(grep -l '^enabled$' /sys/class/drm/*/enabled | cut -f 5 -d / | sort) | grep -Fv -e eDP -e LVDS`" ]; then
    if [ -n "$WAYLAND_DISPLAY" ]; then
      wlr-randr --output eDP-1 --off || wlr-randr --output eDP1 --off || wlr-randr --output LVDS-1 --off || wlr-randr --output LVDS1 --off
    elif [ -n "$DISPLAY" ]; then
      xrandr --output eDP-1 --off || xrandr --output eDP1 --off || xrandr --output LVDS-1 --off || xrandr --output LVDS1 --off
    fi
    touch /tmp/.lid-closed
    DISABLE_SUSPEND=y
  fi
  ;;
# if the lid is opened:
#  turn on the previously disabled internal display
# (we must do this because we don't know if the laptop was supended while connected to an external monitor)
open)
  if [ -f /tmp/.lid-closed ]; then
    if [ -n "$WAYLAND_DISPLAY" ]; then
      wlr-randr --output eDP-1 --on || wlr-randr --output eDP1 --on || wlr-randr --output LVDS-1 --on || wlr-randr --output LVDS1 --on
    elif [ -n "$DISPLAY" ]; then
      xrandr --output eDP-1 --auto || xrandr --output eDP1 --auto || xrandr --output LVDS-1 --auto || xrandr --output LVDS1 --auto
    fi
    rm -f /tmp/.lid-closed
  fi
  DISABLE_SUSPEND=y
  ;;
esac

case "$DISABLE_SUSPEND" in
y*|Y*|true|True|TRUE|1) exit;;
esac

#avoid multiple run
LOCKFILE=/tmp/acpi_suspend-flg
if [ -f "$LOCKFILE" ]; then
  PID=$(cat "$LOCKFILE")
  ps| grep "^[ ]*$PID " && exit
fi
echo -n $$ > "$LOCKFILE"
sync
[ "$(cat "$LOCKFILE")" = $$ ] || exit 0 

# do not suspend at shutdown proccess
#111129 added suspend to acpi_poweroff.sh
PS=$(ps)
[ ! -f /tmp/suspend ] && echo "$PS"| grep -qE 'sh[ ].*poweroff' && rm -f "$LOCKFILE" && exit 0
rm -f /tmp/suspend

. /etc/DISTRO_SPECS

# do not suspend if usb media mounted
if [ "$DISTRO_TARGETARCH" = "x86" ]; then
	USBS=$(probedisk2|grep '|usb' | cut -d'|' -f1 )
	for USB in $USBS
	do
		mount | grep -q "^$USB" && rm -f "$LOCKFILE" && exit 0
	done
fi

# process before suspend
# sync for non-usb drives
sync
[ "$DISTRO_TARGETARCH" = "x86" ] && rmmod ehci_hcd

#suspend
case "$DISABLE_LOCK" in
y*|Y*|true|True|TRUE|1) echo -n mem > /sys/power/state ;;
*)
  if [ -n "$WAYLAND_DISPLAY" ]; then
    puplock
    echo mem > /sys/power/state
  elif [ -n "$DISPLAY" -a -z "`pidof -s xlock`" ]; then
    xlock -startCmd "echo mem > /sys/power/state"
  else
    echo -n mem > /sys/power/state
  fi
  ;;
esac

# process at recovery from suspend
#restartwm
[ "$DISTRO_TARGETARCH" = "x86" ] && modprobe ehci_hcd
#/etc/rc.d/rc.network restart

rm -f "$LOCKFILE"
