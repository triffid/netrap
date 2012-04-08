#include	"ringbuffer.h"

#include	<stdio.h>
#include	<unistd.h>

#include	<sys/types.h>
#include	<sys/socket.h>

void ringbuffer_init(ringbuffer *rb) {
	rb->head = rb->tail = rb->nl = 0;
}

unsigned int ringbuffer_canread(ringbuffer *rb) {
	return((rb->head - rb->tail) & (BUFFER_SIZE - 1));
}

unsigned int ringbuffer_canwrite(ringbuffer *rb) {
	return((rb->tail - 1 - rb->head) & (BUFFER_SIZE - 1));
}

void ringbuffer_status(ringbuffer *rb) {
	fprintf(stderr, "Ringbuffer %p:\n\thead: %d\n\ttail: %d\n\tfill: %d\n\twrit: %d\n", rb, rb->head, rb->tail, ringbuffer_canread(rb), ringbuffer_canwrite(rb));
}

unsigned int ringbuffer_read(ringbuffer *rb, char *buffer, unsigned int maxchars) {
	if (maxchars > ringbuffer_canread(rb))
		maxchars = ringbuffer_canread(rb);
	for (unsigned int i = 0; i < maxchars; i++) {
		buffer[i] = rb->data[rb->tail++];
		rb->tail &= (BUFFER_SIZE - 1);
		if ((buffer[i] == 10) && (rb->nl > 0))
			rb->nl--;
	}
	return maxchars;
}

unsigned int ringbuffer_readtofd(ringbuffer *rb, int fd) {
	unsigned int r;
	if (rb->head > rb->tail) {
		//write(STDERR_FILENO, "> ", 2);
		//write(STDERR_FILENO, &rb->data[rb->tail], rb->head - rb->tail);
		r = write(fd, &rb->data[rb->tail], rb->head - rb->tail);
	}
	else {
		//write(STDERR_FILENO, "> ", 2);
		//write(STDERR_FILENO, &rb->data[rb->tail], BUFFER_SIZE - rb->tail);
		r = write(fd, &rb->data[rb->tail], BUFFER_SIZE - rb->tail);
	}
	//fprintf(stderr, "*** readtofd: %d bytes: tail = %d ->", r, rb->tail);
	rb->tail += r;
	rb->tail &= (BUFFER_SIZE - 1);
	//fprintf(stderr, " %d\n", rb->tail);
	return r;
}

unsigned int ringbuffer_readline(ringbuffer *rb, char *linebuffer, unsigned int maxchars) {
	if (rb->nl == 0)
		return 0;
	if (maxchars > ringbuffer_canread(rb))
		maxchars = ringbuffer_canread(rb);
	unsigned int t = rb->tail;
	for (unsigned int i = 0; i < maxchars; i++) {
		linebuffer[i] = rb->data[t++];
		t &= (BUFFER_SIZE - 1);
		if (linebuffer[i] == 10) {
			i++;
			linebuffer[i] = 0;
			rb->nl--;
			rb->tail = t;
			return i;
		}
	}
	return maxchars;
}

void ringbuffer_scannl(ringbuffer *rb) {
	rb->nl = 0;
	//fprintf(stderr, "checking buffer.. ");
	for (unsigned int i = rb->tail; i != (rb->head + 1); i = (i + 1) & (BUFFER_SIZE - 1)) {
		//fprintf(stderr, "%d=0x%02X (%c), ", i, rb->data[i], rb->data[i]);
		if (rb->data[i] == 10)
			rb->nl++;
	}
	//fprintf(stderr, "\n");
}

unsigned int ringbuffer_writefromfd(ringbuffer *rb, int fd, unsigned int nchars) {
	if (nchars > ringbuffer_canwrite(rb))
		nchars = ringbuffer_canwrite(rb);

	//fprintf(stderr, "writefromfd: nchars = %d\n", nchars);

	unsigned int rmn = nchars;
	unsigned int r, rcv, rcvtot;
	rcvtot = 0;
	while (rmn) {
		//fprintf(stderr, "writefromfd: rmn = %d\n", rmn);
		r = BUFFER_SIZE - rb->head;
		if (r > rmn)
			r = rmn;
		//fprintf(stderr, "writefromfd: r = %d\n", r);
		rcv = read(fd, &rb->data[rb->head], r);
		rcvtot += rcv;
		//fprintf(stderr, "writefromfd: rcv = %d, rcvtot = %d\n", rcv, rcvtot);
		rb->head += rcv;
		rb->head &= (BUFFER_SIZE - 1);
		if (rcv < r) {
			rmn -= r;
			ringbuffer_scannl(rb);
			return rcvtot;
		}
		rmn -= r;
	}
	ringbuffer_scannl(rb);
	return rcvtot;
}

unsigned int ringbuffer_writefromsock(ringbuffer *rb, int fd, unsigned int nchars) {
	if (nchars > ringbuffer_canwrite(rb))
		nchars = ringbuffer_canwrite(rb);

	//fprintf(stderr, "writefromfd: nchars = %d\n", nchars);

	unsigned int rmn = nchars;
	unsigned int r, rcv, rcvtot;
	rcvtot = 0;
	while (rmn) {
		//fprintf(stderr, "writefromfd: rmn = %d\n", rmn);
		r = BUFFER_SIZE - rb->head;
		if (r > rmn)
			r = rmn;
		//fprintf(stderr, "writefromfd: r = %d\n", r);
		rcv = recv(fd, &rb->data[rb->head], r, 0);
		rcvtot += rcv;
		//fprintf(stderr, "writefromfd: rcv = %d, rcvtot = %d\n", rcv, rcvtot);
		rb->head += rcv;
		rb->head &= (BUFFER_SIZE - 1);
		if (rcv < r) {
			rmn -= r;
			ringbuffer_scannl(rb);
			return rcvtot;
		}
		rmn -= r;
	}
	ringbuffer_scannl(rb);
	return rcvtot;
}

unsigned int ringbuffer_write(ringbuffer *rb, char *buffer, unsigned int maxchars) {
	if (maxchars > ringbuffer_canwrite(rb))
		maxchars = ringbuffer_canwrite(rb);
	for (unsigned int i = 0; i < maxchars; i++) {
		rb->data[rb->head++] = buffer[i];
		rb->head &= (BUFFER_SIZE - 1);
		if (buffer[i] == 10)
			rb->nl++;
	}
	return maxchars;
}
