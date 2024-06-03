#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <string.h>
#include <errno.h>

#include <linux/fscrypt.h>

#include <argon2.h>

#define T_COST 15
#define M_COST 128*1024
#define THREADS 1
#define SALT "woofwoof"
#define KEY_SIZE 32

#define HIDE_KEY "\e[33m\e[43m"
#define RESET_TTY "\e[0m"

static int read_pwd(unsigned char key[KEY_SIZE])
{
    unsigned char buf[32];
    size_t len;

    for (len = 0; len < sizeof(buf); ++len) {
        if (read(STDIN_FILENO, &buf[len], sizeof(buf[len]) ) != 1)
            return 0;

        if (buf[len] == '\n')
            break;
    }

    if (argon2i_hash_raw(T_COST, M_COST, THREADS, buf, len, SALT, sizeof(SALT) - 1, key, KEY_SIZE) != ARGON2_OK)
        return 0;

    return 1;
}

static int add_key(const char *pwd, int fd, struct fscrypt_policy_v2 *policy)
{
    static unsigned char buf[sizeof(struct fscrypt_add_key_arg) + KEY_SIZE];
    struct fscrypt_add_key_arg *arg = (struct fscrypt_add_key_arg *)buf;
    int ok;

    *arg = (struct fscrypt_add_key_arg){
        .key_spec = {
            .type = FSCRYPT_KEY_SPEC_TYPE_IDENTIFIER,
        },
        .raw_size = KEY_SIZE
    };

    if (pwd && *pwd) {
        if (argon2i_hash_raw(T_COST, M_COST, THREADS, pwd, strlen(pwd), SALT, sizeof(SALT) - 1, &buf[sizeof(*arg)], KEY_SIZE) != ARGON2_OK)
            return EINVAL;

        goto add;
    }

    if (write(STDOUT_FILENO, "Password: ", sizeof("Password: ") - 1) != sizeof("Password: ") - 1)
        return EINTR;

    write(STDOUT_FILENO, HIDE_KEY, sizeof(HIDE_KEY) - 1);
    ok = read_pwd(&buf[sizeof(*arg)]);
    write(STDOUT_FILENO, RESET_TTY, sizeof(RESET_TTY) - 1);
    if (!ok)
        return EINTR;

add:
    if (ioctl(fd, FS_IOC_ADD_ENCRYPTION_KEY, buf) < 0)
        return errno;

    memcpy(policy->master_key_identifier,
           arg->key_spec.u.identifier,
           sizeof(policy->master_key_identifier));

    return 0;
}

static int set_policy(int root, const char *path, const struct fscrypt_policy_v2 *policy)
{
    int fd, err;

    fd = openat(root, path, O_RDONLY);
    if (fd < 0)
        return errno == ENOENT ? 0 : errno;

    if (ioctl(fd, FS_IOC_SET_ENCRYPTION_POLICY, policy) < 0) {
        err = errno;
        close(fd);
        return err;
    }

    close(fd);
    return 0;
}

int main(int argc, char *argv[])
{
    struct fscrypt_policy_v2 policy = {
        .version = FSCRYPT_POLICY_V2,
        .contents_encryption_mode = FSCRYPT_MODE_AES_256_XTS,
        .filenames_encryption_mode = FSCRYPT_MODE_AES_256_CTS,
        .flags = FSCRYPT_POLICY_FLAGS_PAD_32,
    };
    int root, i, res;

    if (argc < 4)
        return EXIT_FAILURE;

    root = open(argv[1], O_RDONLY);
    if (root < 0) {
        fprintf(stderr, "Failed to open %s: %s\n", argv[1], strerror(errno));
        return EXIT_FAILURE;
    }

    do {
wrong:
        res = add_key(argv[2], root, &policy);
        if (res != 0) {
            fprintf(stderr, "Failed to add key: %s\n", strerror(res));
            close(root);
            return EXIT_FAILURE;
        }

        for (i = 3; i < argc; ++i) {
            res = set_policy(root, argv[i], &policy);
            if (res == EEXIST) {
                fprintf(stderr, "Wrong password for %s\n", argv[i]);
                goto wrong;
            }

            if (res != 0) {
                fprintf(stderr, "Failed to unlock %s: %s\n", argv[i], strerror(res));
                close(root);
                return EXIT_FAILURE;
            }

            fprintf(stderr, "Unlocked %s\n", argv[i]);
        }
    } while (0);

    close(root);
    return EXIT_SUCCESS;
}
