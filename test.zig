const std = @import("std");

test "spng decode" {
    const c = @cImport({
        @cInclude("spng.h");
    });

    const image_data = @embedFile("test-images/orange.png");

    const ctx = c.spng_ctx_new(0) orelse return error.FailedToCreateContext;
    defer c.spng_ctx_free(ctx);
    if (c.spng_set_png_buffer(ctx, image_data.ptr, image_data.len) != 0) {
        return error.FailedToSetBuffer;
    }

    var size: usize = undefined;
    if (c.spng_decoded_image_size(ctx, c.SPNG_FMT_RGBA8, &size) != 0) {
        return error.FailedToGetSize;
    }
    const pixels = try std.testing.allocator.alloc(u8, size);
    defer std.testing.allocator.free(pixels);
    if (c.spng_decode_image(ctx, pixels.ptr, pixels.len, c.SPNG_FMT_RGBA8, c.SPNG_DECODE_TRNS) != 0) {
        return error.FailedToDecode;
    }
}

test "spng encode" {
    const c = @cImport({
        @cInclude("spng.h");
    });

    const image_data = @embedFile("test-images/orange.png");

    const ctx = c.spng_ctx_new(0) orelse return error.FailedToCreateContext;
    defer c.spng_ctx_free(ctx);
    if (c.spng_set_png_buffer(ctx, image_data.ptr, image_data.len) != 0) {
        return error.FailedToSetBuffer;
    }

    var size: usize = undefined;
    if (c.spng_decoded_image_size(ctx, c.SPNG_FMT_RGBA8, &size) != 0) {
        return error.FailedToGetSize;
    }
    const pixels = try std.testing.allocator.alloc(u8, size);
    defer std.testing.allocator.free(pixels);
    if (c.spng_decode_image(ctx, pixels.ptr, pixels.len, c.SPNG_FMT_RGBA8, c.SPNG_DECODE_TRNS) != 0) {
        return error.FailedToDecode;
    }

    const encode_ctx = c.spng_ctx_new(c.SPNG_CTX_ENCODER) orelse return error.FailedToCreateEncodeContext;
    defer c.spng_ctx_free(encode_ctx);

    var ihdr: c.struct_spng_ihdr = undefined;
    if (c.spng_get_ihdr(ctx, &ihdr) != 0) {
        return error.FailedToGetIHDR;
    }

    ihdr.color_type = c.SPNG_COLOR_TYPE_TRUECOLOR_ALPHA;
    ihdr.bit_depth = 8;

    if (c.spng_set_ihdr(encode_ctx, &ihdr) != 0) {
        return error.FailedToSetIHDR;
    }

    if (c.spng_set_option(encode_ctx, c.SPNG_ENCODE_TO_BUFFER, 1) != 0) {
        return error.FailedToSetOption;
    }

    if (c.spng_encode_image(encode_ctx, pixels.ptr, pixels.len, c.SPNG_FMT_PNG, c.SPNG_ENCODE_FINALIZE) != 0) {
        return error.FailedToEncode;
    }

    var out_len: usize = 0;
    var error_code: c_int = 0;
    const out_buffer = c.spng_get_png_buffer(encode_ctx, &out_len, &error_code);
    if (out_buffer == null or error_code != 0) {
        return error.FailedToGetBuffer;
    }

    // Verify that we have some output
    try std.testing.expect(out_len > 0);
}

test "tiff decode" {
    const c = @cImport({
        @cInclude("tiffio.h");
    });

    const image_path = "test-images/orange.tiff";
    const tif = c.TIFFOpen(image_path, "r") orelse return error.FailedToOpenTIFF;
    defer _ = c.TIFFClose(tif);

    var width: u32 = 0;
    var height: u32 = 0;
    _ = c.TIFFGetField(tif, c.TIFFTAG_IMAGEWIDTH, &width);
    _ = c.TIFFGetField(tif, c.TIFFTAG_IMAGELENGTH, &height);

    const pixels = try std.testing.allocator.alloc(u32, @as(usize, width) * @as(usize, height));
    defer std.testing.allocator.free(pixels);

    if (c.TIFFReadRGBAImage(tif, width, height, pixels.ptr, 0) == 0) {
        return error.FailedToDecode;
    }

    // Verify that we have some pixels
    try std.testing.expect(pixels.len > 0);
}

test "tiff encode" {
    const spng_c = @cImport({
        @cInclude("spng.h");
    });
    const tiff_c = @cImport({
        @cInclude("tiffio.h");
    });

    const image_data = @embedFile("test-images/orange.png");

    const ctx = spng_c.spng_ctx_new(0) orelse return error.FailedToCreateContext;
    defer spng_c.spng_ctx_free(ctx);
    if (spng_c.spng_set_png_buffer(ctx, image_data.ptr, image_data.len) != 0) {
        return error.FailedToSetBuffer;
    }

    var size: usize = undefined;
    if (spng_c.spng_decoded_image_size(ctx, spng_c.SPNG_FMT_RGBA8, &size) != 0) {
        return error.FailedToGetSize;
    }
    const pixels = try std.testing.allocator.alloc(u8, size);
    defer std.testing.allocator.free(pixels);
    if (spng_c.spng_decode_image(ctx, pixels.ptr, pixels.len, spng_c.SPNG_FMT_RGBA8, spng_c.SPNG_DECODE_TRNS) != 0) {
        return error.FailedToDecode;
    }

    var ihdr: spng_c.struct_spng_ihdr = undefined;
    if (spng_c.spng_get_ihdr(ctx, &ihdr) != 0) {
        return error.FailedToGetIHDR;
    }

    // Now encode to TIFF
    const output_path = "test-images/temp_output.tiff";
    const tif = tiff_c.TIFFOpen(output_path, "w") orelse return error.FailedToCreateTIFF;
    defer _ = tiff_c.TIFFClose(tif);
    defer std.fs.cwd().deleteFile(output_path) catch {};

    _ = tiff_c.TIFFSetField(tif, tiff_c.TIFFTAG_IMAGEWIDTH, @as(c_uint, ihdr.width));
    _ = tiff_c.TIFFSetField(tif, tiff_c.TIFFTAG_IMAGELENGTH, @as(c_uint, ihdr.height));
    _ = tiff_c.TIFFSetField(tif, tiff_c.TIFFTAG_SAMPLESPERPIXEL, @as(c_int, 4));
    _ = tiff_c.TIFFSetField(tif, tiff_c.TIFFTAG_BITSPERSAMPLE, @as(c_int, 8));
    _ = tiff_c.TIFFSetField(tif, tiff_c.TIFFTAG_ORIENTATION, @as(c_int, tiff_c.ORIENTATION_TOPLEFT));
    _ = tiff_c.TIFFSetField(tif, tiff_c.TIFFTAG_PLANARCONFIG, @as(c_int, tiff_c.PLANARCONFIG_CONTIG));
    _ = tiff_c.TIFFSetField(tif, tiff_c.TIFFTAG_PHOTOMETRIC, @as(c_int, tiff_c.PHOTOMETRIC_RGB));
    _ = tiff_c.TIFFSetField(tif, tiff_c.TIFFTAG_COMPRESSION, @as(c_int, tiff_c.COMPRESSION_NONE));
    _ = tiff_c.TIFFSetField(tif, tiff_c.TIFFTAG_ROWSPERSTRIP, @as(c_uint, ihdr.height));

    if (tiff_c.TIFFWriteEncodedStrip(tif, @as(u32, 0), pixels.ptr, @as(c_long, @intCast(pixels.len))) == -1) {
        return error.FailedToEncode;
    }

    const stat = try std.fs.cwd().statFile(output_path);
    try std.testing.expect(stat.size > 0);
}
