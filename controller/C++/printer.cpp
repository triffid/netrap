#include "printer.hpp"

#include <cstdio>

namespace C {
	#include <unistd.h>
	#include <sys/types.h>
	#include <sys/stat.h>
	#include <fcntl.h>
}

Printer::Printer() {
	Socket::_fd = -1;
	init();
}

Printer::Printer(int fd) {
	Socket::open(fd);
	init();
}

Printer::Printer(char *port, int baud) {
	open(port, baud);
	init();
}

Printer::~Printer() {
	close();
	init();
}

int Printer::open(char *port, int baud) {
	_fd = open(port, O_RDWR | O_NOCTTY | O_NONBLOCK);
	if (_fd != -1) {
		return Socket::open(_fd);
	}
	return _fd;
}

void Printer::init() {
	queuemanager.setDrain(this);
	write("M115\n", 5);
	write("M114\n", 5);
	write("M105\n", 5);
}

int Printer::write(string str) {
	return write(str.c_str(), str.length());
}

int Printer::write(const char *str, int len) {
	// TODO: extract target properties from outgoing commands
	return Socket::write(str, len);
}

int Printer::read(char *buf, int buflen) {
	int r = Socket::read(buf, buflen);
	// TODO: extract properties from replies
	return r;
}
