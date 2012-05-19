#include "printer.hpp"

#include <cstdio>

namespace C {
	#include <unistd.h>
	#include <sys/types.h>
	#include <sys/stat.h>
	#include <fcntl.h>
}

Printer::Printer() {
	this->fd = -1;
}

Printer::Printer(int fd) {
	open(fd);
}

Printer::Printer(char *port, int baud) {
	open(port, baud);
}

Printer::~Printer() {
	close();
}

int Printer::open(int fd) {
	Printer::fd = fd;
	gettimeofday(&opentime, NULL);
	return 1;
}

int Printer::open(char *port, int baud) {
	fd = open(port, O_RDWR | O_NOCTTY | O_NONBLOCK);
	if (fd != -1) {
		return open(fd);
	}
	return fd;
}

int Printer::opened() {
	return fd;
}

void Printer::close() {
	if (fd != -1)
		C::close(fd);
	fd = -1;
}
