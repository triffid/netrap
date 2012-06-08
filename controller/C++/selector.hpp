#ifndef _SELECTOR_HPP
#define	_SELECTOR_HPP

#include <list>

struct SelectFd;

typedef void (*FdCallback)(void *obj, struct SelectFd *selector);

class Selector;
class SelectorEventReceiver;

struct SelectFd {
	int fd;
// 	FdCallback onread;
// 	FdCallback onwrite;
// 	FdCallback onerror;
	Selector *parent;
	SelectorEventReceiver *callbackObj;
	void *data;
#define POLL_READ 1
#define POLL_WRITE 2
#define POLL_ERROR 4
	int poll;
};

class SelectorEventReceiver {
public:
	SelectorEventReceiver();
	~SelectorEventReceiver();
protected:
	virtual void onread(SelectFd *) = 0;
	virtual void onwrite(SelectFd *) = 0;
	virtual void onerror(SelectFd *) = 0;

	friend class Selector;
};

class Selector {
public:
	Selector();
	~Selector();

	struct SelectFd * add(int fd, FdCallback onread, FdCallback onwrite, FdCallback onerror, void *callbackObj, void *data);
	struct SelectFd * add(int fd, SelectorEventReceiver *callbackObj);
	void remove(int fd);

	struct SelectFd * operator[](int fd);

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
