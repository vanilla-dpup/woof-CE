#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <netdb.h>
#include <nss.h>
#include <errno.h>

#include <xxhash.h>

static char *aliases[] = {NULL};

static struct in_addr any = {.s_addr = INADDR_ANY};
static const struct in_addr *addr_list[] = {&any, NULL};

static struct in6_addr any6 = IN6ADDR_ANY_INIT;
static const struct in6_addr *addr_list6[] = {&any6, NULL};

static int hashcmp(const void *a, const void *b)
{
	XXH64_hash_t m, n;
	m = *(XXH64_hash_t *)a;
	n = *(XXH64_hash_t *)b;
	return m < n ? -1 : m > n ? 1 : 0;
}

enum nss_status _nss_adlist_gethostbyname2_r(const char *name,
                                             int af,
                                             struct hostent *ret,
                                             char *buf,
                                             size_t buflen,
                                             int *errnop,
                                             int *h_errnop)
{
	struct stat stbuf;
	XXH64_hash_t hash;
	void *p;
	int fd;

	if (af != AF_INET && af != AF_INET6) {
		*errnop = ENOENT;
		return NSS_STATUS_UNAVAIL;
	}

	if ((fd = open("/var/cache/pup_advert_blocker/adlist", O_RDONLY)) < 0) {
		*errnop = ENOENT;
		return NSS_STATUS_UNAVAIL;
	}

	if (fstat(fd, &stbuf) < 0) {
		close(fd);
		*errnop = ENOENT;
		return NSS_STATUS_UNAVAIL;
	}

	if (stbuf.st_size % sizeof(hash) > 0) {
		close(fd);
		*errnop = ENOENT;
		return NSS_STATUS_UNAVAIL;
	}

	if ((p = mmap(NULL, stbuf.st_size, PROT_READ, MAP_PRIVATE, fd, 0)) == MAP_FAILED) {
		close(fd);
		*errnop = ENOENT;
		return NSS_STATUS_UNAVAIL;
	}

	hash = XXH3_64bits(name, strlen(name));

	if (!bsearch(&hash, p, stbuf.st_size / sizeof(hash), sizeof(hash), hashcmp)) {
		munmap(p, stbuf.st_size);
		close(fd);
		return NSS_STATUS_NOTFOUND;
	}

	munmap(p, stbuf.st_size);
	close(fd);

	ret->h_name = "adlist";
	ret->h_aliases = aliases;
	ret->h_addrtype = af;
	if (af == AF_INET) {
		ret->h_length = sizeof(struct in_addr);
		ret->h_addr_list = (char **)addr_list;
	} else {
		ret->h_length = sizeof(struct in6_addr);
		ret->h_addr_list = (char **)addr_list6;
	}

	return NSS_STATUS_SUCCESS;
}
