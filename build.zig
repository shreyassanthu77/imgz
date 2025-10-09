const std = @import("std");
const JpegTurbo = @import("formats/jpeg-turbo.zig");
const Spng = @import("formats/spng.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const enable_spng = b.option(bool, "spng", "libspng: Enable") orelse true;

    const enable_jpeg_turbo = b.option(bool, "jpeg_turbo", "libjpeg-turbo: Enable") orelse true;
    const jpeg_turbo_pic = b.option(bool, "jpeg_turbo_pic", "libjpeg-turbo: Enable position independent code") orelse true;
    const jpeg_turbo_arith_enc = b.option(bool, "jpeg_turbo_arith_enc", "libjpeg-turbo: Enable arithmetic encoding") orelse true;
    const jpeg_turbo_arith_dec = b.option(bool, "jpeg_turbo_arith_dec", "libjpeg-turbo: Enable arithmetic decoding") orelse true;
    const jpeg_turbo_simd = b.option(bool, "jpeg_turbo_simd", "libjpeg-turbo: Enable SIMD extensions") orelse true;

    const imgz = try get(b, .{
        .target = target,
        .optimize = optimize,
        .jpeg_turbo = if (enable_jpeg_turbo) .{
            .pic = jpeg_turbo_pic,
            .arith_enc = jpeg_turbo_arith_enc,
            .arith_dec = jpeg_turbo_arith_dec,
            .simd = jpeg_turbo_simd,
        } else null,
        .spng = if (enable_spng) .{} else null,
    });
    b.installArtifact(imgz);
}

pub const Options = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    jpeg_turbo: ?JpegTurbo.Options = null,
    spng: ?Spng.Options = null,
};

pub fn get(b: *std.Build, options: Options) !*std.Build.Step.Compile {
    const target = options.target;
    const optimize = options.optimize;

    const imgz = b.addLibrary(.{
        .name = "imgz",
        .root_module = b.createModule(.{
            .root_source_file = b.path("empty.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    if (options.jpeg_turbo) |jpeg_turbo_options| {
        const jpeg_turbo = try JpegTurbo.get(b, target, optimize, jpeg_turbo_options);
        try imgz.installed_headers.appendSlice(jpeg_turbo.installed_headers.items);
        imgz.linkLibrary(jpeg_turbo);
    }

    if (options.spng) |spng_options| {
        const spng = try Spng.get(b, target, optimize, spng_options);
        try imgz.installed_headers.appendSlice(spng.installed_headers.items);
        imgz.linkLibrary(spng);
    }

    return imgz;
}
