chroot . xdg-mime default zzzfm.desktop inode/directory
chroot . run-as-spot xdg-mime default zzzfm.desktop inode/directory

mkdir -p etc/skel/Desktop

install -m 644 usr/local/share/applications/zzzfm.desktop etc/skel/Desktop/zzzfm.desktop
install -m 644 usr/share/applications/foot.desktop etc/skel/Desktop/foot.desktop 2>/dev/null
install -m 644 usr/share/applications/geany.desktop etc/skel/Desktop/geany.desktop 2>/dev/null
install -m 644 usr/share/applications/librewolf.desktop etc/skel/Desktop/librewolf.desktop 2>/dev/null
install -m 644 usr/share/applications/libreoffice-writer.desktop etc/skel/Desktop/libreoffice-writer.desktop 2>/dev/null
install -m 644 usr/share/applications/libreoffice-calc.desktop etc/skel/Desktop/libreoffice-calc.desktop 2>/dev/null
install -m 644 usr/local/share/applications/mtpaint.desktop etc/skel/Desktop/mtpaint.desktop 2>/dev/null
install -m 644 usr/share/applications/synaptic.desktop etc/skel/Desktop/synaptic.desktop 2>/dev/null
install -m 644 usr/local/share/applications/swaylock.desktop etc/skel/Desktop/swaylock.desktop 2>/dev/null

cat << EOF > etc/skel/Desktop/puppyhelp.desktop
[Desktop Entry]
Encoding=UTF-8
Name=Help
Icon=help-contents-symbolic
Exec=puppyhelp
Terminal=false
Type=Application
EOF
chmod 644 etc/skel/Desktop/puppyhelp.desktop

cat << EOF > etc/skel/Desktop/logout_gui.desktop
[Desktop Entry]
Encoding=UTF-8
Name=Leave
Icon=system-log-out-symbolic
Exec=logout_gui
Terminal=false
Type=Application
EOF
chmod 644 etc/skel/Desktop/logout_gui.desktop
