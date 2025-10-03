rtclock prevents connman from changing the hardware clock using eBPF, to prevent conflicts with other OSs running on the same machine that may save time in UTC rather than local time.

When connman's clock_adjtime() calls get intercepted by rtclock, clock synchronization over NTP only sets the software clock. /etc/rc.d/rc.sysinit is responsible for synchronizing the software clock with RTC at boot time, so if RTC is set correctly (by another OS), the software clock will show the correct time even before network is ready.
