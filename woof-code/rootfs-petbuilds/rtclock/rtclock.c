#include <signal.h>
#include <stdlib.h>
#include <bpf/libbpf.h>
#include <unistd.h>

#include "rtclock.skel.h"

int main(int argc, char *argv[])
{
	sigset_t set;
	struct rtclock_bpf *skel;
	int sig;

	if (sigemptyset(&set) < 0 || sigaddset(&set, SIGTERM) < 0 || sigaddset(&set, SIGINT) < 0 || sigprocmask(SIG_BLOCK, &set, NULL) < 0) return EXIT_FAILURE;

	libbpf_set_strict_mode(LIBBPF_STRICT_ALL);
	libbpf_set_print(NULL);

	if (!(skel = rtclock_bpf__open_and_load())) return EXIT_FAILURE;

	if (rtclock_bpf__attach(skel)) {
		rtclock_bpf__destroy(skel);
		return EXIT_FAILURE;
	}

	daemon(0, 0);
	sigwait(&set, &sig);

	rtclock_bpf__destroy(skel);
	return EXIT_FAILURE;
}
