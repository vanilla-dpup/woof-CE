#120221 moved this code here from /etc/profile, also take 'exec' prefix off call to xwin.

export PATH="$PATH:/usr/local/games:/usr/games"
[ -d $XDG_DATA_HOME/flatpak/exports/bin ] && export PATH="$PATH:$XDG_DATA_HOME/flatpak/exports/bin"
[ -d /var/lib/flatpak/exports/bin ] && export PATH="$PATH:/var/lib/flatpak/exports/bin"

if [ ! -f /tmp/bootcnt.txt ] ; then
	touch /tmp/bootcnt.txt
	startdwl
else
	pm13 cli
fi

### END ###
