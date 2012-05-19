#include "socket.hpp"

namespace C {
#include <unistd.h>
}

Socket::Socket() {
	fd = -1;
}

Socket::~Socket() {
	if (fd != -1)
		C::close(fd);
}
