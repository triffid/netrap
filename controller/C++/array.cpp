#include	"array.hpp"

#include	<stdlib.h>
#include	<string.h>

Array::Array() {
	len = 0;
	data = NULL;
}

Array::~Array() {
	if (data)
		free(data);
}

unsigned int Array::length() {
	return len;
}

void Array::push(void *element) {
	len++;
	if (data == NULL)
		data = (void **) malloc(sizeof(void *) * len);
	else
		data = (void **) realloc(data, sizeof(void *) * len);

	data[len - 1] = element;
}

void * Array::pop() {
	if (len) {
		len--;
		void *r = data[len];
		data = (void **) realloc(data, sizeof(void *) * len);
		return r;
	}
	return NULL;
}

void *Array::shift() {
	if (len) {
		len--;
		void *r = data[0];
		data = (void **) memmove(data, &data[1], sizeof(void *) * len);
		data = (void **) realloc(data, sizeof(void *) * len);
		return r;
	}
	return NULL;
}

void Array::unshift(void *element) {
	len++;
	if (data == NULL)
		data = (void **) malloc(sizeof(void *) * len);
	else
		data = (void **) realloc(data, sizeof(void *) * len);
	data = (void **) memmove(&data[1], data, sizeof(void *) * (len - 1));
	data[0] = element;
}

int Array::indexof(void *element) {
	for (unsigned int i = 0; i < len; i++) {
		if (data[i] == element)
			return i;
	}
	return -1;
}

void Array::remove(void *element) {
	int i = indexof(element);
	if (i >= 0) {
		len--;
		if (len > ((unsigned int) i))
			data = (void **) memmove(&data[i], &data[(i + 1)], (len - i) * sizeof(void *));
		data = (void **) realloc(data, sizeof(void *) * len);
	}
}
