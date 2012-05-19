#include	"ringbuffer.hpp"

#include	<stdlib.h>
#include	<string.h>
#include	<cstdio>

Ringbuffer::Ringbuffer(unsigned int size) {
	data   = (char *) malloc(size);
	length = size;
	head   = 0;
	tail   = 0;
	nl     = 0;
}

Ringbuffer::~Ringbuffer() {
	free(data);
}

unsigned int Ringbuffer::numlines() {
	return nl;
}

unsigned int Ringbuffer::scannl() {
	nl = 0;
	for (unsigned int i = tail; i != head; i++) {
		if (i >= length)
			i -= length;
		if (data[i] == 10)
			nl++;
	}
	return nl;
}

unsigned int Ringbuffer::canread() {
	return (head - tail) % length;
}

unsigned int Ringbuffer::canwrite() {
	return (tail - head + (length - 1)) % length;
}

unsigned int Ringbuffer::read(char *buf, unsigned int len) {
	if (len > canread())
		len = canread();

	unsigned int stage1 = length - tail;
	unsigned int stage2 = 0;

	if (stage1 > len)
		stage1 = len;
	if (stage1 < len) {
		stage2 = len - stage1;
		stage1 = len;
	}

	memcpy(buf, &data[tail], stage1);

	tail += stage1;
	if (tail >= length) tail -= length;

	if (stage2) {
		memcpy(&buf[stage1], &data[tail], stage2);
		tail += stage2;
		if (tail >= length) tail -= length;
	}

	scannl();

	return len;
}

unsigned int Ringbuffer::readtofd(FILE * fd, unsigned int len) {
	if (len > canread())
		len = canread();

	unsigned int stage1 = length - tail;
	if (stage1 > len)
		stage1 = len;

	stage1 = fwrite(&data[tail], 1, stage1, fd);

	tail += stage1;
	if (stage1 >= length) stage1 -= length;

	scannl();

	return stage1;
}

unsigned int Ringbuffer::peekline(char *buf, unsigned int len) {
	if (nl == 0)
		return 0;

	len--; // make room for trailing 0

	if (len > canread())
		len = canread();

	unsigned int t = tail;
	for (unsigned int i = 0; i < len; i++) {
		buf[i] = data[t];
		t = (t + 1) % length;
		if (buf[i] == 10) {
			buf[++i] = 0;
			return i;
		}
	}
	return 0;
}

unsigned int Ringbuffer::readline(char *buf, unsigned int len) {
	unsigned int r = peekline(buf, len);
	if (r > 0) {
		tail = (tail + r) % length;
		nl--;
	}
	return r;
}

unsigned int Ringbuffer::write(char *buf, unsigned int len) {
	if (len > canwrite())
		len = canwrite();

	unsigned int stage1 = length - head;
	unsigned int stage2 = 0;

	if (stage1 > len)
		stage1 = len;
	if (stage1 < len) {
		stage2 = len - stage1;
	}

	memcpy(&data[head], buf, stage1);

	head += stage1;
	if (head >= length) head -= length;

	if (stage2 > 0) {
		memcpy(&data[head], &buf[stage1], stage2);

		head += stage2;
		if (head >= length) head -= length;
	}

	scannl();

	return len;
}

unsigned int Ringbuffer::writefromfd(FILE *fd, unsigned int len) {
	if (len > canwrite())
		len = canwrite();

	unsigned int stage1 = length - head;

	if (stage1 > len)
		stage1 = len;

	stage1 = fread(&data[head], 1, stage1, fd);

	head += stage1;
	if (head >= length) head -= length;

	scannl();

	return stage1;
}
