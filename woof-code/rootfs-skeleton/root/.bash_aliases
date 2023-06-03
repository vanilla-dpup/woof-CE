if [ ! -e /usr/bin/sudo ]; then
	sudo() {
		if [ -e /usr/bin/sudo ]; then
			/usr/bin/sudo "$@"
		else
			"$@"
		fi
	}
fi