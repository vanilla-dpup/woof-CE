#120221 moved this code here from /etc/profile, also take 'exec' prefix off call to xwin.

export PATH="$PATH:/usr/local/games:/usr/games"
[ -d /var/lib/flatpak/exports/bin ] && export PATH="$PATH:/var/lib/flatpak/exports/bin"

if command -v startlabwc >/dev/null 2>&1 ; then
	if [ ! -f /tmp/bootcnt.txt ] ; then
		touch /tmp/bootcnt.txt
		startlabwc
	else
		/usr/sbin/pm13 cli
	fi
elif command -v startdwl >/dev/null 2>&1 ; then
	if [ ! -f /tmp/bootcnt.txt ] ; then
		touch /tmp/bootcnt.txt
		startdwl
	else
		/usr/sbin/pm13 cli
	fi
else
	/usr/sbin/pm13 cli
fi

### END ###
