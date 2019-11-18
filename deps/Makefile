OPT = -g -O3
CCFLAGS+= -Wall -fpic $(OPT)

all: libaffinity.so

libaffinity.so: affinity.o
		$(CC) $(CXXFLAGS) -shared $^ -o $@

%.o: %.c
	$(CC) $(CCFLAGS) -c -o $@ $<
