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

test "jpeg-turbo decode" {
    const spng_c = @cImport({
        @cInclude("spng.h");
    });
    const jpeg_c = @cImport({
        @cInclude("stddef.h");
        @cInclude("stdio.h");
        @cInclude("jpeglib.h");
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
    const rgba_pixels = try std.testing.allocator.alloc(u8, size);
    defer std.testing.allocator.free(rgba_pixels);
    if (spng_c.spng_decode_image(ctx, rgba_pixels.ptr, rgba_pixels.len, spng_c.SPNG_FMT_RGBA8, spng_c.SPNG_DECODE_TRNS) != 0) {
        return error.FailedToDecode;
    }

    var ihdr: spng_c.struct_spng_ihdr = undefined;
    if (spng_c.spng_get_ihdr(ctx, &ihdr) != 0) {
        return error.FailedToGetIHDR;
    }

    // Convert RGBA to RGB
    const rgb_pixels = try std.testing.allocator.alloc(u8, ihdr.width * ihdr.height * 3);
    defer std.testing.allocator.free(rgb_pixels);
    for (0..ihdr.height) |y| {
        for (0..ihdr.width) |x| {
            const rgba_idx = (y * ihdr.width + x) * 4;
            const rgb_idx = (y * ihdr.width + x) * 3;
            rgb_pixels[rgb_idx] = rgba_pixels[rgba_idx];
            rgb_pixels[rgb_idx + 1] = rgba_pixels[rgba_idx + 1];
            rgb_pixels[rgb_idx + 2] = rgba_pixels[rgba_idx + 2];
        }
    }

    // Encode to JPEG in memory
    var jpeg_buffer: ?[*]u8 = null;
    var jpeg_size: c_ulong = 0;
    var cinfo: jpeg_c.jpeg_compress_struct = undefined;
    var jerr: jpeg_c.jpeg_error_mgr = undefined;
    cinfo.err = jpeg_c.jpeg_std_error(&jerr);
    jpeg_c.jpeg_create_compress(&cinfo);
    defer jpeg_c.jpeg_destroy_compress(&cinfo);
    jpeg_c.jpeg_mem_dest(&cinfo, &jpeg_buffer, &jpeg_size);
    cinfo.image_width = ihdr.width;
    cinfo.image_height = ihdr.height;
    cinfo.input_components = 3;
    cinfo.in_color_space = jpeg_c.JCS_RGB;
    jpeg_c.jpeg_set_defaults(&cinfo);
    jpeg_c.jpeg_set_quality(&cinfo, 90, 1);
    jpeg_c.jpeg_start_compress(&cinfo, 1);
    const row_stride = ihdr.width * 3;
    var row_ptr: [*]u8 = rgb_pixels.ptr;
    while (cinfo.next_scanline < cinfo.image_height) {
        var row_pointers: [1][*]u8 = .{row_ptr};
        _ = jpeg_c.jpeg_write_scanlines(&cinfo, @as([*c][*c]u8, @ptrCast(&row_pointers)), 1);
        row_ptr += row_stride;
    }
    jpeg_c.jpeg_finish_compress(&cinfo);
    try std.testing.expect(jpeg_size > 0);

    // Now decode the JPEG
    var dinfo: jpeg_c.jpeg_decompress_struct = undefined;
    var djerr: jpeg_c.jpeg_error_mgr = undefined;
    dinfo.err = jpeg_c.jpeg_std_error(&djerr);
    jpeg_c.jpeg_create_decompress(&dinfo);
    defer jpeg_c.jpeg_destroy_decompress(&dinfo);
    jpeg_c.jpeg_mem_src(&dinfo, jpeg_buffer, jpeg_size);
    if (jpeg_c.jpeg_read_header(&dinfo, 1) != jpeg_c.JPEG_HEADER_OK) {
        return error.FailedToReadHeader;
    }
    _ = jpeg_c.jpeg_start_decompress(&dinfo);
    const decoded_rgb = try std.testing.allocator.alloc(u8, @as(usize, dinfo.output_width) * @as(usize, dinfo.output_height) * @as(usize, @intCast(dinfo.num_components)));
    defer std.testing.allocator.free(decoded_rgb);
    var decoded_row_ptr: [*]u8 = decoded_rgb.ptr;
    const decoded_row_stride = @as(usize, dinfo.output_width) * @as(usize, @intCast(dinfo.num_components));
    while (dinfo.output_scanline < dinfo.output_height) {
        var decoded_row_pointers: [1][*]u8 = .{decoded_row_ptr};
        _ = jpeg_c.jpeg_read_scanlines(&dinfo, @as([*c][*c]u8, @ptrCast(&decoded_row_pointers)), 1);
        decoded_row_ptr += decoded_row_stride;
    }
    _ = jpeg_c.jpeg_finish_decompress(&dinfo);
    try std.testing.expect(decoded_rgb.len > 0);
}

test "jpeg-turbo encode" {
    const spng_c = @cImport({
        @cInclude("spng.h");
    });
    const jpeg_c = @cImport({
        @cInclude("stddef.h");
        @cInclude("stdio.h");
        @cInclude("jpeglib.h");
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
    const rgba_pixels = try std.testing.allocator.alloc(u8, size);
    defer std.testing.allocator.free(rgba_pixels);
    if (spng_c.spng_decode_image(ctx, rgba_pixels.ptr, rgba_pixels.len, spng_c.SPNG_FMT_RGBA8, spng_c.SPNG_DECODE_TRNS) != 0) {
        return error.FailedToDecode;
    }

    var ihdr: spng_c.struct_spng_ihdr = undefined;
    if (spng_c.spng_get_ihdr(ctx, &ihdr) != 0) {
        return error.FailedToGetIHDR;
    }

    // Convert RGBA to RGB
    const rgb_pixels = try std.testing.allocator.alloc(u8, ihdr.width * ihdr.height * 3);
    defer std.testing.allocator.free(rgb_pixels);
    for (0..ihdr.height) |y| {
        for (0..ihdr.width) |x| {
            const rgba_idx = (y * ihdr.width + x) * 4;
            const rgb_idx = (y * ihdr.width + x) * 3;
            rgb_pixels[rgb_idx] = rgba_pixels[rgba_idx];
            rgb_pixels[rgb_idx + 1] = rgba_pixels[rgba_idx + 1];
            rgb_pixels[rgb_idx + 2] = rgba_pixels[rgba_idx + 2];
        }
    }

    // Encode to JPEG in memory
    var jpeg_buffer: ?[*]u8 = null;
    var jpeg_size: c_ulong = 0;
    var cinfo: jpeg_c.jpeg_compress_struct = undefined;
    var jerr: jpeg_c.jpeg_error_mgr = undefined;
    cinfo.err = jpeg_c.jpeg_std_error(&jerr);
    jpeg_c.jpeg_create_compress(&cinfo);
    defer jpeg_c.jpeg_destroy_compress(&cinfo);
    jpeg_c.jpeg_mem_dest(&cinfo, &jpeg_buffer, &jpeg_size);
    cinfo.image_width = ihdr.width;
    cinfo.image_height = ihdr.height;
    cinfo.input_components = 3;
    cinfo.in_color_space = jpeg_c.JCS_RGB;
    jpeg_c.jpeg_set_defaults(&cinfo);
    jpeg_c.jpeg_set_quality(&cinfo, 90, 1);
    jpeg_c.jpeg_start_compress(&cinfo, 1);
    const row_stride = ihdr.width * 3;
    var row_ptr: [*]u8 = rgb_pixels.ptr;
    while (cinfo.next_scanline < cinfo.image_height) {
        var row_pointers: [1][*]u8 = .{row_ptr};
        _ = jpeg_c.jpeg_write_scanlines(&cinfo, @as([*c][*c]u8, @ptrCast(&row_pointers)), 1);
        row_ptr += row_stride;
    }
    jpeg_c.jpeg_finish_compress(&cinfo);
    try std.testing.expect(jpeg_size > 0);
}
