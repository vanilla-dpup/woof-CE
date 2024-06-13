# XDG_CURRENT_DESKTOP has the same value as under labwc
cat << EOF >> etc/environment
XDG_CURRENT_DESKTOP=wlroots
EOF

cat << EOF >> etc/environment
DWL_BORDER_COLOR=#000000
DWL_FOCUS_COLOR=#FF00FF
DWL_URGENT_COLOR=#00FFFF
DWL_ROOT_COLOR=#221111
EOF

echo dwl > etc/windowmanager
