#include <spng.h>
#include <stdio.h>

#include <stddef.h>
#include <stdint.h>

typedef struct GradientPixels {
  uint8_t *pixels;
  size_t len;
} GradientPixels;

GradientPixels generate_gradient_pixels(size_t width, size_t height, bool rgba);

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

int main() {
  if (!test_spng_encode()) {
    printf("spng_encode failed\n");
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
