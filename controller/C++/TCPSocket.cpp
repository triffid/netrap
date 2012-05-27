#include "TCPSocket.hpp"

TCPSocket::TCPSocket(struct sockaddr *addr) {
	memcpy(&myaddr, addr, socksize(addr));
	sock2a(addr, description, sizeof(description));
}

TCPSocket::~TCPSocket() {
}
