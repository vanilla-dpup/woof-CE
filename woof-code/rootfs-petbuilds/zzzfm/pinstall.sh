chroot . xdg-mime default zzzfm.desktop inode/directory
chroot . run-as-spot xdg-mime default zzzfm.desktop inode/directory

mkdir -p etc/skel/Desktop

install -m 644 usr/local/share/applications/zzzfm.desktop etc/skel/Desktop/zzzfm.desktop
install -m 644 usr/share/applications/foot.desktop etc/skel/Desktop/foot.desktop 2>/dev/null
install -m 644 usr/share/applications/geany.desktop etc/skel/Desktop/geany.desktop 2>/dev/null
install -m 644 usr/share/applications/librewolf.desktop etc/skel/Desktop/librewolf.desktop 2>/dev/null
install -m 644 usr/share/applications/libreoffice-startcenter.desktop etc/skel/Desktop/libreoffice-startcenter.desktop 2>/dev/null
install -m 644 usr/share/applications/gimp.desktop etc/skel/Desktop/gimp.desktop 2>/dev/null
install -m 644 usr/share/applications/synaptic.desktop etc/skel/Desktop/synaptic.desktop 2>/dev/null
install -m 644 usr/local/share/applications/xpad.desktop etc/skel/Desktop/xpad.desktop 2>/dev/null

cat << EOF > etc/skel/Desktop/help.desktop
[Desktop Entry]
Encoding=UTF-8
Name=Help
Icon=/usr/share/pixmaps/puppy/help.svg
Exec=puppyhelp
Terminal=false
Type=Application
EOF
chmod 644 etc/skel/Desktop/help.desktop

cat << EOF > etc/skel/Desktop/leave.desktop
[Desktop Entry]
Encoding=UTF-8
Name=Leave
Icon=/usr/share/pixmaps/puppy/shutdown.svg
Exec=logout_gui
Terminal=false
Type=Application
EOF
chmod 644 etc/skel/Desktop/leave.desktop

cat << EOF > etc/skel/Desktop/install.desktop
[Desktop Entry]
Encoding=UTF-8
Name=Install
Icon=/usr/share/pixmaps/puppy/puppy_install.svg
Exec=bootflash
Terminal=false
Type=Application
EOF
chmod 644 etc/skel/Desktop/install.desktop

if [ -f usr/bin/swaylock ]; then
	cat << EOF > etc/skel/Desktop/lock.desktop
[Desktop Entry]
Encoding=UTF-8
Name=Lock
Icon=/usr/share/pixmaps/puppy/screen_lock.svg
Exec=swaylock
Terminal=false
Type=Application
EOF
	chmod 644 etc/skel/Desktop/lock.desktop
fi

if [ -f usr/bin/connman-gtk ]; then
	cat << EOF > etc/skel/Desktop/connect.desktop
[Desktop Entry]
Encoding=UTF-8
Name=Connect
Icon=/usr/share/pixmaps/puppy/network.svg
Exec=connman-gtk
Terminal=false
Type=Application
EOF
	chmod 644 etc/skel/Desktop/connect.desktop
fi
