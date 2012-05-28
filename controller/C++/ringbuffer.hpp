#ifndef	_RINGBUFFER_H
#define	_RINGBUFFER_H

#include	<iostream>
using namespace std;

class Ringbuffer {
public:
	Ringbuffer(unsigned int length);
	~Ringbuffer();

	unsigned int numlines();

	unsigned int canread();
	unsigned int canwrite();

	unsigned int read(char *buf, unsigned int len);
	unsigned int readtofd(int fd, unsigned int len);
	unsigned int readtofd(FILE *fd, unsigned int len);
	
	unsigned int peekline(char *buf, unsigned int len);
	unsigned int readline(char *buf, unsigned int len);

	unsigned int write(const char *buf, unsigned int len);
	unsigned int writefromfd(int fd, unsigned int len);
	unsigned int writefromfd(FILE *fd, unsigned int len);
private:
	unsigned int scannl();
	unsigned int length;
	unsigned int head;
	unsigned int tail;
	char *data;
	unsigned int nl;
};
/*
typedef struct {
	unsigned int head;
	unsigned int tail;
	char data[1024];
	unsigned int nl;
} ringbuffer;

void ringbuffer_init(ringbuffer *rb);

unsigned int ringbuffer_canread(ringbuffer *rb);
unsigned int ringbuffer_canwrite(ringbuffer *rb);

void ringbuffer_status(ringbuffer *rb);
void ringbuffer_scannl(ringbuffer *rb);

unsigned int ringbuffer_read(ringbuffer *rb, char *buffer, unsigned int maxchars);
unsigned int ringbuffer_readtofd(ringbuffer *rb, int fd);

unsigned int ringbuffer_peekline(ringbuffer *rb, char *linebuffer, unsigned int maxchars);
unsigned int ringbuffer_readline(ringbuffer *rb, char *linebuffer, unsigned int maxchars);

unsigned int ringbuffer_write(ringbuffer *rb, char *buffer, unsigned int maxchars);
unsigned int ringbuffer_writefromfd(ringbuffer *rb, int fd, unsigned int nchars);
unsigned int ringbuffer_writefromsock(ringbuffer *rb, int fd, unsigned int nchars);
*/
#endif	/* _RINGBUFFER_H */
