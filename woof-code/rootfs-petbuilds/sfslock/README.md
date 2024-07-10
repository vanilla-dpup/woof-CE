sfslock is a tool that maps a file to memory, populates all mapped pages and locks them to RAM. It's used by /etc/rc.d/rc.sysinit to cache loaded SFSs in RAM, speeding up access to files inside the SFSs if they reside on a slow flash drive.

sfslock voluntarily increases its OOM score, so it should be the first process to be killed when running low on RAM.

On memory pressure, sfsunlockd kills all running sfslock processes to free memory.
