#include "TCPListen.hpp"

#include <sys/select.h>

namespace C {
	int clisten(int sockfd, int backlog) {
		return listen(sockfd, backlog);
	}
	int caccept(int sockfd, struct sockaddr *addr, socklen_t *addrlen) {
		return accept(sockfd, addr, addrlen);
	}
}

TCPListen::TCPListen() {
	listenfd.clear();
}

TCPListen::TCPListen(uint16_t port) {
	listen(port);
}

TCPListen::~TCPListen() {
}

static uint16_t sockport(void *address) {
	if (((struct sockaddr *) address)->sa_family == AF_INET) {
		struct sockaddr_in *s = (struct sockaddr_in *) address;
		return s->sin_port;
	}
	else if (((struct sockaddr *) address)->sa_family == AF_INET6) {
		struct sockaddr_in6 *s = (struct sockaddr_in6 *) address;
		return s->sin6_port;
	}
	return 0;
}

static int sock2a(void *address, char *buffer, int length) {
	void *addr;
	char buf[256];
	uint16_t port;
	char *fmt = NULL;
	if (((struct sockaddr *) address)->sa_family == AF_INET) {
		struct sockaddr_in *s = (struct sockaddr_in *) address;
		addr = &s->sin_addr;
		port = s->sin_port;
		fmt = "%s:%d";
	}
	else if (((struct sockaddr *) address)->sa_family == AF_INET6) {
		struct sockaddr_in6 *s = (struct sockaddr_in6 *) address;
		addr = &s->sin6_addr;
		port = s->sin6_port;
		fmt = "[%s].%d";
	}
	
	if (fmt) {
		inet_ntop(((struct sockaddr * ) address)->sa_family, addr, buf, 256);
		return snprintf(buffer, length, fmt, buf, ntohs(port));
	}
	else {
		fprintf(stderr, "bad sockaddr %p, family is %d\n", address, ((struct sockaddr *) address)->sa_family);
		exit(1);
	}
}

int TCPListen::listen(uint16_t port) {
	struct addrinfo hints;
	struct addrinfo *result, *rp;
	int s;
	char buf[64];
	memset(&hints, 0, sizeof(struct addrinfo));
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_flags = AI_PASSIVE;
	hints.ai_protocol = 0;
	hints.ai_canonname = NULL;
	hints.ai_addr = NULL;
	hints.ai_next = NULL;
	
	snprintf(buf, 64, "%d", port);
	if ((s = getaddrinfo(NULL, buf, &hints, &result)) != 0) {
		fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(s));
		exit(1);
	}
	
// 	listen_socket *listensock;
	for (rp = result; rp != NULL; rp = rp->ai_next) {
// 		listensock = malloc(sizeof(listen_socket));
// 		listensock->type = SOCKTYPE_LISTEN;
		
		memcpy(&listenaddr, rp->ai_addr, rp->ai_addrlen);
		
		int fd = socket(rp->ai_family, SOCK_STREAM, IPPROTO_TCP);
		
		int yes = 1;
		if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int)) == -1) {
			perror("setsockopt");
			exit(1);
		}
		
		if (rp->ai_family == AF_INET6) {
			if (setsockopt(fd, IPPROTO_IPV6, IPV6_V6ONLY, &yes, sizeof(int)) == -1) {
				perror("setsockopt");
				exit(1);
			}
		}
		
		if (bind(fd, rp->ai_addr, rp->ai_addrlen) == -1) {
			perror("bind");
			exit(1);
		}
		
		if (C::clisten(fd, SOMAXCONN) == -1) {
			perror("listen");
			exit(1);
		}
		
		sock2a(rp->ai_addr, buf, 64);
		fprintf(stderr, "Listening on %s\n", buf);
		
		listenport = sockport(rp->ai_addr);
		listenfd.push_back(fd);
// 		listensock->protocol = protocol;
		
// 		readsockets = array_push(readsockets, listensock);
// 		errorsockets = array_push(errorsockets, listensock);
	}
	
	freeaddrinfo(result);
// 	return listensock;
	return 0;
}

int TCPListen::waiting() {
	fd_set testread;
	struct timeval timeout = { 1, 0 };
	FD_ZERO(&testread);
	std::list<int>::iterator i;
	int fdmax = 0;
	for (i=listenfd.begin(); i != listenfd.end(); ++i) {
		FD_SET(*i, &testread);
		if (*i >= fdmax)
			fdmax = *i + 1;
	}
	return select(fdmax, &testread, NULL, &testread, &timeout);
}

Socket *TCPListen::accept() {
	struct sockaddr_storage addr;
	socklen_t addrsize = sizeof(addr);

	fd_set testread;
	struct timeval timeout = { 0, 0 };
	FD_ZERO(&testread);
	int fdmax = 0;
	std::list<int>::iterator i;
	for (i=listenfd.begin(); i != listenfd.end(); ++i) {
		FD_SET(*i, &testread);
		if (*i >= fdmax)
			fdmax = *i + 1;
	}
	
	if (select(fdmax, &testread, NULL, NULL, &timeout)) {
		int fd = -1;
		std::list<int>::iterator i;
		for (i=listenfd.begin(); i != listenfd.end(); ++i) {
			if (FD_ISSET(*i, &testread)) {
				fd = *i;
				break;
			}
		}
		int newfd = C::caccept(fd, (struct sockaddr *)&addr, &addrsize);

		Socket *newsock = new Socket();
		newsock->open(newfd);

		char buf[64];
		sock2a(&addr, buf, 64);
		printf("New connection from %s (%d/%p)\n", buf, newfd, newsock);

		return newsock;
	}
	return NULL;
}

uint16_t TCPListen::port() {
	return listenport;
}
