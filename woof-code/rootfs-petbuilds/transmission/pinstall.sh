echo '#!/bin/sh
exec transmission-gtk "$@"' > usr/local/bin/defaulttorrent
chmod 755 usr/local/bin/defaulttorrent

chroot . /usr/sbin/setup-spot transmission-gtk=true
