This is a minimal replacement for the Puppy combination of busybox init, plogin, getty and autologin.

It runs /etc/rc.d/rc.sysinit and repeatedly runs a root login shell on /dev/console with extra environment variables defined in /etc/environment.
