#ifndef _TCPLISTEN_HPP
#define _TCPLISTEN_HPP

#include <cstdint>
#include <cstring>
#include <list>

#include	<sys/types.h>
#include	<sys/socket.h>
#include	<netdb.h>
#include	<netinet/in.h>
#include	<netinet/ip.h>
#include	<netinet/tcp.h>
#include	<arpa/inet.h>

#include "socket.hpp"

class TCPListen {
public:
	TCPListen();
	TCPListen(uint16_t port);
	~TCPListen();

	int listen(uint16_t port);
	int waiting();
	Socket *accept();
	uint16_t port();
protected:
	std::list<int> listenfd;
	uint16_t listenport;
	struct sockaddr_storage listenaddr;
};

#endif /* _TCPLISTEN_HPP */