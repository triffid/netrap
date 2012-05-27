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
	int paused;
};

class Selector {
public:
	Selector();
	~Selector();

	void add(int fd, FdCallback onread, FdCallback onwrite, FdCallback onerror, void *callbackObj, void *data);

	void remove(struct SelectFd *sel);
	void remove(int fd);
	
	void pause(int fd);
	void resume(int fd);
	
	void wait();
	void poll();
	
	static void allwait();
	static void allpoll();

	typedef std::list<struct SelectFd *>::iterator iterator;
	
	iterator begin();
	iterator end();
	
protected:
	std::list<struct SelectFd *> fdlist;
	static std::list<struct SelectFd *> globalfdlist;
private:
};

#endif /* _SELECTOR_HPP */
