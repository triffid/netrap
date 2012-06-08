#include "TCPClient.hpp"

TCPClient::TCPClient(int fd, struct sockaddr *addr) {
	memcpy(&myaddr, addr, socksize(addr));
	open(fd);
	sock2a(addr, description, sizeof(description));

	state = TCPCLIENT_STATE_CLASSIFY;
}

TCPClient::~TCPClient() {
}

int TCPClient::open(int fd) {
	_fd = fd;
// 	printf("o%d/%d: %p\n", fd, _fd, this);
	gettimeofday(&opentime, NULL);
// 	selector.add(fd, (FdCallback) &TCPClient::onread, (FdCallback) &TCPClient::onwrite, (FdCallback) &TCPClient::onerror, (void *) this, NULL);
	selector.add(fd, this);
	return fd;
}

void TCPClient::onread(struct SelectFd *selected) {
	TCPSocket::onread(selected);
// 	printf("onread %d:%d:%d: %p\n", Socket::_fd, rxbuf->canread(), rxbuf->numlines(), this);
	if (rxbuf->canread() == 0) {
		// socket closed
		return;
	}
	// now check our rxbuf for tasty lines
	char linebuf[256];
	int l;
	while (rxbuf->numlines() > 0) {
		l = rxbuf->readline(linebuf, 256);
		linebuf[l] = 0;
// 		printf("[%d]< ", state); printl(linebuf); printf("\n");
		switch (state) {
			case TCPCLIENT_STATE_CLASSIFY: {
				if (strncmp(linebuf, "GET /", 5) == 0) {
					state = TCPCLIENT_STATE_HTTPHEADER;
					char *tok = linebuf;
					char sep[5] = " \t\r\n";
					httpdata["method"] = string(strsep(&tok, sep));
					httpdata["uri"] = string(strsep(&tok, sep));
					httpdata["protocol"] = string(strsep(&tok, sep));

					bodysize = 0;
					bodyrmn = 0;
					bodycomplete = 0;

					printf("method: %s\nuri: %s\nprotocol: %s\n", httpdata["method"].c_str(), httpdata["uri"].c_str(), httpdata["protocol"].c_str());
				}
				break;
			}
			case TCPCLIENT_STATE_HTTPHEADER: {
// 				printf("(%d:%d:%d)\n", linebuf[0], '\r', bodysize);
				if ((linebuf[0] == '\r') || (linebuf[0] == '\n')) {
// 					printf("is EOL\n");
					if (bodysize > 0) {
						state = TCPCLIENT_STATE_HTTPBODY;
						bodyrmn = bodysize;
						httpbody = (char *) malloc(bodyrmn + 1);
					}
					else {
// 						state = TCPCLIENT_STATE_CLASSIFY;
						process_http_request();
					}
				}
				else {
					char *value = index(linebuf, ':');
					if (value > linebuf) {
						*value = 0;
						do {
							value++;
						} while (index(" \t\r\n", *value) > NULL);
						do {
							l--;
						} while(linebuf[l] < 32);
						linebuf[++l] = 0;

						httpdata[string(linebuf)] = string(value);
// 						printf("Added %s = %s to metadata\n", linebuf, value);
					}
				}
				break;
			}
			case TCPCLIENT_STATE_HTTPBODY: {
				bodyrmn -= l;
				memcpy(&httpbody[bodycomplete], linebuf, l);
				bodycomplete += l;
				if (bodyrmn <= 0) {
					process_http_request();
					free(httpbody);
					httpbody = NULL;
// 					state = TCPCLIENT_STATE_CLASSIFY;
				}
				break;
			}
		}
	}
// 	printf("freed %d bytes in rxbuf\n", rxbuf->canwrite());
	if ((rxbuf->canwrite() > 0) && (_fd >= 0)) {
		selector[_fd]->poll |= POLL_READ;
// 		printf("re-enabled onread as we have %d clear\n", rxbuf->canwrite());
	}
}

void TCPClient::onwrite(struct SelectFd *selected) {
	TCPSocket::onwrite(selected);
	if (state != TCPCLIENT_STATE_CLASSIFY) {
		if (txbuf->canread() == 0) {
			selector.remove(_fd);
			close();
		}
	}
}

void TCPClient::onerror(struct SelectFd *selected) {
	TCPSocket::onerror(selected);
}

void TCPClient::process_http_request() {
	printf("Processing %s request for %s\n", httpdata["method"].c_str(), httpdata["uri"].c_str());
	char writebuf[256];
	char *wp = writebuf;
	wp += snprintf(wp, (writebuf + 256 - wp), "%s 200 OK\r\nConnection: close\r\nContent-Type: text/plain\r\n\r\n", httpdata["protocol"].c_str());
	write(string(writebuf)); wp = writebuf;
	printf("Headers:\n");
	write(string("Headers:\n"));
	std::map<string, string>::iterator i;
	for (i=httpdata.begin(); i != httpdata.end(); i++) {
		printf("\t%s:\t%s\n", (*i).first.c_str(), (*i).second.c_str());
		wp += snprintf(wp, (writebuf + 256 - wp), "\t%s:\t%s\n", (*i).first.c_str(), (*i).second.c_str());
		write(string(writebuf)); wp = writebuf;
	}
// 	close();
// 	selector.remove(_fd);
}

int TCPClient::printl(const char *str) {
	char *p;
	int r;
	for (r = 0, p = (char *) str; *p != 0; p++) {
		if (*p < 32 || *p > 127) {
			r += printf("\\%02X", *p);
		}
		else {
			r += printf("%c", *p);
		}
	}
	return r;
}
