#ifndef _TCPCLIENT_HPP
#define	_TCPCLIENT_HPP

#include <string>
#include <map>

#include "TCPSocket.hpp"
#include "printer.hpp"

class TCPClient;

class TCPClient : public TCPSocket {
public:
	TCPClient(int fd, struct sockaddr *addr);
	~TCPClient();

	int open(int fd);
protected:
	void onread(struct SelectFd *selected);
	void onwrite(struct SelectFd *selected);
	void onerror(struct SelectFd *selected);

	std::map<string, string> httpdata;

#define TCPCLIENT_STATE_CLASSIFY 0
#define TCPCLIENT_STATE_CLOSING 1
#define TCPCLIENT_STATE_HTTPHEADER 2
#define TCPCLIENT_STATE_HTTPBODY 3
	int state;

	int bodysize;
	int bodyrmn;
	int bodycomplete;

	char *httpbody;

	Printer *printer;

	void process_http_request();
	void process_netrap_request(const char *line, int len);
	void process_gcode_request(const char *line, int len);

	int printl(const char *str);

	struct Command {
		const char *command;
		void (TCPClient::*func)(const char *line, int len);
	};

	static Command commands[];

	void cmd_list_printers(const char *line, int len);
	void cmd_add_printer(const char *line, int len);
	void cmd_use_printer(const char *line, int len);
	void cmd_exit(const char *line, int len);
	void cmd_shutdown(const char *line, int len);
};

#endif /* _TCPCLIENT_HPP */
