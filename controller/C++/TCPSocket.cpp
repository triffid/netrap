#include "TCPSocket.hpp"

TCPSocket::TCPSocket() {
}

TCPSocket::TCPSocket(int fd, struct sockaddr *addr) {
	memcpy(&myaddr, addr, socksize(addr));
	open(fd);
	sock2a(addr, description, sizeof(description));
}

TCPSocket::~TCPSocket() {
}

int TCPSocket::open(int fd) {
	Socket::_fd = fd;
	gettimeofday(&opentime, NULL);
// 	selector.add(fd, (FdCallback) &TCPSocket::onread, (FdCallback) &TCPSocket::onwrite, (FdCallback) &TCPSocket::onerror, (void *) this, NULL);
	selector.add(fd, this);
	snprintf(description, sizeof(description), "fd:%d", fd);
	return 1;
}

void TCPSocket::onread(struct SelectFd *selected) {
	Socket::onread(selected);
}

void TCPSocket::onwrite(struct SelectFd *selected) {
	Socket::onwrite(selected);
}

void TCPSocket::onerror(struct SelectFd *selected) {
	Socket::onerror(selected);
}
