#ifndef	_ARRAY_H
#define	_ARRAY_H

class Array {
	Array(void);
	~Array(void);
	unsigned int length(void);
	void push(void *element);
	void * pop(void);
	void unshift(void *element);
	void * shift(void);
	int indexof(void *element);
	void remove(void *element);
private:
	unsigned int len;
	void ** data;
};

#endif	/* _ARRAY_H */
