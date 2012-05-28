#include "selector.hpp"

#include <sys/select.h>

#include <cstdlib>
#include <cstdio>

std::list<struct SelectFd *> Selector::globalfdlist;
std::list<struct SelectFd *>::iterator Selector::globalfditerator;

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
// 	std::list<struct SelectFd *>::iterator i;
	for (fditerator = fdlist.begin(); fditerator != fdlist.end(); ++fditerator) {
		sel = *fditerator;
		if (sel->poll & POLL_READ)
			FD_SET(sel->fd, &testread);
		if (sel->poll & POLL_WRITE)
			FD_SET(sel->fd, &testwrite);
		if (sel->poll && POLL_ERROR)
			FD_SET(sel->fd, &testerror);
		
		if (sel->fd >= fdmax)
			fdmax = sel->fd + 1;
	}
	if (select(fdmax, &testread, &testwrite, &testerror, NULL)) {
		for (fditerator = fdlist.begin(); fditerator != fdlist.end(); ++fditerator) {
			sel = *fditerator;
			if (sel->poll != 0)
			if (FD_ISSET(sel->fd, &testread)) {
				sel->onread(sel->callbackObj, sel);
			}
			if (sel->poll != 0)
			if (FD_ISSET(sel->fd, &testwrite)) {
				sel->onwrite(sel->callbackObj, sel);
			}
			if (sel->poll != 0)
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
// 	std::list<struct SelectFd *>::iterator i;
	for (fditerator = fdlist.begin(); fditerator != fdlist.end(); ++fditerator) {
		sel = *fditerator;
		if (sel->poll & POLL_READ)
			FD_SET(sel->fd, &testread);
		if (sel->poll & POLL_WRITE)
			FD_SET(sel->fd, &testwrite);
		if (sel->poll & POLL_ERROR)
			FD_SET(sel->fd, &testerror);
		if (sel->fd >= fdmax)
			fdmax = sel->fd + 1;
	}
	if (select(fdmax, &testread, &testwrite, &testerror, &timeout)) {
		for (fditerator = fdlist.begin(); fditerator != fdlist.end(); ++fditerator) {
			sel = *fditerator;
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

struct SelectFd * Selector::add(int fd, FdCallback onread, FdCallback onwrite, FdCallback onerror, void *callbackObj, void *data) {
	struct SelectFd *sel = new SelectFd;
	sel->fd = fd;
	sel->onread = onread;
	sel->onwrite = onwrite;
	sel->onerror = onerror;
	sel->callbackObj = callbackObj;
	sel->data = data;
	sel->poll = POLL_READ | POLL_ERROR;
	fdlist.push_back(sel);
	globalfdlist.push_back(sel);

	return sel;
}

void Selector::remove(int fd) {
	struct SelectFd *sel = NULL;
	std::list<struct SelectFd *>::iterator i;
	
	for (i = fdlist.begin(); i != fdlist.end(); ++i) {
		sel = *i;
		if (sel->fd == fd) {
			sel->poll = 0;
			break;
		}
	}
	
	for (i = globalfdlist.begin(); i != globalfdlist.end(); ++i) {
		sel = *i;
		if (sel->fd == fd) {
			sel->poll = 0;
			break;
		}
	}
}

struct SelectFd * Selector::operator[](int fd) {
	struct SelectFd *sel = NULL;
	std::list<struct SelectFd *>::iterator i;
	
	for (i = fdlist.begin(); i != fdlist.end(); ++i) {
		sel = *i;
		if (sel->fd == fd) {
			return sel;
		}
	}
	return NULL;
}

void Selector::allwait() {
	fd_set testread, testwrite, testerror;
	// 	struct timeval timeout = { 1, 0 };
	FD_ZERO(&testread);
	FD_ZERO(&testwrite);
	FD_ZERO(&testerror);
	int fdmax = 0;
	struct SelectFd *sel;
	for (globalfditerator = globalfdlist.begin(); globalfditerator != globalfdlist.end(); ) {
		sel = *globalfditerator;
		if (sel->poll == 0) {
			globalfditerator = globalfdlist.erase(globalfditerator);
			free(sel);
		}
		else {
			if (sel->poll & POLL_READ)
				FD_SET(sel->fd, &testread);
			if (sel->poll & POLL_WRITE)
				FD_SET(sel->fd, &testwrite);
			if (sel->poll & POLL_ERROR)
				FD_SET(sel->fd, &testerror);
			if (sel->fd >= fdmax)
				fdmax = sel->fd + 1;
			++globalfditerator;
		}
	}
	if (select(fdmax, &testread, &testwrite, &testerror, NULL)) {
		for (globalfditerator = globalfdlist.begin(); globalfditerator != globalfdlist.end(); ++globalfditerator) {
			sel = *globalfditerator;
			if ((sel->poll != 0) && (FD_ISSET(sel->fd, &testread))) {
				sel->onread(sel->callbackObj, sel);
			}
			if ((sel->poll != 0) && (FD_ISSET(sel->fd, &testwrite))) {
				sel->onwrite(sel->callbackObj, sel);
			}
			if ((sel->poll != 0) && (FD_ISSET(sel->fd, &testerror))) {
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
		if (sel->poll & POLL_READ)
			FD_SET(sel->fd, &testread);
		if (sel->poll & POLL_WRITE)
			FD_SET(sel->fd, &testwrite);
		if (sel->poll & POLL_ERROR)
			FD_SET(sel->fd, &testerror);
		if (sel->fd >= fdmax)
			fdmax = sel->fd + 1;
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

int Selector::canread(int fd) {
	fd_set testread;
	struct timeval timeout = { 0, 0 };
	FD_ZERO(&testread);
	FD_SET(fd, &testread);
	return select(fd + 1, &testread, NULL, NULL, &timeout);
}

int Selector::canwrite(int fd) {
	fd_set testwrite;
	struct timeval timeout = { 0, 0 };
	FD_ZERO(&testwrite);
	FD_SET(fd, &testwrite);
	return select(fd + 1, NULL, &testwrite, NULL, &timeout);
}

int Selector::canerror(int fd) {
	fd_set testerror;
	struct timeval timeout = { 0, 0 };
	FD_ZERO(&testerror);
	FD_SET(fd, &testerror);
	return select(fd + 1, NULL, NULL, &testerror, &timeout);
}
