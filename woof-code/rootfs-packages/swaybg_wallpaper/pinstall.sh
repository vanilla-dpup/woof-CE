BG="#04475C"
case "`grep -m1 ^Suites etc/apt/sources.list.d/debian.sources | awk '{print $2}'`" in
testing) BG="#613583" ;;
unstable|sid|ceres) BG="#a51d2d" ;;
esac

mkdir -p etc/skel/.config/autostart
cat << EOF > etc/skel/.config/autostart/swaybg.desktop
[Desktop Entry]
Version=1.0
Name=swaybg
Comment=swaybg
Exec=swaybg -c "$BG"
Terminal=false
Type=Application
EOF
chmod 644 etc/skel/.config/autostart/swaybg.desktop
