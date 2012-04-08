#ifndef	_ARRAY_H
#define	_ARRAY_H

typedef struct {
	unsigned int length;
	char * name;
	void * data[];
} array;

array* array_init(void);
array* array_push(array *a, void *element);
array* array_unshift(array *a, void *element);
void* array_pop(array *a);
void* array_shift(array *a);
int array_indexof(array *a, void *element);
array* array_delete(array *a, void *element);

#endif	/* _ARRAY_H */
