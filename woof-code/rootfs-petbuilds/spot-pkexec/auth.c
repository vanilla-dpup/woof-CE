#include <unistd.h>
#include <sys/types.h>
#include <pwd.h>
#include <stdlib.h>
#include <shadow.h>
#include <string.h>
#include <strings.h>
#include <sys/mman.h>

#define HIDE_INPUT "\e[33m\e[43m"
#define RESET_TTY "\e[0m\e[K"

static char *hash_pwd(const char *salt)
{
    long page;
    char *buf;
    char *hash;
    size_t len;

    if ((page = sysconf(_SC_PAGESIZE)) <= 1 || (buf = mmap(NULL, page, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)) == MAP_FAILED) return NULL;

    if (mlock(buf, page) < 0) {
        munmap(buf, page);
        return NULL;
    }

    for (len = 0; len < page; ++len) {
        if (read(STDIN_FILENO, &buf[len], sizeof(buf[len])) != 1) {
            explicit_bzero(buf, len);
            munmap(buf, page);
            return NULL;
        }

        if (buf[len] == '\n')
            break;
    }

    buf[len] = '\0';
    hash = crypt(buf, salt);
    explicit_bzero(buf, len);
    munmap(buf, page);
    return hash;
}

int main(int argc, char *argv[])
{
    const char *hash;
    struct passwd *user;
    struct spwd *pass;

    if (!isatty(STDIN_FILENO) || !isatty(STDOUT_FILENO) || !(user = getpwuid(getuid())) || !(pass = getspnam(user->pw_name)) || write(STDOUT_FILENO, "Password: ", 10) != 10) return EXIT_FAILURE;

    write(STDOUT_FILENO, HIDE_INPUT, sizeof(HIDE_INPUT) - 1);
    hash = hash_pwd(pass->sp_pwdp);
    write(STDOUT_FILENO, RESET_TTY, sizeof(RESET_TTY) - 1);

    return (hash && strcmp(pass->sp_pwdp, hash) == 0) ? EXIT_SUCCESS : EXIT_FAILURE;
}
