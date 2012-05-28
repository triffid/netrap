#ifndef _SOCKET_HPP
#define	_SOCKET_HPP

#include <sys/time.h>

#include <string>

#include "ringbuffer.hpp"
#include "selector.hpp"

class Socket {
public:
	Socket();
	Socket(int fd);
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

	virtual void onread(struct SelectFd *selected);
	virtual void onwrite(struct SelectFd *selected);
	virtual void onerror(struct SelectFd *selected);

	char description[64];

	Ringbuffer *rxbuf;
	Ringbuffer *txbuf;
private:
};

#endif /* _SOCKET_HPP */
