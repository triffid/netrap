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

#define BEHAVIOUR_SOURCEPAUSE 1;
#define BEHAVIOUR_DRAINDROP   2;
	void setBehaviours(int behaviours);

	void addDrain(Socket *drain);
	void delDrain(Socket *drain);

	void addSource(Socket *s);
	void delSource(Socket *s);
private:
	int behaviour;
	list<Socket *> drains;
	list<Socket *> sources;
};

#endif /* _QUEUEMANAGER_HPP */
