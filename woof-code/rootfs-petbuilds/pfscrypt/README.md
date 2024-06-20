pfscrypt uses [fscrypt](https://docs.kernel.org/filesystems/fscrypt.html) to "lock" empty directories or "unlock" previously "locked" directories. It's a tiny C alternative to the [big fscrypt userspace tool](https://github.com/google/fscrypt).

The master encryption key is derived from the passphrase provided by the user using [Argon2](https://github.com/P-H-C/phc-winner-argon2), with hardcoded parameters.
