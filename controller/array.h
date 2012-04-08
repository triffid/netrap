#ifndef	_ARRAY_H
#define	_ARRAY_H

typedef struct {
	unsigned int length;
	char * name;
	void * data[];
} array;

array* array_init(void) __attribute__ ((__warn_unused_result__));
void array_free(array *a);

array* array_push(array *a, void *element) __attribute__ ((__warn_unused_result__));
void* array_pop(array *a);

array* array_unshift(array *a, void *element) __attribute__ ((__warn_unused_result__));
void* array_shift(array *a);

int array_indexof(array *a, void *element);

array* array_delete(array *a, void *element) __attribute__ ((__warn_unused_result__));

#endif	/* _ARRAY_H */
