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

    const encode_ctx = c.spng_ctx_new(c.SPNG_CTX_ENCODER) orelse return error.FailedToCreateEncodeContext;
    defer c.spng_ctx_free(encode_ctx);

    var ihdr: c.struct_spng_ihdr = .{
        .width = 16,
        .height = 16,
        .bit_depth = 8,
        .color_type = c.SPNG_COLOR_TYPE_TRUECOLOR_ALPHA,
        .compression_method = 0,
        .filter_method = 0,
        .interlace_method = 0,
    };

    if (c.spng_set_ihdr(encode_ctx, &ihdr) != 0) {
        return error.FailedToSetIHDR;
    }

    if (c.spng_set_option(encode_ctx, c.SPNG_ENCODE_TO_BUFFER, 1) != 0) {
        return error.FailedToSetOption;
    }

    const pixels = try generateGradientPixels(std.testing.allocator, ihdr.width, ihdr.height, true);
    defer std.testing.allocator.free(pixels);

    if (c.spng_encode_image(encode_ctx, pixels.ptr, pixels.len, c.SPNG_FMT_PNG, c.SPNG_ENCODE_FINALIZE) != 0) {
        return error.FailedToEncode;
    }

    var out_len: usize = 0;
    var error_code: c_int = 0;
    const out_buffer = c.spng_get_png_buffer(encode_ctx, &out_len, &error_code);
    if (out_buffer == null or error_code != 0) {
        return error.FailedToGetBuffer;
    }

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
    const c = @cImport({
        @cInclude("tiffio.h");
    });

    const width: u32 = 16;
    const height: u32 = 16;

    const pixels = try generateGradientPixels(std.testing.allocator, width, height, true);
    defer std.testing.allocator.free(pixels);

    const output_path = "test-images/temp_output.tiff";
    const tif = c.TIFFOpen(output_path, "w") orelse return error.FailedToCreateTIFF;
    defer _ = c.TIFFClose(tif);
    defer std.fs.cwd().deleteFile(output_path) catch {};

    _ = c.TIFFSetField(tif, c.TIFFTAG_IMAGEWIDTH, @as(c_uint, width));
    _ = c.TIFFSetField(tif, c.TIFFTAG_IMAGELENGTH, @as(c_uint, height));
    _ = c.TIFFSetField(tif, c.TIFFTAG_SAMPLESPERPIXEL, @as(c_int, 4));
    _ = c.TIFFSetField(tif, c.TIFFTAG_BITSPERSAMPLE, @as(c_int, 8));
    _ = c.TIFFSetField(tif, c.TIFFTAG_ORIENTATION, @as(c_int, c.ORIENTATION_TOPLEFT));
    _ = c.TIFFSetField(tif, c.TIFFTAG_PLANARCONFIG, @as(c_int, c.PLANARCONFIG_CONTIG));
    _ = c.TIFFSetField(tif, c.TIFFTAG_PHOTOMETRIC, @as(c_int, c.PHOTOMETRIC_RGB));
    _ = c.TIFFSetField(tif, c.TIFFTAG_COMPRESSION, @as(c_int, c.COMPRESSION_NONE));
    _ = c.TIFFSetField(tif, c.TIFFTAG_ROWSPERSTRIP, @as(c_uint, height));

    if (c.TIFFWriteEncodedStrip(tif, @as(u32, 0), pixels.ptr, @as(c_long, @intCast(pixels.len))) == -1) {
        return error.FailedToEncode;
    }

    const stat = try std.fs.cwd().statFile(output_path);
    try std.testing.expect(stat.size > 0);
}

test "jpeg-turbo decode" {
    const jpeg_c = @cImport({
        @cInclude("stddef.h");
        @cInclude("stdio.h");
        @cInclude("jpeglib.h");
    });

    const jpeg_data = @embedFile("test-images/orange.jpeg");

    var dinfo: jpeg_c.jpeg_decompress_struct = undefined;
    var djerr: jpeg_c.jpeg_error_mgr = undefined;
    dinfo.err = jpeg_c.jpeg_std_error(&djerr);
    jpeg_c.jpeg_create_decompress(&dinfo);
    defer jpeg_c.jpeg_destroy_decompress(&dinfo);
    jpeg_c.jpeg_mem_src(&dinfo, jpeg_data.ptr, @as(c_ulong, @intCast(jpeg_data.len)));
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
    const jpeg_c = @cImport({
        @cInclude("stddef.h");
        @cInclude("stdio.h");
        @cInclude("jpeglib.h");
    });

    const width: u32 = 16;
    const height: u32 = 16;

    const rgb_pixels = try generateGradientPixels(std.testing.allocator, width, height, false);
    defer std.testing.allocator.free(rgb_pixels);

    // Encode to JPEG in memory
    var jpeg_buffer: ?[*]u8 = null;
    var jpeg_size: c_ulong = 0;
    var cinfo: jpeg_c.jpeg_compress_struct = undefined;
    var jerr: jpeg_c.jpeg_error_mgr = undefined;
    cinfo.err = jpeg_c.jpeg_std_error(&jerr);
    jpeg_c.jpeg_create_compress(&cinfo);
    defer jpeg_c.jpeg_destroy_compress(&cinfo);
    jpeg_c.jpeg_mem_dest(&cinfo, &jpeg_buffer, &jpeg_size);
    cinfo.image_width = width;
    cinfo.image_height = height;
    cinfo.input_components = 3;
    cinfo.in_color_space = jpeg_c.JCS_RGB;
    jpeg_c.jpeg_set_defaults(&cinfo);
    jpeg_c.jpeg_set_quality(&cinfo, 90, 1);
    jpeg_c.jpeg_start_compress(&cinfo, 1);
    const row_stride = width * 3;
    var row_ptr: [*]u8 = rgb_pixels.ptr;
    while (cinfo.next_scanline < cinfo.image_height) {
        var row_pointers: [1][*]u8 = .{row_ptr};
        _ = jpeg_c.jpeg_write_scanlines(&cinfo, @as([*c][*c]u8, @ptrCast(&row_pointers)), 1);
        row_ptr += row_stride;
    }
    jpeg_c.jpeg_finish_compress(&cinfo);
    try std.testing.expect(jpeg_size > 0);
}

fn generateGradientPixels(allocator: std.mem.Allocator, width: u32, height: u32, rgba: bool) ![]u8 {
    var components: usize = 3;
    if (rgba) components = 4;
    const pixels = try allocator.alloc(u8, @as(usize, width) * @as(usize, height) * components);
    const pixel_count = @as(usize, width) * @as(usize, height);
    var i: usize = 0;
    while (i < pixel_count) : (i += 1) {
        const x: u32 = @intCast(i % width);
        const y: u32 = @intCast(i / width);
        const base = i * components;
        pixels[base + 0] = @intCast((x * 255) / (width - 1));
        pixels[base + 1] = @intCast((y * 255) / (height - 1));
        pixels[base + 2] = 0;
        if (rgba) {
            pixels[base + 3] = 255;
        }
    }
    return pixels;
}
