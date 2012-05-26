#ifndef _SOCKET_HPP
#define	_SOCKET_HPP

#include <sys/time.h>

#include <string>

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
protected:
	int _fd;
	timeval opentime;
private:
};

#endif /* _SOCKET_HPP */
