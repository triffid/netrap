#ifndef _TCPSOCKET_HPP
#define _TCPSOCKET_HPP

#include "socket.hpp"
#include "TCPListen.hpp"

class TCPSocket : public Socket {
public:
	TCPSocket(int fd, struct sockaddr *addr);
	~TCPSocket();
protected:
	struct sockaddr_storage myaddr;
private:
};

#endif /* _TCPSOCKET_HPP */
