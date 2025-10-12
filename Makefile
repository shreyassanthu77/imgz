CC=gcc
CFLAGS=$(shell cat compile_flags.txt)

test: src/test.c
	zig build -Doptimize=ReleaseFast
	$(CC) -o test $(CFLAGS) src/test.c -limgz -lz -lm
	./test
	rm test
