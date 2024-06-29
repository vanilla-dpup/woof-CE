#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <string.h>
#include <unistd.h>
#include <sys/time.h>
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>

#define CHUNK_SIZE 512

int main(int argc, char *argv[])
{
	int src, dst;
	struct stat srcstat, dststat;
	struct timeval times[2];
	unsigned char *srcm, *dstm;
	off_t off = 0, chunk;

	if (argc != 3) {
		fprintf(stderr, "%s SRC DST\n", argv[0]);
		return EXIT_FAILURE;
	}

	if ((src = open(argv[1], O_RDONLY | O_NOATIME)) < 0) {
		fprintf(stderr, "Failed to open %s: %s\n", argv[1], strerror(errno));
		return EXIT_FAILURE;
	}

	if (fstat(src, &srcstat) < 0) {
		fprintf(stderr, "Failed to stat %s: %s\n", argv[1], strerror(errno));
		close(src);
		return EXIT_FAILURE;
	}

	if ((dst = open(argv[2], O_RDWR | O_CREAT | O_NOATIME, srcstat.st_mode & ~S_IFMT)) < 0) {
		fprintf(stderr, "Failed to open %s: %s\n", argv[2], strerror(errno));
		close(src);
		return EXIT_FAILURE;
	}

	if (fstat(dst, &dststat) < 0) {
		fprintf(stderr, "Failed to stat %s: %s\n", argv[2], strerror(errno));
		close(dst);
		close(src);
		return EXIT_FAILURE;
	}

	if (dststat.st_size == srcstat.st_size && dststat.st_mtime >= srcstat.st_mtime)
		goto meta;

	if (dststat.st_size != srcstat.st_size && ftruncate(dst, srcstat.st_size) < 0) {
		fprintf(stderr, "Failed to set %s size: %s\n", argv[2], strerror(errno));
		close(dst);
		close(src);
		return EXIT_FAILURE;
	}

	if (srcstat.st_size == 0)
		goto meta;

	if ((srcm = mmap(NULL, srcstat.st_size, PROT_READ, MAP_PRIVATE, src, 0)) == MAP_FAILED) {
		fprintf(stderr, "Failed to mmap %s: %s\n", argv[1], strerror(errno));
		close(dst);
		close(src);
		return EXIT_FAILURE;
	}

	if ((dstm = mmap(NULL, srcstat.st_size, PROT_READ | PROT_WRITE, MAP_SHARED, dst, 0)) == MAP_FAILED) {
		fprintf(stderr, "Failed to mmap %s: %s\n", argv[2], strerror(errno));
		munmap(srcm, srcstat.st_size);
		close(dst);
		close(src);
		return EXIT_FAILURE;
	}

	madvise(srcm, srcstat.st_size, MADV_SEQUENTIAL);
	madvise(dstm, srcstat.st_size, MADV_SEQUENTIAL);

	if (srcstat.st_size > 0 && dststat.st_size == 0)
		memcpy(dstm, srcm, srcstat.st_size);
	else {
		do {
			chunk = srcstat.st_size - off >= CHUNK_SIZE ? CHUNK_SIZE : srcstat.st_size - off;

			if (memcmp(&srcm[off], &dstm[off], chunk) != 0)
				memcpy(&dstm[off], &srcm[off], chunk);

			off += chunk;
		} while (off < srcstat.st_size);
	}

	munmap(srcm, srcstat.st_size);

	if (msync(dstm, srcstat.st_size, MS_SYNC) < 0) {
		fprintf(stderr, "Failed to flush changes to disk: %s\n", strerror(errno));
		munmap(dstm, srcstat.st_size);
		close(dst);
		close(src);
		return EXIT_FAILURE;
	}

	munmap(dstm, srcstat.st_size);

meta:
	close(src);

	if ((dststat.st_uid != srcstat.st_uid || dststat.st_gid != srcstat.st_gid) && fchown(dst, srcstat.st_uid, srcstat.st_gid) < 0)
		fprintf(stderr, "Failed to sync ownership: %s\n", strerror(errno));

	if (dststat.st_mode != srcstat.st_mode && fchmod(dst, srcstat.st_mode & ~S_IFMT) < 0)
		fprintf(stderr, "Failed to sync permissions: %s\n", strerror(errno));

	if (dststat.st_mtime != srcstat.st_mtime)
	{
		times[0].tv_sec = dststat.st_atime;
		times[1].tv_sec = srcstat.st_mtime;
		times[0].tv_usec = times[1].tv_usec = 0;
		if (futimes(dst, times) < 0)
			fprintf(stderr, "Failed to sync times: %s\n", strerror(errno));
	}

	close(dst);
	return EXIT_SUCCESS;
}
