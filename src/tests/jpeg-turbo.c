#include "shared.h"
#include <stdio.h>
#include <stdlib.h>

#include <jpeglib.h>
#include <turbojpeg.h>

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
  unsigned char *row_ptr = rgb_pixels.data;
  while (cinfo.next_scanline < cinfo.image_height) {
    JSAMPROW row_pointers[1] = {row_ptr};
    jpeg_write_scanlines(&cinfo, row_pointers, 1);
    row_ptr += row_stride;
  }
  jpeg_finish_compress(&cinfo);
  jpeg_destroy_compress(&cinfo);

  free(rgb_pixels.data);
  free(jpeg_buffer);
  return jpeg_size > 0;
}

bool test_jpeg_decode() {
  auto jpeg_data = read_file("src/tests/test-images/orange.jpeg");
  if (!jpeg_data.data)
    return false;

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

  size_t decoded_size =
      dinfo.output_width * dinfo.output_height * dinfo.num_components;
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

bool test_turbojpeg_compress() {
  const int width = 16;
  const int height = 16;
  const int quality = 90;

  auto rgb_pixels = generate_gradient_pixels(width, height, false);

  tjhandle handle = tjInitCompress();
  if (!handle) {
    free(rgb_pixels.data);
    return false;
  }

  unsigned char *jpeg_buf = NULL;
  unsigned long jpeg_size = 0;

  int result = tjCompress2(handle, rgb_pixels.data, width,
                           0, // pitch
                           height, TJPF_RGB, &jpeg_buf, &jpeg_size, TJSAMP_444,
                           quality, TJFLAG_ACCURATEDCT);

  free(rgb_pixels.data);
  tjDestroy(handle);

  if (result != 0 || jpeg_size == 0 || jpeg_buf == NULL) {
    if (jpeg_buf)
      tjFree(jpeg_buf);
    return false;
  }

  tjFree(jpeg_buf);
  return true;
}

bool test_turbojpeg_decompress() {
  auto jpeg_data = read_file("src/tests/test-images/orange.jpeg");
  if (!jpeg_data.data)
    return false;

  tjhandle handle = tjInitDecompress();
  if (!handle) {
    free(jpeg_data.data);
    return false;
  }

  int width, height, subsamp, colorspace;
  int result = tjDecompressHeader3(handle, jpeg_data.data, jpeg_data.len,
                                   &width, &height, &subsamp, &colorspace);

  if (result != 0 || width <= 0 || height <= 0) {
    free(jpeg_data.data);
    tjDestroy(handle);
    return false;
  }

  size_t pixel_size = width * height * 3; // RGB
  uint8_t *rgb_pixels = malloc(pixel_size);
  if (!rgb_pixels) {
    free(jpeg_data.data);
    tjDestroy(handle);
    return false;
  }

  int decompress_result =
      tjDecompress2(handle, jpeg_data.data, jpeg_data.len, rgb_pixels, width,
                    0, // pitch
                    height, TJPF_RGB, TJFLAG_ACCURATEDCT);

  free(rgb_pixels);
  free(jpeg_data.data);
  tjDestroy(handle);

  return decompress_result == 0;
}

bool test_turbojpeg_roundtrip() {
  const int width = 32;
  const int height = 32;
  const int quality = 85;

  auto original_pixels = generate_gradient_pixels(width, height, false);

  // Compress
  tjhandle compress_handle = tjInitCompress();
  if (!compress_handle) {
    free(original_pixels.data);
    return false;
  }

  unsigned char *jpeg_buf = NULL;
  unsigned long jpeg_size = 0;

  int compress_result = tjCompress2(
      compress_handle, original_pixels.data, width, 0, height, TJPF_RGB,
      &jpeg_buf, &jpeg_size, TJSAMP_444, quality, TJFLAG_ACCURATEDCT);

  free(original_pixels.data);
  tjDestroy(compress_handle);

  if (compress_result != 0 || jpeg_size == 0 || jpeg_buf == NULL) {
    if (jpeg_buf)
      tjFree(jpeg_buf);
    return false;
  }

  // Decompress
  tjhandle decompress_handle = tjInitDecompress();
  if (!decompress_handle) {
    tjFree(jpeg_buf);
    return false;
  }

  size_t decompressed_size = width * height * 3;
  uint8_t *decompressed_pixels = malloc(decompressed_size);
  if (!decompressed_pixels) {
    tjFree(jpeg_buf);
    tjDestroy(decompress_handle);
    return false;
  }

  int decompress_result =
      tjDecompress2(decompress_handle, jpeg_buf, jpeg_size, decompressed_pixels,
                    width, 0, height, TJPF_RGB, TJFLAG_ACCURATEDCT);

  tjFree(jpeg_buf);
  tjDestroy(decompress_handle);

  if (decompress_result != 0) {
    free(decompressed_pixels);
    return false;
  }

  // Simple check that we got some data
  bool success = decompressed_size > 0;
  free(decompressed_pixels);
  return success;
}

int main() {
  if (!test_jpeg_encode()) {
    printf("jpeg_encode failed\n");
    return 1;
  }

  if (!test_jpeg_decode()) {
    printf("jpeg_decode failed\n");
    return 1;
  }

  if (!test_turbojpeg_compress()) {
    printf("turbojpeg_compress failed\n");
    return 1;
  }

  if (!test_turbojpeg_decompress()) {
    printf("turbojpeg_decompress failed\n");
    return 1;
  }

  if (!test_turbojpeg_roundtrip()) {
    printf("turbojpeg_roundtrip failed\n");
    return 1;
  }

  return 0;
}
