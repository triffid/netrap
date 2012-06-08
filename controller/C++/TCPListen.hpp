#ifndef _TCPLISTEN_HPP
#define _TCPLISTEN_HPP

#include <cstdint>
#include <cstring>
#include <list>
#include <vector>

#include	<sys/types.h>
#include	<sys/socket.h>
#include	<netdb.h>
#include	<netinet/in.h>
#include	<netinet/ip.h>
#include	<netinet/tcp.h>
#include	<arpa/inet.h>

#include "socket.hpp"
#include "selector.hpp"

int socksize(struct sockaddr *address);
uint16_t sockport(void *address);
int sock2a(void *address, char *buffer, int length);

class TCPListen : public SelectorEventReceiver {
public:
	TCPListen();
	TCPListen(uint16_t port);
	~TCPListen();

	int listen(uint16_t port);
	int waiting();
	Socket *accept();
	uint16_t port();

protected:
	std::vector<int> listenfd;
	uint16_t listenport;
	struct sockaddr_storage listenaddr;

	Selector selector;

	void onread(struct SelectFd *selected);
	void onwrite(struct SelectFd *selected);
	void onerror(struct SelectFd *selected);
};

#endif /* _TCPLISTEN_HPP */
