#include "selector.hpp"

#include <sys/select.h>

#include <cstdlib>

std::list<struct SelectFd *> Selector::globalfdlist;

Selector::Selector() {
}

Selector::~Selector() {
}

void Selector::wait() {
	fd_set testread, testwrite, testerror;
// 	struct timeval timeout = { 1, 0 };
	FD_ZERO(&testread);
	FD_ZERO(&testwrite);
	FD_ZERO(&testerror);
	
	int fdmax = 0;
	struct SelectFd *sel;
	std::list<struct SelectFd *>::iterator i;
	for (i=fdlist.begin(); i != fdlist.end(); ++i) {
		sel = *i;
		if (sel->paused == 0) {
			FD_SET(sel->fd, &testread);
			FD_SET(sel->fd, &testwrite);
			FD_SET(sel->fd, &testerror);
			if (sel->fd >= fdmax)
				fdmax = sel->fd + 1;
		}
	}
	if (select(fdmax, &testread, &testwrite, &testerror, NULL)) {
		for (i=fdlist.begin(); i != fdlist.end(); ++i) {
			sel = *i;
			if (FD_ISSET(sel->fd, &testread)) {
				sel->onread(sel->callbackObj, sel);
			}
			if (FD_ISSET(sel->fd, &testwrite)) {
				sel->onwrite(sel->callbackObj, sel);
			}
			if (FD_ISSET(sel->fd, &testerror)) {
				sel->onerror(sel->callbackObj, sel);
			}
		}
	}
}

void Selector::poll() {
	fd_set testread, testwrite, testerror;
	struct timeval timeout = { 1, 0 };
	FD_ZERO(&testread);
	FD_ZERO(&testwrite);
	FD_ZERO(&testerror);
	int fdmax = 0;
	struct SelectFd *sel;
	std::list<struct SelectFd *>::iterator i;
	for (i=fdlist.begin(); i != fdlist.end(); ++i) {
		sel = *i;
		if (sel->paused == 0) {
			FD_SET(sel->fd, &testread);
			FD_SET(sel->fd, &testwrite);
			FD_SET(sel->fd, &testerror);
			if (sel->fd >= fdmax)
				fdmax = sel->fd + 1;
		}
	}
	if (select(fdmax, &testread, &testwrite, &testerror, &timeout)) {
		for (i=fdlist.begin(); i != fdlist.end(); ++i) {
			sel = *i;
			if (FD_ISSET(sel->fd, &testread)) {
				sel->onread(sel->callbackObj, sel);
			}
			if (FD_ISSET(sel->fd, &testwrite)) {
				sel->onwrite(sel->callbackObj, sel);
			}
			if (FD_ISSET(sel->fd, &testerror)) {
				sel->onerror(sel->callbackObj, sel);
			}
		}
	}
}

void Selector::add(int fd, FdCallback onread, FdCallback onwrite, FdCallback onerror, void *callbackObj, void *data) {
	struct SelectFd *sel = new SelectFd;
	sel->fd = fd;
	sel->onread = onread;
	sel->onwrite = onwrite;
	sel->onerror = onerror;
	sel->callbackObj = callbackObj;
	sel->data = data;
	sel->paused = 0;
	fdlist.push_back(sel);
	globalfdlist.push_back(sel);
}

void Selector::remove(struct SelectFd *rem) {
	std::list<struct SelectFd *>::iterator i;
	struct SelectFd *sel = NULL;
	for (i=fdlist.begin(); i != fdlist.end(); ++i) {
		sel = *i;
		if (sel == rem) {
			fdlist.erase(i);
			break;
		}
	}
	for (i=globalfdlist.begin(); i != globalfdlist.end(); ++i) {
		sel = *i;
		if (sel == rem) {
			globalfdlist.erase(i);
			break;
		}
	}
	if (sel)
		free(sel);
}

void Selector::remove(int fd) {
	std::list<struct SelectFd *>::iterator i;
	struct SelectFd *sel = NULL;
	for (i=fdlist.begin(); i != fdlist.end(); ++i) {
		sel = *i;
		if (sel->fd == fd) {
			fdlist.erase(i);
			break;
		}
	}
	for (i=globalfdlist.begin(); i != globalfdlist.end(); ++i) {
		sel = *i;
		if (sel->fd == fd) {
			globalfdlist.erase(i);
			break;
		}
	}
	if (sel)
		free(sel);
}

void Selector::pause(int fd) {
	std::list<struct SelectFd *>::iterator i;
	struct SelectFd *sel;
	for (i=fdlist.begin(); i != fdlist.end(); ++i) {
		sel = *i;
		if (sel->fd == fd) {
			sel->paused = 1;
		}
	}
}

void Selector::resume(int fd) {
	std::list<struct SelectFd *>::iterator i;
	struct SelectFd *sel;
	for (i=fdlist.begin(); i != fdlist.end(); ++i) {
		sel = *i;
		if (sel->fd == fd) {
			sel->paused = 0;
		}
	}
}

void Selector::allwait() {
	fd_set testread, testwrite, testerror;
	// 	struct timeval timeout = { 1, 0 };
	FD_ZERO(&testread);
	FD_ZERO(&testwrite);
	FD_ZERO(&testerror);
	int fdmax = 0;
	struct SelectFd *sel;
	std::list<struct SelectFd *>::iterator i;
	for (i=globalfdlist.begin(); i != globalfdlist.end(); ++i) {
		sel = *i;
		if (sel->paused == 0) {
			FD_SET(sel->fd, &testread);
			FD_SET(sel->fd, &testwrite);
			FD_SET(sel->fd, &testerror);
			if (sel->fd >= fdmax)
				fdmax = sel->fd + 1;
		}
	}
	if (select(fdmax, &testread, &testwrite, &testerror, NULL)) {
		for (i=globalfdlist.begin(); i != globalfdlist.end(); ++i) {
			sel = *i;
			if (FD_ISSET(sel->fd, &testread)) {
				sel->onread(sel->callbackObj, sel);
			}
			if (FD_ISSET(sel->fd, &testwrite)) {
				sel->onwrite(sel->callbackObj, sel);
			}
			if (FD_ISSET(sel->fd, &testerror)) {
				sel->onerror(sel->callbackObj, sel);
			}
		}
	}
}

void Selector::allpoll() {
	fd_set testread, testwrite, testerror;
	struct timeval timeout = { 1, 0 };
	FD_ZERO(&testread);
	FD_ZERO(&testwrite);
	FD_ZERO(&testerror);
	int fdmax = 0;
	struct SelectFd *sel;
	std::list<struct SelectFd *>::iterator i;
	for (i=globalfdlist.begin(); i != globalfdlist.end(); ++i) {
		sel = *i;
		if (sel->paused == 0) {
			FD_SET(sel->fd, &testread);
			FD_SET(sel->fd, &testwrite);
			FD_SET(sel->fd, &testerror);
			if (sel->fd >= fdmax)
				fdmax = sel->fd + 1;
		}
	}
	if (select(fdmax, &testread, &testwrite, &testerror, &timeout)) {
		for (i=globalfdlist.begin(); i != globalfdlist.end(); ++i) {
			sel = *i;
			if (FD_ISSET(sel->fd, &testread)) {
				sel->onread(sel->callbackObj, sel);
			}
			if (FD_ISSET(sel->fd, &testwrite)) {
				sel->onwrite(sel->callbackObj, sel);
			}
			if (FD_ISSET(sel->fd, &testerror)) {
				sel->onerror(sel->callbackObj, sel);
			}
		}
	}
}

Selector::iterator Selector::begin() {
	return fdlist.begin();
}

Selector::iterator Selector::end() {
	return fdlist.end();
}
