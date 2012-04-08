/****************************************************************************\
*                                                                            *
\****************************************************************************/

#include	<stdio.h>
#include	<stdint.h>
#include	<stdlib.h>

#include	<sys/select.h>
#include	<sys/time.h>
#include	<sys/types.h>
#include	<sys/stat.h>
#include	<sys/socket.h>

#include	<netinet/in.h>
#include	<netinet/ip.h>
#include	<netinet/tcp.h>

#include	<arpa/inet.h>

#include	<errno.h>
#include	<string.h>
#include	<termios.h>
#include	<unistd.h>
#include	<fcntl.h>
#include	<netdb.h>

#define BUFFER_SIZE 1024

#include	"array.h"
#include	"ringbuffer.h"

/****************************************************************************\
*                                                                            *
* Connection Defaults                                                        *
*                                                                            *
\****************************************************************************/

#define	DEFAULT_PORT "/dev/arduino"
#define	DEFAULT_BAUD 115200

#define	DEFAULT_LISTEN_ADDR 0.0.0.0
#define	DEFAULT_LISTEN_PORT 2560

/****************************************************************************\
*                                                                            *
* Data Structures - Sockets                                                  *
*                                                                            *
\****************************************************************************/


#define SOCKTYPE_LOCAL 0
typedef struct {
	int     type;
	int     fd;
} local_socket;

#define	SOCKTYPE_PRINTER 1
typedef struct {
	local_socket socket;

	ringbuffer  rxbuffer;
	ringbuffer	txbuffer;

	local_socket * lastmsgsock;
	int lastmsgindex;

	struct termios termios;

	char *   portname;
	int      baud;

	int      tokens;
	int      maxtoken;
} printer_socket;

#define SOCKTYPE_CLIENT 2
typedef struct {
	local_socket socket;

	ringbuffer rxbuffer;
	ringbuffer txbuffer;

	struct sockaddr_storage addr;
} client_socket;

#define	SOCKTYPE_LISTEN 3
typedef struct {
	local_socket socket;

	struct sockaddr_storage addr;
} listen_socket;

#define SOCKTYPE_FILE 4
typedef struct {
	local_socket socket;

	char * filename;
	ssize_t filesize;

	ringbuffer rxbuffer;

	struct timeval starttime;

	struct timeval lastpausetime;
	struct timeval pausedtime;

	char paused;
	char eof;
} file_socket;

/****************************************************************************\
*                                                                            *
* Utility Functions                                                          *
*                                                                            *
\****************************************************************************/

int sock2a(void *address, char *buffer, int length) {
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

speed_t baud2termios(int baud) {
	switch(baud) {
		case 0:
				return B0;
		case 50:
				return B50;
		case 75:
				return B75;
		case 110:
				return B110;
		case 134:
				return B134;
		case 150:
				return B150;
		case 200:
				return B200;
		case 300:
				return B300;
		case 600:
				return B600;
		case 1200:
				return B1200;
		case 1800:
				return B1800;
		case 2400:
				return B2400;
		case 4800:
				return B4800;
		case 9600:
				return B9600;
		case 19200:
				return B19200;
		case 38400:
				return B38400;
		#ifdef B57600
			case 57600:
				return B57600;
		#endif
		#ifdef B115200
			case 115200:
				return B115200;
		#endif
		#ifdef B230400
			case 230400:
				return B230400;
		#endif
		#ifdef B460800
			case 460800:
				return B460800;
		#endif
		#ifdef B500000
			case 500000:
				return B500000;
		#endif
		#ifdef B576000
			case 576000:
				return B576000;
		#endif
		#ifdef B921600
			case 921600:
				return B921600;
		#endif
		#ifdef B1000000
			case 1000000:
				return B1000000;
		#endif
		#ifdef B1152000
			case 1152000:
				return B1152000;
		#endif
		#ifdef B1500000
			case 1500000:
				return B1500000;
		#endif
		#ifdef B2000000
			case 2000000:
				return B2000000;
		#endif
		#ifdef B2500000
			case 2500000:
				return B2500000;
		#endif
		#ifdef B3000000
			case 3000000:
				return B3000000;
		#endif
		#ifdef B3500000
			case 3500000:
				return B3500000;
		#endif
		#ifdef B4000000
			case 4000000:
				return B4000000;
		#endif
		default:
			fprintf(stderr, "invalid baud rate: %d\n", baud);
			exit(1);
	}
}

/****************************************************************************\
*                                                                            *
* Printer Constructor                                                        *
*                                                                            *
\****************************************************************************/

printer_socket * new_printer_socket(char * portname, int baud) {
	printer_socket *s = malloc(sizeof(printer_socket));

	s->socket.type = SOCKTYPE_PRINTER;

	s->socket.fd = open(portname, O_RDWR | O_NOCTTY);
	if (s->socket.fd == -1) {
		fprintf(stderr, "error opening %s: %s\n", portname, strerror(errno));
		exit(1);
	}

	if (tcgetattr(s->socket.fd, &s->termios) == -1) {
		fprintf(stderr, "error getting attributes for %s: %s\n", portname, strerror(errno));
		exit(1);
	}

	cfmakeraw(&s->termios);

	if (cfsetspeed(&s->termios, baud2termios(baud)) == -1) {
		fprintf(stderr, "error setting baud rate on %s: %s\n", portname, strerror(errno));
		exit(1);
	}

	if (tcsetattr(s->socket.fd, TCSANOW, &s->termios) == -1) {
		fprintf(stderr, "error setting attributes for %s: %s\n", portname, strerror(errno));
		exit(1);
	}

	s->tokens = 1;
	s->maxtoken = 1;

	ringbuffer_init(&s->rxbuffer);
	ringbuffer_init(&s->txbuffer);

	return s;
}

/****************************************************************************\
*                                                                            *
* Main                                                                       *
*                                                                            *
\****************************************************************************/

int main(int argc, char **argv) {
	char buf[1024];

	fd_set *     readselect  = malloc(sizeof(fd_set));
	fd_set *     writeselect = malloc(sizeof(fd_set));
	fd_set *     errorselect = malloc(sizeof(fd_set));
	unsigned int maxfd = 3;

	array *      readsockets  = array_init(); readsockets->name = "read";
	array *      writesockets = array_init(); writesockets->name = "write";
	array *      errorsockets = array_init(); errorsockets->name = "error";

	local_socket * stdin_sock = malloc(sizeof(local_socket));
	stdin_sock->type = SOCKTYPE_LOCAL;
	stdin_sock->fd   = STDIN_FILENO;

	int running = 1;

	char * printer_port = DEFAULT_PORT;
	int printer_baud = DEFAULT_BAUD;

	printer_socket *printer = new_printer_socket(printer_port, printer_baud);

	file_socket *file = NULL;

	if (printer->socket.fd >= maxfd)
		maxfd = printer->socket.fd + 1;

	uint16_t listen_port = DEFAULT_LISTEN_PORT;
	struct addrinfo hints;
	struct addrinfo *result, *rp;
	int s;
	char service[7];
	memset(&hints, 0, sizeof(struct addrinfo));
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	hints.ai_flags = AI_PASSIVE;
	hints.ai_protocol = 0;
	hints.ai_canonname = NULL;
	hints.ai_addr = NULL;
	hints.ai_next = NULL;

	snprintf(service, 7, "%d", listen_port);
	if ((s = getaddrinfo(NULL, service, &hints, &result)) != 0) {
		fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(s));
		exit(1);
	}

	readsockets = array_push(readsockets, stdin_sock);
	readsockets = array_push(readsockets, printer);

	errorsockets = array_push(errorsockets, stdin_sock);
	errorsockets = array_push(errorsockets, printer);

/***************************************************************************\
*                                                                           *
* Now set up network sockets                                                *
*                                                                           *
\***************************************************************************/

	for (rp = result; rp != NULL; rp = rp->ai_next) {
		listen_socket *listensock = malloc(sizeof(listen_socket));
		listensock->socket.type = SOCKTYPE_LISTEN;

		memcpy(&listensock->addr, rp->ai_addr, rp->ai_addrlen);

		listensock->socket.fd = socket(rp->ai_family, SOCK_STREAM, IPPROTO_TCP);

		int yes = 1;
		if (setsockopt(listensock->socket.fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int)) == -1) {
			perror("setsockopt");
			exit(1);
		}

		if (rp->ai_family == AF_INET6) {
			if (setsockopt(listensock->socket.fd, IPPROTO_IPV6, IPV6_V6ONLY, &yes, sizeof(int)) == -1) {
				perror("setsockopt");
				exit(1);
			}
		}

		if (bind(listensock->socket.fd, rp->ai_addr, rp->ai_addrlen) == -1) {
			perror("bind");
			exit(1);
		}

		if (listen(listensock->socket.fd, SOMAXCONN) == -1) {
			perror("listen");
			exit(1);
		}

		sock2a(rp->ai_addr, buf, BUFFER_SIZE);
		fprintf(stderr, "Listening on %s\n", buf);

		readsockets = array_push(readsockets, listensock);
		errorsockets = array_push(errorsockets, listensock);
	}

	freeaddrinfo(result);

	while (running) {
		FD_ZERO(readselect);
		FD_ZERO(writeselect);
		FD_ZERO(errorselect);
		for (int i = 0; i < readsockets->length; i++) {
			int fd = ((local_socket *) readsockets->data[i])->fd;
			//printf("check read %d\n", ((local_socket *) readsockets->data[i])->fd);
			FD_SET(fd, readselect);
			if (fd >= maxfd)
				maxfd = fd + 1;
		}
		for (int i = 0; i < writesockets->length; i++) {
			int fd = ((local_socket *) writesockets->data[i])->fd;
			//printf("check write %d\n", ((local_socket *) writesockets->data[i])->fd);
			FD_SET(fd, writeselect);
			if (fd >= maxfd)
				maxfd = fd + 1;
		}
		for (int i = 0; i < errorsockets->length; i++) {
			int fd = ((local_socket *) errorsockets->data[i])->fd;
			//printf("check error %d\n", ((local_socket *) errorsockets->data[i])->fd);
			FD_SET(((local_socket *) errorsockets->data[i])->fd, errorselect);
			if (fd >= maxfd)
				maxfd = fd + 1;
		}
		select(maxfd, readselect, writeselect, errorselect, NULL);

		for (int i = 0; i < errorsockets->length; i++) {
			local_socket *s = (local_socket *) errorsockets->data[i];
			if (FD_ISSET(s->fd, errorselect)) {
				printf("error on %d: %p\n", s->fd, s);
				switch (s->type) {
					case SOCKTYPE_LOCAL:
						break;
					case SOCKTYPE_PRINTER:
						break;
					case SOCKTYPE_CLIENT:
						break;
					case SOCKTYPE_LISTEN:
						break;
				}
			}
		}

		for (int i = 0; i < readsockets->length; i++) {
			local_socket *s = (local_socket *) readsockets->data[i];
			if (FD_ISSET(s->fd, readselect)) {
				//printf("read %d (type %d)\n", s->fd, s->type);
				switch (s->type) {
					case SOCKTYPE_LOCAL:
						{
							ssize_t r = read(s->fd, buf, 1024);
							buf[r] = 0;
							if (r == 0) {
								printf("EOF on stdin, exiting...\n");
								exit(0);
							}
							else {
								//printf(" %d bytes: %s\n", r, buf);
								printer->lastmsgsock = s;
								ringbuffer_write(&printer->txbuffer, buf, r);
								//printf("tokens: %d\n", printer->tokens);
								if (printer->tokens > 0)
									if (array_indexof(writesockets, printer) == -1)
										writesockets = array_push(writesockets, printer);
							}
						}
						break;
					case SOCKTYPE_PRINTER:
						{
							//printf("can read printer\n");
							printer_socket *sock = (printer_socket *) s;
							unsigned int r = ringbuffer_writefromfd(&sock->rxbuffer, s->fd, BUFFER_SIZE);
							if (r == 0) {
								//printf(" %d bytes: printer disconnected, trying to reconnect...\n", r);
								close(s->fd);
								readsockets = array_delete(readsockets, sock);
								writesockets = array_delete(writesockets, sock);
								errorsockets = array_delete(errorsockets, sock);
								free(sock);
								sock = NULL;
								sock = new_printer_socket(printer_port, printer_baud);
								readsockets = array_push(readsockets, sock);
								errorsockets = array_push(errorsockets, sock);
							}
							else {
								//printf(" %d bytes, %d newlines", r, sock->rxbuffer.nl);
								while (sock->rxbuffer.nl > 0) {
									char line[BUFFER_SIZE];
									int r = ringbuffer_readline(&sock->rxbuffer, line, BUFFER_SIZE);
									if (sock->lastmsgsock->fd > 2)
										printf("< %s", line);
									int m = snprintf(buf, BUFFER_SIZE, "< %s", line);
									if (sock->lastmsgsock->type == SOCKTYPE_LOCAL) {
										int i = 0;
										do {
											i += write(sock->lastmsgsock->fd, &buf[i], m - i);
										} while (i < m);
									}
									else if (sock->lastmsgsock->type == SOCKTYPE_CLIENT) {
										//printf("client type\n");
										client_socket *cs = (client_socket *) sock->lastmsgsock;
										ringbuffer_write(&cs->txbuffer, line, r);
										if (array_indexof(writesockets, cs) == -1) {
											writesockets = array_push(writesockets, cs);
											//printf("pushed %p/%d to writesockets\n", cs, cs->socket.fd);
										}
									}
									if (strncmp(line, "ok", 2) == 0) {
										//fprintf(stderr, "got token!");
										if (sock->tokens < sock->maxtoken)
											sock->tokens++;
										for (int i = 0; i < errorsockets->length; i++) {
											if (((local_socket *) errorsockets->data[i])->type == SOCKTYPE_CLIENT)
												readsockets = array_push(readsockets, errorsockets->data[i]);
										}
										if (file != NULL)
											writesockets = array_push(writesockets, sock);
										//fprintf(stderr, " tokens: %d\n", sock->tokens);
									}
									else {
										//fprintf(stderr, "no token\n");
									}
								}
							}
						}
						break;
					case SOCKTYPE_CLIENT:
						{
							client_socket *sock = (client_socket *) s;
							unsigned int r = ringbuffer_writefromfd(&sock->rxbuffer, s->fd, ringbuffer_canwrite(&sock->rxbuffer));
							//printf("writefromfd %p %d %d got %d nl %d\n", &sock->rxbuffer, s->fd, ringbuffer_canwrite(&sock->rxbuffer), r, sock->rxbuffer.nl);
							if (r == 0) {
								sock2a(&sock->addr, buf, BUFFER_SIZE);
								printf("client %s disconnected\n", buf);
								close(sock->socket.fd);
								readsockets = array_delete(readsockets, sock);
								writesockets = array_delete(writesockets, sock);
								errorsockets = array_delete(errorsockets, sock);
								free(sock);
								sock = NULL;
							}
							else if (sock->rxbuffer.nl > 0 && printer->tokens > 0) {
								printer->lastmsgsock = s;
								ringbuffer_readline(&sock->rxbuffer, buf, BUFFER_SIZE);
								char paddr[256];
								sock2a(&sock->addr, paddr, 256);
								printf("from %s (%d): %s", paddr, sock->socket.fd, buf);
								ringbuffer_write(&printer->txbuffer, buf, r);
								if (array_indexof(writesockets, printer) == -1)
									writesockets = array_push(writesockets, printer);
							}
						}
						break;
					case SOCKTYPE_LISTEN:
						{
							printf("got connection ");
							//listen_socket *sock = (listen_socket *) s;
							client_socket * newcs = malloc(sizeof(client_socket));
							newcs->socket.type = SOCKTYPE_CLIENT;
							ringbuffer_init(&newcs->rxbuffer);
							ringbuffer_init(&newcs->txbuffer);
							unsigned int socksize = sizeof(struct sockaddr_storage);
							newcs->socket.fd = accept(s->fd, (struct sockaddr *) &newcs->addr, &socksize);
							sock2a(&newcs->addr, buf, BUFFER_SIZE);
							printf("from %s (%d) sock %p\n", buf, newcs->socket.fd, newcs);
							readsockets = array_push(readsockets, newcs);
							errorsockets = array_push(errorsockets, newcs);
						}
						break;
				}
			}
		}
		for (int i = 0; i < writesockets->length; i++) {
			local_socket *s = (local_socket *) writesockets->data[i];
			if (FD_ISSET(s->fd, writeselect)) {
				//printf("write %d", s->fd);
				switch (s->type) {
					case SOCKTYPE_LOCAL:
						{
							/*if (ringbuffer_canread(s->txbuffer) > 0)
								ringbuffer_readtofd(s->txbuffer, s->fd);
							if (ringbuffer_canread(s->txbuffer) == 0)
								array_delete(writesockets, s);
							*/
						}
						break;
					case SOCKTYPE_PRINTER:
						{
							printer_socket *sock = (printer_socket *) s;
							//printf("write: nl: %d\n", sock->txbuffer.nl);
							if (sock->txbuffer.nl > 0) {
								//printf("write: nl: %d\n", sock->txbuffer.nl);
								unsigned int r = ringbuffer_readline(&sock->txbuffer, buf, BUFFER_SIZE);
								buf[r] = 0;
								printf(">>> %s", buf);
								int i = 0;
								do {
									i += write(s->fd, &buf[i], r - i);
								} while (i < r);
								sock->tokens--;
								if (sock->tokens == 0) {
									for (int i = 0; i < errorsockets->length; i++) {
										if (((local_socket *) errorsockets->data[i])->type == SOCKTYPE_CLIENT)
											readsockets = array_delete(readsockets, errorsockets->data[i]);
									}
								}
							}
							else if ((sock->tokens > 0) && (file != NULL) && (file->paused == 0)) {
								if ((ringbuffer_canwrite(&file->rxbuffer) > 0) && (file->eof == 0)) {
									int w = ringbuffer_writefromfd(&file->rxbuffer, file->socket.fd, BUFFER_SIZE);
									if (w == 0)
										file->eof = 1;
								}
								if (file->rxbuffer.nl > 0) {
									int r = ringbuffer_readline(&file->rxbuffer, buf, BUFFER_SIZE);
									buf[r] = 0;
									printf(">>> %s", buf);
									int i = 0;
									do {
										i += write(s->fd, &buf[i], r - i);
									} while (i < r);
									sock->tokens--;
								}
								else if (file->eof) {
									// file is completely printed
									printf("File %s complete. Print time: \n", file->filename);
									// TODO:close file
								}
							}
							if ((ringbuffer_canread(&sock->txbuffer) == 0) || (sock->tokens == 0))
								writesockets = array_delete(writesockets, sock);
						}
						break;
					case SOCKTYPE_CLIENT:
						{
							//printf("write client socket\n");
							client_socket *sock = (client_socket *) s;
							if (ringbuffer_canread(&sock->txbuffer) > 0) {
								//printf("readtofd %d %p: %d\n", s->fd, &sock->txbuffer,
									ringbuffer_readtofd(&sock->txbuffer, s->fd);
								//);
							}
							if (ringbuffer_canread(&sock->txbuffer) == 0) {
								//printf("client txbuffer empty\n");
								writesockets = array_delete(writesockets, s);
							}
						}
						break;
				}

			}
		}

	}

	return 0;
}
