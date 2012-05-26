#include "socket.hpp"

namespace C {
	#include <unistd.h>
	#include <sys/types.h>
	#include <sys/stat.h>
	#include <fcntl.h>
	int close(int fd);
}

Socket::Socket() {
	_fd = -1;
}

Socket::~Socket() {
	if (_fd != -1)
		C::close(_fd);
}

int Socket::open(int fd) {
	Socket::_fd = fd;
	gettimeofday(&opentime, NULL);
	return 1;
}

int Socket::opened() {
	return _fd;
}

void Socket::close() {
	if (_fd != -1)
		C::close(_fd);
	_fd = -1;
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
