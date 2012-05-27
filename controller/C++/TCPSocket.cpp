#include "TCPSocket.hpp"

TCPSocket::TCPSocket(int fd, struct sockaddr *addr) {
	memcpy(&myaddr, addr, socksize(addr));
	Socket::open(fd);
	sock2a(addr, description, sizeof(description));
}

TCPSocket::~TCPSocket() {
}
