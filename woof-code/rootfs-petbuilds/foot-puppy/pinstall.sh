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
