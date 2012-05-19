#include <iostream>
#include <cstdio>

#include "array.hpp"
#include "ringbuffer.hpp"

int main(int argc, char **argv) {
	Ringbuffer *r = new Ringbuffer(1024);
	r->writefromfd(stdin, 1024);
	cout << r->readtofd(stdout, 1024) << " chars written" << endl;
}
