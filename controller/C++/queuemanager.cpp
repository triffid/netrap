#include "queuemanager.hpp"

QueueManager::QueueManager() {
}

QueueManager::QueueManager(Socket *drain) {
	setDrain(drain);
}

QueueManager::~QueueManager() {
}

void QueueManager::setBehaviours(int behaviours) {
	behaviour = behaviours;
}

void QueueManager::addDrain(Socket *drain) {
	drains.push_back(drain);
}

void QueueManager::delDrain(Socket *drain) {
	drains.remove(drain);
}

void addSocket(Socket *s) {
	sources.push_back(s);
}

void delSocket(Socket *s) {
	sources.remove(s);
}
