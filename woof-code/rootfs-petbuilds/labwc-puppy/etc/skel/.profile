#120221 moved this code here from /etc/profile, also take 'exec' prefix off call to xwin.

. /etc/rc.d/PUPSTATE
if [ $PUPMODE -eq 13 -a ! -s ~/Desktop/save2flash.desktop ]; then
	cat << EOF > ~/Desktop/save2flash.desktop
[Desktop Entry]
Encoding=UTF-8
Name=Save
Icon=/usr/share/pixmaps/puppy/save.svg
Exec=save2flash
Terminal=false
Type=Application
EOF
	chmod 644 ~/Desktop/save2flash.desktop
elif [ $PUPMODE -ne 13 ]; then
	rm -f ~/Desktop/save2flash.desktop
fi

export PATH="$PATH:/usr/local/games:/usr/games"
[ -d $XDG_DATA_HOME/flatpak/exports/bin ] && export PATH="$PATH:$XDG_DATA_HOME/flatpak/exports/bin"
[ -d /var/lib/flatpak/exports/bin ] && export PATH="$PATH:/var/lib/flatpak/exports/bin"

if [ ! -f /tmp/bootcnt.txt ] ; then
	touch /tmp/bootcnt.txt
	startlabwc
else
	pm13 cli
fi

### END ###
