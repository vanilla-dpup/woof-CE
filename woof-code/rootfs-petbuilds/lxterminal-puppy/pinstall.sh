echo '#!/bin/sh
exec lxterminal "$@"' > usr/local/bin/defaultterminal
chmod 755 usr/local/bin/defaultterminal

if [ -e usr/bin/urxvt ]; then
	rm -f usr/local/bin/lxterminal-urxvt
else
	ln -s lxterminal-urxvt usr/local/bin/urxvt
	ln -s lxterminal-urxvt usr/local/bin/rxvt
	ln -s lxterminal-urxvt usr/local/bin/xterm
fi
