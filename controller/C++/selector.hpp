#ifndef _SELECTOR_HPP
#define	_SELECTOR_HPP

#include <list>

struct SelectFd;

typedef void (*FdCallback)(void *obj, struct SelectFd *selector);

class Selector;

struct SelectFd {
	int fd;
	FdCallback onread;
	FdCallback onwrite;
	FdCallback onerror;
	Selector *parent;
	void *callbackObj;
	void *data;
#define POLL_READ 1
#define POLL_WRITE 2
#define POLL_ERROR 4
	int poll;
};

class Selector {
public:
	Selector();
	~Selector();

	struct SelectFd * add(int fd, FdCallback onread, FdCallback onwrite, FdCallback onerror, void *callbackObj, void *data);

// 	void remove(struct SelectFd *sel);
	void remove(int fd);
	
	void wait();
	void poll();
	
	static void allwait();
	static void allpoll();

	typedef std::list<struct SelectFd *>::iterator iterator;
	
	iterator begin();
	iterator end();

	static int canread(int fd);
	static int canwrite(int fd);
	static int canerror(int fd);
protected:
	std::list<struct SelectFd *> fdlist;
	std::list<struct SelectFd *>::iterator fditerator;
	static std::list<struct SelectFd *> globalfdlist;
	static std::list<struct SelectFd *>::iterator globalfditerator;
private:
};

#endif /* _SELECTOR_HPP */
