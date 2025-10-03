#include <unistd.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <limits.h>
#include <sys/inotify.h>
#include <errno.h>
#include <string.h>
#include <signal.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>

static int
fixmenus(const sigset_t *set)
{
	pid_t pid, reaped;

	pid = fork();
	if (pid == 0) {
		if (sigprocmask(SIG_SETMASK, set, NULL) == 0)
			execlp("fixmenus", "fixmenus", (char *)NULL);

		exit(EXIT_FAILURE);
	}
	else if (pid > 0) {
		reaped = waitpid(pid, NULL, 0);
		if ((reaped == pid) || ((reaped < 0) && (errno == ECHILD)))
			return 0;

		return -1;
	}
	else
		return -1;
}

static int
handle_events(const int fd, const sigset_t *set)
{
	char buf[sizeof(struct inotify_event) + NAME_MAX + 1];
	const struct inotify_event *event;
	ssize_t out;
	size_t len;

	while (1) {
		out = read(fd, buf, sizeof(buf));
		if (out < 0) {
			if (errno == EAGAIN)
				break;

			return -1;
		}

		for (event = (const struct inotify_event *)buf;
		     (char *)event < (buf + out);
		     event = (const struct inotify_event *)((char *)event + sizeof(*event) + event->len)) {
			if (!(event->mask & (IN_DELETE | IN_CLOSE_WRITE | IN_MOVED_TO)))
				continue;

			len = strlen(event->name);
			if ((len <= (sizeof(".desktop") - 1)) ||
			    (strcmp(&event->name[len - (sizeof(".desktop") - 1)], ".desktop") != 0))
				continue;

			alarm(5);
		}
	}

	return 0;
}

int
main(int argc, char* argv[])
{
	static char path[PATH_MAX];
	const char *datadirs, *share;
	char *copy, *pos;
	sigset_t set, oset;
	int fd,  sig;

	if (argc != 1)
		return EXIT_FAILURE;

	if (!(datadirs = getenv("XDG_DATA_DIRS")) || !*datadirs || !(copy = strdup(datadirs)))
		return EXIT_FAILURE;

	if ((sigemptyset(&set) < 0) ||
	    (sigaddset(&set, SIGRTMIN) < 0) ||
	    (sigaddset(&set, SIGALRM) < 0) ||
	    (sigaddset(&set, SIGINT) < 0) ||
	    (sigaddset(&set, SIGTERM) < 0) ||
	    (sigaddset(&set, SIGHUP) < 0) ||
	    (sigaddset(&set, SIGCHLD) < 0) ||
	    (sigprocmask(SIG_BLOCK, &set, &oset) < 0)) {
		free(copy);
		return EXIT_FAILURE;
	}

	fd = inotify_init1(O_CLOEXEC);
	if (fd < 0) {
		free(copy);
		return EXIT_FAILURE;
	}

	share = strtok_r(copy, ":", &pos);
	while (share) {
		snprintf(path, sizeof(path), "%s/applications", share);
		path[sizeof(path) - 1] = '\0';
		inotify_add_watch(fd, path, IN_CLOSE_WRITE | IN_DELETE | IN_MOVED_TO | IN_EXCL_UNLINK);
		share = strtok_r(NULL, ":", &pos);
	}
	free(copy);

	if ((fcntl(fd, F_SETFL, O_NONBLOCK | O_ASYNC) < 0) ||
	    (fcntl(fd, F_SETSIG, SIGRTMIN) < 0) ||
	    (fcntl(fd, F_SETOWN, getpid()) < 0)) {
		close(fd);
		return EXIT_FAILURE;
	}

	while ((sigwait(&set, &sig) == 0) &&
	       (((sig == SIGRTMIN) &&
	         (handle_events(fd, &oset) == 0)) ||
	        ((sig == SIGALRM) &&
	         (fixmenus(&oset) == 0)) ||
	        (sig == SIGCHLD)));

	close(fd);
	return EXIT_FAILURE;
}