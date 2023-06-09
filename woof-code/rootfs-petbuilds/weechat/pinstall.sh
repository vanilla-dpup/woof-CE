echo '#!/bin/ash
exec weechat-shell' > usr/local/bin/defaultchat
chmod 755 usr/local/bin/defaultchat

chroot . /usr/sbin/setup-spot weechat=true

chroot . run-as-spot weechat-headless -r "/server add libera irc.libera.chat/6697 -autoconnect -ssl;/set irc.server.libera.autojoin #puppylinux;/quit"
rm -f usr/bin/weechat-headless
