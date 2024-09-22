#include <fcntl.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <linux/ioprio.h>
#include <syslog.h>

static int oom_score_adj(void)
{
	int adj;

	if ((adj = open("/proc/self/oom_score_adj", O_WRONLY)) < 0) return -1;
	if (write(adj, "1000", sizeof("1000") - 1) != sizeof("1000") - 1) { close(adj); return -1; }
	close(adj);
	return 0;
}

int main(int argc, char *argv[])
{
	char ok;
	sigset_t mask;
	off_t size;
	void *p;
	long minsize;
	pid_t pid;
	int fd, comm[2], sig;

	if (argc != 2 || sigemptyset(&mask) < 0 || sigaddset(&mask, SIGTERM) < 0 || sigprocmask(SIG_SETMASK, &mask, NULL) < 0) return EXIT_FAILURE;

	if (syscall(__NR_ioprio_set, IOPRIO_WHO_PROCESS, 0, IOPRIO_PRIO_VALUE(IOPRIO_CLASS_IDLE, 7)) < 0 || oom_score_adj() < 0) return EXIT_FAILURE;

	if (pipe(comm) < 0) return EXIT_FAILURE;
	if ((fd = open(argv[1], O_RDONLY)) < 0) return EXIT_FAILURE;
	if ((minsize = sysconf(_SC_PAGESIZE)) <= 0 || (size = lseek(fd, 0, SEEK_END)) == (off_t)-1 || size < minsize) return EXIT_FAILURE;

	openlog("sfslock", LOG_CONS | LOG_PID, LOG_USER);
	syslog(LOG_INFO, "locking %s", argv[1]);

	if ((pid = fork()) < 0) return EXIT_FAILURE;
	else if (pid == 0) {
		close(comm[0]);
		if (mlockall(MCL_FUTURE) < 0 || (p = mmap(NULL, (size_t)size, PROT_READ, MAP_PRIVATE | MAP_POPULATE, fd, 0)) == MAP_FAILED) {
			closelog();
			return EXIT_FAILURE;
		}
		write(comm[1], "0", 1);
		close(comm[1]);
		while (!(sigwait(&mask, &sig) < 0 || sig == SIGTERM));
		syslog(LOG_INFO, "unlocking %s", argv[1]);
		munlockall();
		posix_fadvise(fd, 0, 0, POSIX_FADV_DONTNEED);
	}
	else {
		close(comm[1]);
		if (read(comm[0], &ok, 1) == 1) {
			syslog(LOG_INFO, "locked %s", argv[1]);
			closelog();
			return EXIT_SUCCESS;
		}
		syslog(LOG_NOTICE, "failed to lock %s", argv[1]);
	}

	closelog();
	return EXIT_FAILURE;
}
