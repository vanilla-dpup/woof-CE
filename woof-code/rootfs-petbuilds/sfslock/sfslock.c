#include <fcntl.h>
#include <unistd.h>
#include <signal.h>
#include <stdlib.h>
#include <sys/mman.h>

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

	if (oom_score_adj() < 0) return EXIT_FAILURE;

	if (pipe(comm) < 0) return EXIT_FAILURE;
	if ((fd = open(argv[1], O_RDONLY)) < 0) return EXIT_FAILURE;
	if ((minsize = sysconf(_SC_PAGESIZE)) <= 0 || (size = lseek(fd, 0, SEEK_END)) == (off_t)-1 || size < minsize) return EXIT_FAILURE;

	if ((pid = fork()) < 0) return EXIT_FAILURE;
	else if (pid == 0) {
		close(comm[0]);
		if (mlockall(MCL_FUTURE) < 0 || (p = mmap(NULL, (size_t)size, PROT_READ, MAP_PRIVATE | MAP_POPULATE, fd, 0)) == MAP_FAILED) return EXIT_FAILURE;
		write(comm[1], "0", 1);
		close(comm[1]);
		while (!(sigwait(&mask, &sig) < 0 || sig == SIGTERM));
	}
	else {
		close(comm[1]);
		if (read(comm[0], &ok, 1) == 1) return EXIT_SUCCESS;
	}

	return EXIT_FAILURE;
}
