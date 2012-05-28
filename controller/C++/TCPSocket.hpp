#ifndef _TCPSOCKET_HPP
#define _TCPSOCKET_HPP

#include "socket.hpp"
#include "TCPListen.hpp"

class TCPSocket : public Socket {
public:
	TCPSocket();
	TCPSocket(int fd, struct sockaddr *addr);
	~TCPSocket();

	int open(int fd);
protected:
	struct sockaddr_storage myaddr;
	
	void onread(struct SelectFd *selected);
	void onwrite(struct SelectFd *selected);
	void onerror(struct SelectFd *selected);
private:
};

#endif /* _TCPSOCKET_HPP */
