#ifndef _TCPSOCKET_HPP
#define _TCPSOCKET_HPP

#include "socket.hpp"
#include "TCPListen.hpp"

class TCPSocket : public Socket {
public:
	TCPSocket(struct sockaddr *addr);
	~TCPSocket();
protected:
	char description[64];
	struct sockaddr_storage myaddr;
private:
};

#endif /* _TCPSOCKET_HPP */
