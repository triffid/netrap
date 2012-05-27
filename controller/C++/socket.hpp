#ifndef _SOCKET_HPP
#define	_SOCKET_HPP

#include <sys/time.h>

#include <string>

#include "selector.hpp"

class Socket {
public:
	Socket();
	~Socket();
	int open(int fd);
	int opened();
	void close();
	
	int canread();
	int canwrite();

	int write(std::string str);
	int write(const char *str, int len);

	int read(char *buf, int buflen);

	int fd();

	const char *toString();
protected:
	int _fd;
	timeval opentime;

	Selector selector;

	void onread(struct SelectFd *selected);
	void onwrite(struct SelectFd *selected);
	void onerror(struct SelectFd *selected);

	char description[64];
private:
};

#endif /* _SOCKET_HPP */
