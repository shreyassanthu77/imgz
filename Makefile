CC=gcc
CFLAGS=$(shell cat compile_flags.txt)
LIBS=-lspng -ljpeg-turbo -ltiff -lwebp -lz -lm

test: src/test.c
	$(CC) $(CFLAGS) -o test src/test.c $(LIBS)
	./test
	rm test
