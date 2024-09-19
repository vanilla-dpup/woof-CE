#!/bin/ash

#set -x

run_desktop() {
	hidden=
	exec=
	while read j
	do
		case $j in
		"Hidden="*)
			hidden="${j#Hidden=}"
			[ -n "$exec" ] && break
			;;
		"Exec="*)
			exec="${j#Exec=}"
			[ -n "$hidden" ] && break
			;;
		esac
	done < "$1"
	[ -n "$exec" -a "$hidden" != "true" ] && ash -c "$exec" &
}

#=================================================

for i in /etc/xdg/autostart/*.desktop
do
	if ! [ -f $i ] ; then
		continue
	fi
	case "$i" in
	/etc/xdg/autostart/blueman.desktop|/etc/xdg/autostart/org.gnome.Software.desktop) continue ;;
	esac
	run_desktop $i
done

#=================================================

for i in $HOME/.config/autostart/*.desktop
do
	if ! [ -f $i ] ; then
		continue
	fi
	if [ -f /etc/xdg/autostart/${i} ] ; then
		continue
	fi
	run_desktop $i
done

### END ###