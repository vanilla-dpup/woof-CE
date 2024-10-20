#include <vmlinux.h>

#include <bpf/bpf_core_read.h>

#define STA_UNSYNC 0x0040

char LICENSE[] SEC("license") = "GPL";

SEC("tracepoint/syscalls/sys_enter_clock_adjtime")
int override_clock_adjtime(struct trace_event_raw_sys_enter *ctx)
{
	struct __kernel_timex ktx;

	if (bpf_probe_read_user(&ktx, sizeof(ktx), (void *)ctx->args[1]) < 0) {
		return 0;
	}

	ktx.status |= STA_UNSYNC;
	bpf_probe_write_user((void *)ctx->args[1], &ktx, sizeof(ktx));

	return 0;
}
