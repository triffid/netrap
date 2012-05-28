#ifndef _TCPCLIENT_HPP
#define	_TCPCLIENT_HPP

#include <string>
#include <map>

#include "TCPSocket.hpp"

class TCPClient : public TCPSocket {
public:
	TCPClient(int fd, struct sockaddr *addr);
	~TCPClient();

	int open(int fd);
protected:
	void onread(struct SelectFd *selected);
	void onwrite(struct SelectFd *selected);
	void onerror(struct SelectFd *selected);

	std::map<string, string> httpdata;
	
#define TCPCLIENT_STATE_CLASSIFY 0
#define TCPCLIENT_STATE_HTTPHEADER 1
#define TCPCLIENT_STATE_HTTPBODY 2
	int state;

	int bodysize;
	int bodyrmn;
	int bodycomplete;

	char *httpbody;

	void process_http_request();

	int printl(const char *str);
};

#endif /* _TCPCLIENT_HPP */
