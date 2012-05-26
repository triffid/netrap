#include "queuemanager.hpp"

QueueManager::QueueManager() {
}

QueueManager::QueueManager(Socket *drain) {
	setDrain(drain);
}

QueueManager::~QueueManager() {
}

void QueueManager::setDrain(Socket *drain) {
	QueueManager::drain = drain;
}
