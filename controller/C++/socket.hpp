#ifndef _SOCKET_HPP
#define	_SOCKET_HPP

#include <sys/time.h>

#include <string>

#include "ringbuffer.hpp"
#include "selector.hpp"

class Socket : public SelectorEventReceiver {
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
	int printf(const char *format, ...);

	int read(char *buf, int buflen);

	void stall(void);
	void unstall(void);
	int is_stalled(void);

	int fd();

	const char *toString();
protected:
	int _fd;
	int stalled;
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
