#!/bin/sh

BATDIR=$(find -L /sys/class/power_supply -maxdepth 1 -type d -name 'BAT*')
[ -z "$BATDIR" ] && echo 'no battery' && exit # no battery

case $1 in
  s)
	yad --title=powerapplet.sh --window-icon=dialog-information --button=gtk-ok \
	--text="$(cd $BATDIR ; for i in * ; do [ "$i" = 'uevent' ] && continue; [ -d "$i" ] && continue; echo -n "${i}: " && cat $i ; done)" &
  ;;
  *)
    FULL=$(find -L $BATDIR -maxdepth 1 -type f -name '*_full')
    NOW=$(find -L $BATDIR -maxdepth 1 -type f -name '*_now' |grep -E 'charge|energy')
    STATE=$(find -L $BATDIR -maxdepth 1 -type f -name 'status')

    echo "scanner {
  file(\"$FULL\") { BatTotal = Grab(First) }
  file(\"$NOW\") { BatLeft = Grab(First) }
  file(\"$STATE\") { BatState = RegEx(\"^(.*)$\",First) }
}"
;;
esac
