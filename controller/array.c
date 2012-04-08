#include	"array.h"

#include	<stdlib.h>
#include	<stdio.h>
#include	<errno.h>
#include	<string.h>

array* array_init(void) {
	array * a = malloc(sizeof(array));
	if (a == NULL) {
		fprintf(stderr, "array_init: malloc failed: %s\n", strerror(errno));
		exit(1);
	}
	a->length = 0;
	return a;
}

void array_free(array *a) {
	free(a);
}

array* array_push(array *a, void *element) {
	//printf("push %s(%p): %p. %d->%d\n", a->name, a, element, a->length, a->length + 1);
	a->length++;
	a = realloc(a, sizeof(array) + (sizeof(void *) * a->length));
	if (a == NULL) {
		fprintf(stderr, "array_push: realloc failed: %s\n", strerror(errno));
		exit(1);
	}

	a->data[a->length - 1] = element;

	return a;
}

array* array_unshift(array *a, void *element) {
	//printf("push %s(%p): %p. %d->%d\n", a->name, a, element, a->length, a->length + 1);
	a->length++;
	a = realloc(a, sizeof(array) + (sizeof(void *) * a->length));
	if (a == NULL) {
		fprintf(stderr, "array_push: realloc failed: %s\n", strerror(errno));
		exit(1);
	}

	memmove(&a->data[1], &a->data[0], sizeof(void *) * a->length);

	a->data[0] = element;

	return a;
}

void* array_pop(array *a) {
	if (a->length) {
		void *r = a->data[(a->length - 1)];
		a->length--;
		a = realloc(a, sizeof(array) + sizeof(void *) * a->length);
		if (a == NULL) {
			fprintf(stderr, "array_pop: realloc failed: %s\n", strerror(errno));
			exit(1);
		}
		return r;
	}
	return NULL;
}

void* array_shift(array *a) {
	if (a->length) {
		void *r = a->data[0];
		a->length--;
		memmove(&a->data[0], &a->data[1], sizeof(void *) * a->length);
		a = realloc(a, sizeof(array) + sizeof(void *) * a->length);
		if (a == NULL) {
			fprintf(stderr, "array_shift: realloc failed: %s\n", strerror(errno));
			exit(1);
		}
		return r;
	}
	return NULL;
}

int array_indexof(array *a, void *element) {
	for (int i = 0; i < a->length; i++) {
		if (a->data[i] == element) {
			return i;
		}
	}
	return -1;
}

array* array_delete(array *a, void *element) {
	int i = array_indexof(a, element);
	if (i >= 0) {
		a->length--;
		if (a->length > i)
			memmove(&a->data[i], &a->data[(i + 1)], (a->length - i) * sizeof(void *));
		return a = realloc(a, sizeof(array) + sizeof(void *) * a->length);
	}
	return a;
}

