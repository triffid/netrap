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

Socket::Socket() {
	_fd = -1;
	memcpy(&description, "closed", 7);
}

Socket::~Socket() {
	printf("Socket %s destroyed\n", description);
	if (_fd != -1)
		C::close(_fd);
}

int Socket::open(int fd) {
	Socket::_fd = fd;
	gettimeofday(&opentime, NULL);
	selector.add(fd, (FdCallback) &Socket::onread, (FdCallback) &Socket::onwrite, (FdCallback) &Socket::onerror, (void *) this, NULL);
	snprintf(description, sizeof(description), "fd:%d", fd);
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
	return 1;
}

int Socket::canwrite() {
	// TODO: check underlying socket for buffer space
	return 1;
}

int Socket::fd() {
	return _fd;
}

void Socket::onread(struct SelectFd *selected) {
	char readbuf[1024];
// 	printf("canread(%d)\n", selected->fd);
	ssize_t r = C::read(selected->fd, readbuf, 1024);
	if (r > 0) {
		printf("read %ld bytes: ", r);
		C::write(0, readbuf, r);
		printf("\n");
	}
	else if (r == 0) {
		printf("Connection from %s closed\n", toString());
		close();
		selected->poll = 0;
	}
	else {
		perror("read");
	}
}

void Socket::onwrite(struct SelectFd *selected) {
}

void Socket::onerror(struct SelectFd *selected) {
}

const char *Socket::toString() {
	return description;
}
