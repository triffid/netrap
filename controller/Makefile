PROJECT=netrap-controller

SRC=$(PROJECT).c array.c ringbuffer.c

OBJ=$(patsubst %.c,%.o,$(SRC))

CFLAGS=-std=gnu99 -O2 -fdata-sections -ffunction-sections -Wall
LDFLAGS=-Wl,--as-needed -Wl,--gc-sections

.PHONY: all clean

all: $(PROJECT)

$(PROJECT): $(PROJECT).elf
	cp $< $@

clean:
	rm -r $(OBJ) $(PROJECT).elf $(PROJECT)

%.elf: $(OBJ)
	gcc $(LDFLAGS) -o $@ $^

%.o: %.c Makefile
	gcc -c $(CFLAGS) -o $@ $<
