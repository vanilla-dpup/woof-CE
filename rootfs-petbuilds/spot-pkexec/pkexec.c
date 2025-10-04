#include <sys/types.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <errno.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>

static
int sendall(const int s, const char *buf, const size_t len)
{
	size_t total;
	ssize_t sent;

	for (total = 0; total < len; total += (size_t)sent) {
		sent = send(s, buf + total, len - total, MSG_NOSIGNAL);
		if (sent <= 0)
			return -1;
	}

	return 0;
}

int main(int argc, char *argv[])
{
	struct sockaddr_un sun = {.sun_family = AF_UNIX, .sun_path = "/run/pkexecd.socket"};
	size_t len;
	int s, i = 1;

	if (argc == 1 || argc > 30)
		return EXIT_FAILURE;

	do {
		if (strcmp(argv[i], "--version") == 0) {
			write(STDOUT_FILENO, "pkexec version 125\n", sizeof("pkexec version 125\n") - 1);
			return EXIT_SUCCESS;
		}

		if ((strcmp(argv[i], "--user") == 0 || strcmp(argv[i], "-u") == 0) && i < argc -1)
			i += 2;
		else if (strncmp(argv[i], "--", 2) == 0)
			++i;
		else
			break;
	} while (i < argc);

	if (i == argc)
		return EXIT_FAILURE;

	argv = &argv[i];
	argc -= i;

	if (getuid() == 0 && getgid() == 0) {
		execvp(argv[0], argv);
		return EXIT_FAILURE;
	}

	if ((s = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0)) < 0) return EXIT_FAILURE;

	if (connect(s, (const struct sockaddr *)&sun, sizeof(sun))) {
		close(s);
		return EXIT_FAILURE;
	}

	for (i = 0; environ[i]; ++i) {
		len = strlen(environ[i]);
		if ((len > 0 && sendall(s, environ[i], len) < 0) || sendall(s, "\0", 1) < 0) {
			close(s);
			return EXIT_FAILURE;
		}
	}

	for (i = 0; i < argc; ++i) {
		len = strlen(argv[i]);
		if ((len > 0 && sendall(s, argv[i], len) < 0) || sendall(s, "\0", 1) < 0) {
			close(s);
			return EXIT_FAILURE;
		}
	}

	if (sendall(s, "\0", 1) < 0) {
		close(s);
		return EXIT_FAILURE;
	}

	recv(s, &i, 1, 0);

	close(s);
	return EXIT_SUCCESS;
}
