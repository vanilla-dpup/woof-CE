#120221 moved this code here from /etc/profile, also take 'exec' prefix off call to xwin.

export PATH="$PATH:/usr/local/games:/usr/games"
[ -d /var/lib/flatpak/exports/bin ] && export PATH="$PATH:/var/lib/flatpak/exports/bin"
[ -d "$HOME/.local/bin" ] && export PATH="$HOME/.local/bin:$PATH"

if command -v startlabwc >/dev/null 2>&1 ; then
	if [ ! -f /tmp/bootcnt.txt ] ; then
		touch /tmp/bootcnt.txt
		startlabwc
	else
		/usr/local/sbin/pm13 cli
	fi
elif command -v startdwl >/dev/null 2>&1 ; then
	if [ ! -f /tmp/bootcnt.txt ] ; then
		touch /tmp/bootcnt.txt
		startdwl
	else
		/usr/local/sbin/pm13 cli
	fi
else
	/usr/local/sbin/pm13 cli
fi

### END ###
