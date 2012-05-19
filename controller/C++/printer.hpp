#ifndef _PRINTER_HPP

#include <sys/time.h>

class Printer {
	Printer(void);
	Printer(int fd);
	Printer(char *port, int baud);
	~Printer(void);
public:
	int open(char *port, int baud);
	int open(int fd);
	int opened();
	void close();
private:
	int fd;
	timeval opentime;
};

#endif /* _PRINTER_HPP */
