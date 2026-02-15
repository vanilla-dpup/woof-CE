#include <syscall.h>
#include <sys/types.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <errno.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdlib.h>
#include <pwd.h>
#include <grp.h>
#include <fcntl.h>
#include <sys/wait.h>

#define REQUEST_MAX (2*1024*1024)

#define ALLOW(X) {#X"=", sizeof(#X"=") - 1}
static const struct {
	const char *pfix;
	size_t len;
} allowed[] = {
	ALLOW(LC_ALL),
	ALLOW(LANG),
	ALLOW(WAYLAND_DISPLAY),
	ALLOW(XDG_RUNTIME_DIR),
};

static inline
int pidfd_open(pid_t pid, unsigned int flags)
{
	return syscall(__NR_pidfd_open, pid, flags);
}

static inline
int pidfd_getfd(int pidfd, int targetfd, unsigned int flags)
{
	return syscall(__NR_pidfd_getfd, pidfd, targetfd, flags);
}

static
int borrow_pipes(const pid_t pid)
{
	int fd, i, pid_fd;

	if ((pid_fd = pidfd_open(pid, 0)) < 0) return -1;

	for (i = STDIN_FILENO; i <= STDERR_FILENO; ++i) {
		if ((fd = pidfd_getfd(pid_fd, i, 0)) < 0) {
			if (errno != ESRCH) {
				close(pid_fd);
				return -1;
			}
			continue;
		}
		if (dup2(fd, i) != i) {
			close(fd);
			close(pid_fd);
			return -1;
		}
		close(fd);
	}

	close(pid_fd);
	return 0;
}

static
void exec_child(const struct ucred *cred, char *argv[], char *envp[])
{
	int i;

	for (i = 0; envp[i]; ++i) {
		if (putenv(envp[i]) < 0) return;
	}

	if (setenv("USER", "root", 1) < 0 ||
	    setenv("HOME", "/root", 1) < 0 ||
	    setenv("XDG_DATA_HOME", "/root/.local/share", 1) < 0 ||
	    setenv("XDG_CONFIG_HOME", "/root/.config", 1) < 0 ||
	    setenv("XDG_DATA_DIRS", "/usr/share:/usr/local/share", 1) < 0 ||
	    setenv("XDG_CACHE_HOME", "/root/.cache", 1) < 0 ||
	    setenv("XDG_STATE_HOME", "/root/.local/state", 1) < 0)
		return;

	execvp(argv[0], argv);
}

void run_cmd(const struct ucred *cred, char *buf, const size_t len)
{
	static char *envp[128], *safe_envp[(sizeof(allowed) / sizeof(allowed[0])) + 1], *argv[32] = {"/usr/local/sbin/pkexec-ask"};
	struct passwd *user;
	pid_t ask, reaped;
	int envc, safe_envc = 0, argc, status, i, j;

	if (!(user = getpwuid(cred->uid))) return;

	for (envc = 1; envp[0] = buf, envc < 127; ++envc) {
		if (!(envp[envc] = memchr(envp[envc - 1], '\0', len - (envp[envc] - buf)))) break;
		if (envp[envc] >= &buf[len - 2]) return;
		++(envp[envc]);
		if (!strrchr(envp[envc], '=')) break;
	}

	if (envc == 0) return;

	for (argc = 2, argv[1] = envp[envc]; argc < 31; ++argc) {
		if (!(argv[argc] = memchr(argv[argc - 1], '\0', len - (argv[argc] - buf)))) break;
		if (argv[argc] < &buf[len - 2]) ++(argv[argc]);
		else {
			envp[envc] = NULL;
			argv[argc] = NULL;

			if (borrow_pipes(cred->pid) < 0) return;

			if ((ask = fork()) == 0) {
				if (initgroups(user->pw_name, user->pw_gid) < 0 || setgid(user->pw_gid) < 0 || setuid(user->pw_uid) < 0) exit(EXIT_FAILURE);

				for (i = 0; i < envc; ++i) {
					for (j = 0; j < sizeof(allowed) / sizeof(allowed[0]) && safe_envc < (sizeof(safe_envp) / sizeof(safe_envp[0])) - 1; ++j) {
						if (strncmp(envp[i], allowed[j].pfix, allowed[j].len) == 0) {
							safe_envp[safe_envc++] = envp[i];
							break;
						}
					}
				}

				execve(argv[0], argv, safe_envp);
				exit(EXIT_FAILURE);
			} else if (ask > 0) {
				while ((reaped = waitpid(ask, &status, 0)) != ask) {
					if (reaped < 0) {
						if (errno == EINTR) continue;
						return;
					}
				}
				if (!WIFEXITED(status) || (WEXITSTATUS(status) != EXIT_SUCCESS))
					return;

				exec_child(cred, &argv[1], envp);
			}

			break;
		}
	}
}

static
void handle(sigset_t *set, const struct ucred *cred, const int fd, char *buf, const size_t len)
{
	ssize_t chunk, total;

	if (sigprocmask(SIG_SETMASK, set, NULL) < 0) return;

	for (total = 0; total < len;) {
		if ((chunk = recv(fd, &buf[total], len - total, 0)) < 0) {
			if (errno == EINTR) continue;
			break;
		}
		else if (chunk == 0) break;
		total += (size_t)chunk;
		if (total > 2 && buf[total - 2] == '\0' && buf[total - 1] == '\0') {
			run_cmd(cred, buf, total);
			break;
		}
	}
}

int main(int argc, char *argv[])
{
	sigset_t set, old;
	siginfo_t sig;
	struct sockaddr_un sun = {.sun_family = AF_UNIX, .sun_path = "/run/pkexecd.socket"};
	struct ucred cred;
	char *buf;
	pid_t pid;
	int s, c;
	socklen_t len = sizeof(cred);

	if (sigemptyset(&set) < 0 || sigaddset(&set, SIGIO) < 0 || sigaddset(&set, SIGCHLD) < 0 || sigaddset(&set, SIGTERM) < 0 || sigprocmask(SIG_SETMASK, &set, &old) < 0) return EXIT_FAILURE;

	if (!(buf = malloc(REQUEST_MAX))) return EXIT_FAILURE;

	if ((s = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0)) < 0) return EXIT_FAILURE;
	if (bind(s, (const struct sockaddr *)&sun, sizeof(sun)) < 0) {
		if (errno != EADDRINUSE || (unlink(sun.sun_path) < 0 && errno != ENOENT) || bind(s, (const struct sockaddr *)&sun, sizeof(sun)) < 0) {
			close(s);
			free(buf);
			return EXIT_FAILURE;
		}
	}
	if (chmod(sun.sun_path, 0766) < 0 || listen(s, 5) < 0 || daemon(1, 0) < 0 || chdir("/tmp") < 0 || fcntl(s, F_SETFL, O_RDWR | O_ASYNC) < 0 || fcntl(s, F_SETOWN, getpid()) < 0) {
		close(s);
		unlink(sun.sun_path);
		free(buf);
		return EXIT_FAILURE;
	}

	while (sigwaitinfo(&set, &sig) > 0) {
		if (sig.si_signo == SIGCHLD) {
			waitpid(sig.si_pid, NULL, WNOHANG);
			continue;
		}

		if (sig.si_signo != SIGIO) break;

		if ((c = accept4(s, NULL, NULL, 0)) < 0) continue;

		if (getsockopt(c, SOL_SOCKET, SO_PEERCRED, &cred, &len) < 0 || len != sizeof(cred) || ((pid = fork()) > 0)) {
			close(c);
			continue;
		}

		handle(&old, &cred, c, buf, REQUEST_MAX);
		close(c);
		return EXIT_SUCCESS;
	}

	close(s);
	unlink(sun.sun_path);
	free(buf);
	return EXIT_FAILURE;
}
