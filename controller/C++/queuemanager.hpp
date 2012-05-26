#ifndef _QUEUEMANAGER_HPP
#define _QUEUEMANAGER_HPP

#include "array.hpp"
#include "socket.hpp"

#include <iostream>
#include <list>

using namespace std;

class QueueManager {
public:
	QueueManager();
	QueueManager(Socket *drain);
	~QueueManager();
	void setDrain(Socket *drain);
	void addSocket(Socket *s);
	void delSocket(Socket *s);
private:
	Socket *drain;
	list<Socket *> sources;
};

#endif /* _QUEUEMANAGER_HPP */
