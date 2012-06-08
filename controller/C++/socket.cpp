#include "socket.hpp"

namespace C {
	#include <unistd.h>
	#include <sys/types.h>
	#include <sys/stat.h>
	#include <fcntl.h>
	extern "C" ssize_t read(int fd, void *buf, size_t count);
	extern "C" ssize_t write(int fd, const void *buf, size_t count);
	extern "C" int close(int fd);
}

#include <cstring>
#include <cstdarg>

Socket::Socket() {
	txbuf = new Ringbuffer(1024);
	rxbuf = new Ringbuffer(128);
	_fd = -1;
	memcpy(&description, "closed", 7);
// 	printf("socket %p: txbuf is at %p and rxbuf is at %p\n", this, txbuf, rxbuf);
}

Socket::Socket(int fd) {
	Socket();
	open(fd);
}

Socket::~Socket() {
	printf("Socket %s destroyed\n", description);
	if (_fd != -1)
		C::close(_fd);
}

int Socket::open(int fd) {
	Socket::_fd = fd;
	gettimeofday(&opentime, NULL);
// 	selector.add(fd, (FdCallback) &Socket::onread, (FdCallback) &Socket::onwrite, (FdCallback) &Socket::onerror, (void *) this, NULL);
	selector.add(fd, this);
// 	snprintf(description, sizeof(description), "fd:%d", fd);
	return 1;
}

int Socket::opened() {
	return _fd;
}

void Socket::close() {
	if (_fd != -1) {
		C::close(_fd);
		selector.remove(_fd);
	}
	_fd = -1;
	memcpy(description, "closed", 7);
}

int Socket::canread() {
	// TODO: check underlying socket for data
	return rxbuf->numlines();
}

int Socket::canwrite() {
	// TODO: check underlying socket for buffer space
	return txbuf->canwrite();
}

int Socket::fd() {
	return _fd;
}

void Socket::onread(struct SelectFd *selected) {
// 	printf("trying to read %d bytes\n", rxbuf->canwrite());
	int r = rxbuf->writefromfd(selected->fd, rxbuf->canwrite());
	if (rxbuf->canwrite() == 0) {
		selector[_fd]->poll &= ~POLL_READ;
// 		printf("disabled onread until rxbuf clears a bit\n");
	}
	if (r > 0) {
// 		printf("read %d bytes\n", r);
	}
	else if (r == 0) {
		printf("Connection from %s (%d) closed\n", toString(), _fd);
		close();
		selected->poll = 0;
	}
	else {
		perror("read");
	}
}

void Socket::onwrite(struct SelectFd *selected) {
	if (txbuf->numlines()) {
		txbuf->readtofd(_fd, txbuf->canread());
	}
	if (txbuf->canread() == 0) {
		selector[_fd]->poll &= ~POLL_WRITE;
	}
}

void Socket::onerror(struct SelectFd *selected) {
	printf("Error on %s (%d)\n", toString(), _fd);
	close();
	selected->poll = 0;
}

const char *Socket::toString() {
	return description;
}

int Socket::write(std::string str) {
	return write(str.c_str(), str.length());
}

int Socket::write(const char *str, int len) {
	int r = txbuf->write(str, len);
	selector[_fd]->poll |= POLL_WRITE;
	return r;
}

int Socket::printf(const char *format, ...) {
	int r = 256, s = 0;
	char *buf = NULL;
	va_list ap;
	do {
		if (buf) free(buf);
		if (r >= s) s = r + 1;
		buf = (char *) malloc(s);
		va_start(ap, format);
		r = vsnprintf(buf, s, format, ap);
		va_end(ap);
	} while (r >= s);
	write(buf, r);
	free(buf);
	return r;
}
