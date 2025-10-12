CC=gcc
CFLAGS=$(shell cat compile_flags.txt) src/tests/shared.c

test: test_spng test_jpeg-turbo test_tiff test_webp

test_spng: src/tests/spng.c
	$(CC) $(CFLAGS) -o test_spng src/tests/spng.c -lspng -lz -lm
	./test_spng
	rm test_spng

test_jpeg-turbo: src/tests/jpeg-turbo.c
	$(CC) $(CFLAGS) -o test_jpeg-turbo src/tests/jpeg-turbo.c -ljpeg-turbo
	./test_jpeg-turbo
	rm test_jpeg-turbo

test_tiff: src/tests/tiff.c
	$(CC) $(CFLAGS) -o test_tiff src/tests/tiff.c -ltiff -lz -lwebp -lm -ljpeg-turbo
	./test_tiff
	rm test_tiff

test_webp: src/tests/webp.c
	$(CC) $(CFLAGS) -o test_webp src/tests/webp.c -lwebp -lm
	./test_webp
	rm test_webp
