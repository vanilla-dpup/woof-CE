echo '#!/bin/sh
exec footclient "$@"' > usr/local/bin/defaultterminal
chmod 755 usr/local/bin/defaultterminal

if [ -e usr/bin/urxvt ]; then
	rm -f usr/bin/foot-urxvt
else
	ln -s ../../bin/foot-urxvt usr/local/bin/urxvt
	ln -s ../../bin/foot-urxvt usr/local/bin/rxvt
	ln -s ../../bin/foot-urxvt usr/local/bin/xterm
fi

cat << EOF >> etc/xdg/foot/foot.ini

# Puppy customization
[main]
initial-window-size-chars = 80x24
font=monospace:size=10
[colors]
background = 1a1a1a
foreground = f8f8f8
regular0 = 000000
regular1 = aa0000
regular2 = 00aa00
regular3 = aa5500
regular4 = 0000aa
regular5 = aa00aa
regular6 = 00aaaa
regular7 = aaaaaa
bright0 = 555555
bright1 = ff5555
bright2 = 55ff55
bright3 = ffff55
bright4 = 5555ff
bright5 = ff55ff
bright6 = 55ffff
bright7 = ffffff
EOF
