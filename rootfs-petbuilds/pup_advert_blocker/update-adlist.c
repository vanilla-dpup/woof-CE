#include <fcntl.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include <xxhash.h>

static int hashcmp(const void *a, const void *b)
{
	XXH64_hash_t m, n;
	m = *(XXH64_hash_t *)a;
	n = *(XXH64_hash_t *)b;
	return m < n ? -1 : m > n ? 1 : 0;
}

int main(int argc, char *argv[])
{
	static char line[256];
	XXH64_hash_t *hashes = NULL, *more;
	size_t len = 0, cap = 0, chars, wrote = 0;
	ssize_t chunk;
	int fd;

	while (fgets(line, sizeof(line), stdin)) {
		if (len == cap) {
			if (cap == UINT64_MAX) {
				free(hashes);
				return EXIT_FAILURE;
			}
			cap += 1024;
			if (!(more = realloc(hashes, cap * sizeof(XXH64_hash_t)))) {
				free(hashes);
				return EXIT_FAILURE;
			}
			hashes = more;
		}
		if ((chars = strlen(line)) > 1)
			hashes[len++] = XXH3_64bits(line, chars - 1);
	}

	qsort(hashes, len, sizeof(XXH64_hash_t), hashcmp);

	if ((fd = open("/var/cache/pup_advert_blocker/adlist.new", O_WRONLY | O_CREAT | O_TRUNC, 0644)) < 0) {
		free(hashes);
		return EXIT_FAILURE;
	}

	while (wrote < len * sizeof(XXH64_hash_t)) {
		if ((chunk = write(fd, &((char *)hashes)[wrote], (len * sizeof(XXH64_hash_t)) - wrote)) <= 0) {
			close(fd);
			unlink("/var/cache/pup_advert_blocker/adlist.new");
			free(hashes);
			return EXIT_FAILURE;
		}
		wrote += chunk;
	}

	close(fd);
	free(hashes);

	if (rename("/var/cache/pup_advert_blocker/adlist.new", "/var/cache/pup_advert_blocker/adlist") < 0) {
		unlink("/var/cache/pup_advert_blocker/adlist.new");
		return EXIT_FAILURE;
	}

	return EXIT_SUCCESS;
}
