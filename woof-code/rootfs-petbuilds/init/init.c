#include <sys/un.h>
#include <sys/types.h>
#include <unistd.h>
#include <pwd.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <time.h>
#include <signal.h>
#include <sys/wait.h>
#include <sys/reboot.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>

#define CLEAR_TTY "\033[2J\033[H"
#define RESPAWN_DELAY 1

static inline void do_autoclose(void *fdp)
{
	if (*(int *)fdp != -1) close(*(int *)fdp);
}

#define autoclose __attribute__((cleanup(do_autoclose)))

static void cat(const char *path)
{
	static char buf[512];
	size_t len;
	autoclose int fd = -1;

	if ((fd = open(path, O_RDONLY)) < 0) return;
	while ((len = read(fd, buf, sizeof(buf))) > 0 && write(STDOUT_FILENO, buf, len) == len);
}

static void fakelogin(void)
{
	static char buf[512];
	FILE *fp;
	struct passwd *user;
	char *sep, *end;

	if (!(user = getpwuid(geteuid()))) return;

	clearenv();

	if ((setenv("USER", user->pw_name, 1) < 0) ||
	    (setenv("HOME", user->pw_dir, 1) < 0) ||
	    (setenv("SHELL", user->pw_shell, 1) < 0) ||
	    (setenv("PATH", "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", 1) < 0) ||
	    (setenv("TERM", "linux", 1) < 0) ||
	    (setenv("XDG_DATA_HOME", "/root/.local/share", 1) < 0) ||
	    (setenv("XDG_CONFIG_HOME", "/root/.config", 1) < 0) ||
	    (setenv("XDG_DATA_DIRS", "/usr/share:/usr/local/share", 1) < 0) ||
	    (setenv("XDG_CONFIG_DIRS", "/etc/xdg", 1) < 0) ||
	    (setenv("XDG_CACHE_HOME", "/root/.cache", 1) < 0) ||
	    (setenv("XDG_RUNTIME_DIR", "/tmp/runtime-root", 1) < 0) ||
	    (setenv("XDG_STATE_HOME", "/root/.local/state", 1) < 0) ||
	    ((mkdir("/tmp/runtime-root", 0700) < 0 && errno != EEXIST) || (errno == EEXIST && chmod("/tmp/runtime-root", 0700) < 0)) ||
	    (chdir(user->pw_dir) < 0))
		return;

	if ((fp = fopen("/etc/environment", "r"))) {
		while (fgets(buf, sizeof(buf), fp)) {
			if (buf[0] == '\0' || buf[0] == '\n' || buf[0] == '#') continue;
			if (!(sep = strchr(buf, '='))) continue;
			end = sep + strcspn(sep, " \t\r\n");
			*sep = *end = '\0';
			if (setenv(buf, sep + 1, 1) < 0) continue;
		}
		fclose(fp);
	}

	cat("/etc/motd");

	execlp(user->pw_shell, user->pw_shell, "-l", (char *)NULL);
}

static void do_cttyhack(const int first)
{
	autoclose int fd = -1;

	if (setsid() < 0) return;

	fd = open("/dev/console", O_RDWR);
	if ((fd < 0) ||
	    (ioctl(fd, TIOCSCTTY, NULL) < 0) ||
	    (dup2(fd, STDIN_FILENO) < 0) ||
	    (dup2(fd, STDOUT_FILENO) < 0) ||
	    (dup2(fd, STDERR_FILENO) < 0))
		return;

	close(fd);
	fd = -1;

	if (first) cat("/etc/issue");
	fakelogin();
}

static void delay(const time_t sec)
{
	struct timespec req = {.tv_sec = sec}, rem;

	while (nanosleep(&req, &rem) < 0 && errno == EINTR) memcpy(&req, &rem, sizeof(struct timespec));
}

static pid_t cttyhack(const int first)
{
	pid_t pid;
	sigset_t mask;

	if ((pid = fork()) == 0) {
		if ((sigfillset(&mask) < 0) ||
		    (sigprocmask(SIG_UNBLOCK, &mask, NULL) < 0))
			exit(EXIT_FAILURE);

		if (!first)
			delay(RESPAWN_DELAY);

		do_cttyhack(first);
		exit(EXIT_FAILURE);
	}

	return pid;
}

static int script(const char *path)
{
	pid_t pid;
	sigset_t mask;
	int status;

	if ((pid = fork()) == 0) {
		if ((sigfillset(&mask) < 0) ||
		    (sigprocmask(SIG_UNBLOCK, &mask, NULL) < 0))
			exit(EXIT_FAILURE);

		close(STDIN_FILENO);
		close(STDOUT_FILENO);
		close(STDERR_FILENO);

		execl(path, path, (char *)NULL);
		exit(EXIT_FAILURE);
	}
	else if ((pid < 0) ||
		 (waitpid(pid, &status, 0) != pid) ||
		 !WIFEXITED(status))
		return -1;

	return 0;
}

int main(int argc, char *argv[])
{
	sigset_t mask;
	pid_t pid, reaped;
	siginfo_t sig = {.si_signo = SIGUSR2};
	int status, ret;

	if (getpid() != 1) return EXIT_FAILURE;

	write(STDOUT_FILENO, CLEAR_TTY, sizeof(CLEAR_TTY) - 1);

	if ((sigemptyset(&mask) < 0) ||
	    (sigaddset(&mask, SIGCHLD) < 0) ||
	    (sigaddset(&mask, SIGTERM) < 0) ||
	    (sigaddset(&mask, SIGUSR2) < 0) ||
	    (sigprocmask(SIG_SETMASK, &mask, NULL) < 0))
		goto shutdown;

	if (script("/etc/rc.d/rc.sysinit") < 0) goto shutdown;

	write(STDOUT_FILENO, CLEAR_TTY, sizeof(CLEAR_TTY) - 1);

	if ((pid = cttyhack(1)) < 0) goto shutdown;

	while (1) {
		if (sigwaitinfo(&mask, &sig) < 0) {
			if (errno == EINTR) continue;
			break;
		}

		if (sig.si_signo != SIGCHLD) break;

		while ((reaped = waitpid(-1, &status, WNOHANG)) > 0) {
			if (!WIFEXITED(status) && !WIFSIGNALED(status)) continue;
			if (reaped == pid && (pid = cttyhack(0)) < 0) break;
		}
	}

shutdown:
	ret = kill(-1, SIGTERM);
	delay(1);
	if (ret == 0)
		kill(-1, SIGKILL);

	sync();

	if (vfork() == 0) reboot(sig.si_signo == SIGUSR2 ? RB_POWER_OFF : RB_AUTOBOOT);

	return EXIT_FAILURE;
}