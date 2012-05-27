#include <iostream>
#include <cstdio>

#include "array.hpp"
#include "ringbuffer.hpp"
#include "TCPListen.hpp"

Selector selector;

int main(int argc, char **argv) {
// 	Ringbuffer *r = new Ringbuffer(1024);
// 	r->writefromfd(stdin, 1024);
// 	cout << r->readtofd(stdout, 1024) << " chars written" << endl;
	TCPListen listener(2560);
	for (;;) {
		selector.allwait();
	}
}
