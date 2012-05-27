PROJECT=netrap-controller

CSRC=$(wildcard *.c)
CXXSRC= $(wildcard *.cpp)

OBJ=$(patsubst %.c,%.o,$(CSRC)) $(patsubst %.cpp,%.o,$(CXXSRC))

CFLAGS=-std=gnu99 -O2 -fdata-sections -ffunction-sections -Wall 
CXXFLAGS=-O2 -fdata-sections -ffunction-sections -Wall -std=gnu++0x
LDFLAGS=-Wl,--as-needed -Wl,--gc-sections

.PHONY: all clean
.PRECIOUS: %.o

all: $(PROJECT)

$(PROJECT): $(PROJECT).elf
	cp $< $@

clean:
	rm -rf $(OBJ) $(PROJECT).elf $(PROJECT) *~

%.elf: $(OBJ)
	g++ $(LDFLAGS) -o $@ $^

%.o: %.c Makefile
	gcc -c $(CFLAGS) -o $@ $<

%.o: %.cPP Makefile
	g++ -c $(CXXFLAGS) -o $@ $<
