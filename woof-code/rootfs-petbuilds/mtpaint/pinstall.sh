if [ ! -e usr/local/apps/ROX-Filer/AppRun ]; then
	chroot . xdg-mime default mtpaint.desktop image/bmp
	chroot . run-as-spot xdg-mime default mtpaint.desktop image/bmp
fi