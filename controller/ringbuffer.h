#ifndef	_RINGBUFFER_H
#define	_RINGBUFFER_H

#ifndef	BUFFER_SIZE
#define	BUFFER_SIZE 1024
#endif

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

#endif	/* _RINGBUFFER_H */
