const std = @import("std");

test "spng load file" {
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
