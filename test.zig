const std = @import("std");

test "spng decode" {
    const c = @cImport({
        @cInclude("spng.h");
    });

    const image_path = "test-images/orange.png";
    const file = try std.fs.cwd().openFile(image_path, .{});
    defer file.close();
    const image_data = try file.readToEndAlloc(std.testing.allocator, std.math.maxInt(u64));
    defer std.testing.allocator.free(image_data);

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

    const image_path = "test-images/orange.png";
    const file = try std.fs.cwd().openFile(image_path, .{});
    defer file.close();
    const image_data = try file.readToEndAlloc(std.testing.allocator, std.math.maxInt(u64));
    defer std.testing.allocator.free(image_data);

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
