#include <spng.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <stddef.h>
#include <stdint.h>
#include <tiffio.h>
#include <jpeglib.h>
#include <webp/encode.h>
#include <webp/decode.h>

typedef struct GradientPixels {
  uint8_t *pixels;
  size_t len;
} GradientPixels;

typedef struct FileData {
  uint8_t *data;
  size_t len;
} FileData;

GradientPixels generate_gradient_pixels(size_t width, size_t height, bool rgba);
FileData read_file(const char *path);

bool test_spng_encode() {
  auto ctx = spng_ctx_new(SPNG_CTX_ENCODER);
  if (!ctx)
    return false;

  auto ihdr = (struct spng_ihdr){
      .width = 16,
      .height = 16,
      .bit_depth = 8,
      .color_type = SPNG_COLOR_TYPE_TRUECOLOR_ALPHA,
      .compression_method = 0,
      .filter_method = 0,
      .interlace_method = 0,
  };
  if (spng_set_ihdr(ctx, &ihdr) != 0) {
    return false;
  }

  if (spng_set_option(ctx, SPNG_ENCODE_TO_BUFFER, 1) != 0) {
    return false;
  }

  auto pixels = generate_gradient_pixels(16, 16, true);

  if (spng_encode_image(ctx, pixels.pixels, pixels.len, SPNG_FMT_PNG,
                        SPNG_ENCODE_FINALIZE) != 0) {
    return false;
  }

  size_t out_len = 0;
  int error_code = 0;
  auto out_buffer = spng_get_png_buffer(ctx, &out_len, &error_code);
  if (out_buffer == NULL || error_code != 0) {
    return false;
  }

  bool result = out_len > 0;

  free(pixels.pixels);
  spng_ctx_free(ctx);

  return result;
}

bool test_spng_decode() {
  auto image_data = read_file("src/test-images/orange.png");
  if (!image_data.data) return false;

  auto ctx = spng_ctx_new(0);
  if (!ctx) {
    free(image_data.data);
    return false;
  }

  if (spng_set_png_buffer(ctx, image_data.data, image_data.len) != 0) {
    free(image_data.data);
    spng_ctx_free(ctx);
    return false;
  }

  size_t size = 0;
  if (spng_decoded_image_size(ctx, SPNG_FMT_RGBA8, &size) != 0) {
    free(image_data.data);
    spng_ctx_free(ctx);
    return false;
  }

  uint8_t *pixels = malloc(size);
  if (!pixels) {
    free(image_data.data);
    spng_ctx_free(ctx);
    return false;
  }

  if (spng_decode_image(ctx, pixels, size, SPNG_FMT_RGBA8, SPNG_DECODE_TRNS) != 0) {
    free(pixels);
    free(image_data.data);
    spng_ctx_free(ctx);
    return false;
  }

  free(pixels);
  free(image_data.data);
  spng_ctx_free(ctx);
  return true;
}

bool test_tiff_encode() {
  const size_t width = 16;
  const size_t height = 16;

  auto pixels = generate_gradient_pixels(width, height, true);

  const char *output_path = "/tmp/temp_output.tiff";
  TIFF *tif = TIFFOpen(output_path, "w");
  if (!tif) {
    free(pixels.pixels);
    return false;
  }

  TIFFSetField(tif, TIFFTAG_IMAGEWIDTH, (uint32_t)width);
  TIFFSetField(tif, TIFFTAG_IMAGELENGTH, (uint32_t)height);
  TIFFSetField(tif, TIFFTAG_SAMPLESPERPIXEL, 4);
  TIFFSetField(tif, TIFFTAG_BITSPERSAMPLE, 8);
  TIFFSetField(tif, TIFFTAG_ORIENTATION, ORIENTATION_TOPLEFT);
  TIFFSetField(tif, TIFFTAG_PLANARCONFIG, PLANARCONFIG_CONTIG);
  TIFFSetField(tif, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_RGB);
  TIFFSetField(tif, TIFFTAG_COMPRESSION, COMPRESSION_NONE);
  TIFFSetField(tif, TIFFTAG_ROWSPERSTRIP, (uint32_t)height);

  if (TIFFWriteEncodedStrip(tif, 0, pixels.pixels, pixels.len) == -1) {
    free(pixels.pixels);
    TIFFClose(tif);
    return false;
  }

  free(pixels.pixels);
  TIFFClose(tif);

  // Check if file exists and has size > 0
  FILE *f = fopen(output_path, "rb");
  if (!f) return false;
  fseek(f, 0, SEEK_END);
  size_t size = ftell(f);
  fclose(f);
  remove(output_path);
  return size > 0;
}

bool test_tiff_decode() {
  const char *image_path = "src/test-images/orange.tiff";
  TIFF *tif = TIFFOpen(image_path, "r");
  if (!tif) return false;

  uint32_t width, height;
  TIFFGetField(tif, TIFFTAG_IMAGEWIDTH, &width);
  TIFFGetField(tif, TIFFTAG_IMAGELENGTH, &height);

  uint32_t *pixels = malloc(width * height * sizeof(uint32_t));
  if (!pixels) {
    TIFFClose(tif);
    return false;
  }

  if (TIFFReadRGBAImage(tif, width, height, pixels, 0) == 0) {
    free(pixels);
    TIFFClose(tif);
    return false;
  }

  free(pixels);
  TIFFClose(tif);
  return true;
}

bool test_jpeg_encode() {
  const size_t width = 16;
  const size_t height = 16;

  auto rgb_pixels = generate_gradient_pixels(width, height, false);

  unsigned char *jpeg_buffer = NULL;
  unsigned long jpeg_size = 0;
  struct jpeg_compress_struct cinfo;
  struct jpeg_error_mgr jerr;
  cinfo.err = jpeg_std_error(&jerr);
  jpeg_create_compress(&cinfo);
  jpeg_mem_dest(&cinfo, &jpeg_buffer, &jpeg_size);
  cinfo.image_width = width;
  cinfo.image_height = height;
  cinfo.input_components = 3;
  cinfo.in_color_space = JCS_RGB;
  jpeg_set_defaults(&cinfo);
  jpeg_set_quality(&cinfo, 90, TRUE);
  jpeg_start_compress(&cinfo, TRUE);

  const size_t row_stride = width * 3;
  unsigned char *row_ptr = rgb_pixels.pixels;
  while (cinfo.next_scanline < cinfo.image_height) {
    JSAMPROW row_pointers[1] = {row_ptr};
    jpeg_write_scanlines(&cinfo, row_pointers, 1);
    row_ptr += row_stride;
  }
  jpeg_finish_compress(&cinfo);
  jpeg_destroy_compress(&cinfo);

  free(rgb_pixels.pixels);
  free(jpeg_buffer);
  return jpeg_size > 0;
}

bool test_jpeg_decode() {
  auto jpeg_data = read_file("src/test-images/orange.jpeg");
  if (!jpeg_data.data) return false;

  struct jpeg_decompress_struct dinfo;
  struct jpeg_error_mgr djerr;
  dinfo.err = jpeg_std_error(&djerr);
  jpeg_create_decompress(&dinfo);
  jpeg_mem_src(&dinfo, jpeg_data.data, jpeg_data.len);
  if (jpeg_read_header(&dinfo, TRUE) != JPEG_HEADER_OK) {
    free(jpeg_data.data);
    jpeg_destroy_decompress(&dinfo);
    return false;
  }
  jpeg_start_decompress(&dinfo);

  size_t decoded_size = dinfo.output_width * dinfo.output_height * dinfo.num_components;
  uint8_t *decoded_rgb = malloc(decoded_size);
  if (!decoded_rgb) {
    free(jpeg_data.data);
    jpeg_destroy_decompress(&dinfo);
    return false;
  }

  uint8_t *decoded_row_ptr = decoded_rgb;
  size_t decoded_row_stride = dinfo.output_width * dinfo.num_components;
  while (dinfo.output_scanline < dinfo.output_height) {
    JSAMPROW decoded_row_pointers[1] = {decoded_row_ptr};
    jpeg_read_scanlines(&dinfo, decoded_row_pointers, 1);
    decoded_row_ptr += decoded_row_stride;
  }
  jpeg_finish_decompress(&dinfo);
  jpeg_destroy_decompress(&dinfo);

  free(decoded_rgb);
  free(jpeg_data.data);
  return decoded_size > 0;
}

bool test_webp_encode() {
  const int width = 16;
  const int height = 16;

  auto rgba_pixels = generate_gradient_pixels(width, height, true);

  uint8_t *webp_buffer = NULL;
  size_t webp_size = WebPEncodeRGBA(rgba_pixels.pixels, width, height, width * 4, 90, &webp_buffer);

  free(rgba_pixels.pixels);
  WebPFree(webp_buffer);
  return webp_size > 0;
}

bool test_webp_decode() {
  auto rgba_pixels = read_file("src/test-images/orange.webp");
  if (!rgba_pixels.data) return false;

  int decoded_width, decoded_height;
  uint8_t *decoded_pixels = WebPDecodeRGBA(rgba_pixels.data, rgba_pixels.len, &decoded_width, &decoded_height);

  free(rgba_pixels.data);
  if (!decoded_pixels) return false;
  WebPFree(decoded_pixels);
  return true;
}

int main() {
  if (!test_spng_encode()) {
    printf("spng_encode failed\n");
    return 1;
  }

  if (!test_spng_decode()) {
    printf("spng_decode failed\n");
    return 1;
  }

  if (!test_tiff_encode()) {
    printf("tiff_encode failed\n");
    return 1;
  }

  if (!test_tiff_decode()) {
    printf("tiff_decode failed\n");
    return 1;
  }

  if (!test_jpeg_encode()) {
    printf("jpeg_encode failed\n");
    return 1;
  }

  if (!test_jpeg_decode()) {
    printf("jpeg_decode failed\n");
    return 1;
  }

  if (!test_webp_encode()) {
    printf("webp_encode failed\n");
    return 1;
  }

  if (!test_webp_decode()) {
    printf("webp_decode failed\n");
    return 1;
  }

  return 0;
}

GradientPixels generate_gradient_pixels(size_t width, size_t height,
                                        bool rgba) {
  uint32_t components = 3;
  if (rgba)
    components = 4;
  uint8_t *pixels = calloc(width * height * components, sizeof(uint8_t));
  GradientPixels result = {pixels, width * height * components};
  for (size_t i = 0; i < width * height; i++) {
    uint8_t x = i % width;
    uint8_t y = i / width;
    uint8_t base = i * components;
    pixels[base + 0] = x * 255 / (width - 1);
    pixels[base + 1] = y * 255 / (height - 1);
    pixels[base + 2] = 0;
    if (rgba) {
      pixels[base + 3] = 255;
    }
  }
  return result;
}

FileData read_file(const char *path) {
  FILE *file = fopen(path, "rb");
  if (!file) {
    return (FileData){NULL, 0};
  }
  fseek(file, 0, SEEK_END);
  size_t len = ftell(file);
  fseek(file, 0, SEEK_SET);
  uint8_t *data = malloc(len);
  if (!data) {
    fclose(file);
    return (FileData){NULL, 0};
  }
  fread(data, 1, len, file);
  fclose(file);
  return (FileData){data, len};
}
