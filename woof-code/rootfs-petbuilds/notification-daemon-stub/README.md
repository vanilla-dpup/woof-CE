This is a stub implementation of the [desktop notifications specification](https://specifications.freedesktop.org/notification-spec/notification-spec-latest.html) that has no capabilities and silently disobeys requests to show notifications.

It's lighter than an a real notification daemon and allows applications with a soft dependency on a notification daemon to run without pulling a big dependency and adding a long-running process that consumes CPU and RAM.
