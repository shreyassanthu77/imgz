const std = @import("std");
const Spng = @import("formats/spng.zig");
const JpegTurbo = @import("formats/jpeg-turbo.zig");
const Tiff = @import("formats/tiff.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const enable_spng = b.option(bool, "spng", "libspng: Enable") orelse true;

    const enable_jpeg_turbo = b.option(bool, "jpeg_turbo", "libjpeg-turbo: Enable") orelse true;
    const jpeg_turbo_pic = b.option(bool, "jpeg_turbo_pic", "libjpeg-turbo: Enable position independent code") orelse true;
    const jpeg_turbo_arith_enc = b.option(bool, "jpeg_turbo_arith_enc", "libjpeg-turbo: Enable arithmetic encoding") orelse true;
    const jpeg_turbo_arith_dec = b.option(bool, "jpeg_turbo_arith_dec", "libjpeg-turbo: Enable arithmetic decoding") orelse true;
    const jpeg_turbo_simd = b.option(bool, "jpeg_turbo_simd", "libjpeg-turbo: Enable SIMD extensions") orelse true;

    const enable_tiff = b.option(bool, "tiff", "libtiff: Enable") orelse true;
    const tiff_has_liblzma = b.option(bool, "tiff_has_liblzma", "libtiff: Enable liblzma support") orelse false;
    const tiff_use_system_liblzma = b.option(bool, "tiff_use_system_liblzma", "libtiff: Use system liblzma") orelse false;
    const tiff_has_libwebp = b.option(bool, "tiff_has_libwebp", "libtiff: Enable libwebp support") orelse false;
    const tiff_use_system_libwebp = b.option(bool, "tiff_use_system_libwebp", "libtiff: Use system libwebp") orelse false;
    const tiff_has_libzstd = b.option(bool, "tiff_has_libzstd", "libtiff: Enable libzstd support") orelse false;
    const tiff_use_system_libzstd = b.option(bool, "tiff_use_system_libzstd", "libtiff: Use system libzstd") orelse false;
    const tiff_has_liblerc = b.option(bool, "tiff_has_liblerc", "libtiff: Enable liblerc support") orelse false;
    const tiff_use_system_liblerc = b.option(bool, "tiff_use_system_liblerc", "libtiff: Use system liblerc") orelse false;

    const imgz = try buildImgz(b, .{
        .target = target,
        .optimize = optimize,
        .spng = if (enable_spng) .{} else null,
        .jpeg_turbo = if (enable_jpeg_turbo) .{
            .pic = jpeg_turbo_pic,
            .arith_enc = jpeg_turbo_arith_enc,
            .arith_dec = jpeg_turbo_arith_dec,
            .simd = jpeg_turbo_simd,
        } else null,
        .tiff = if (enable_tiff) .{
            .has_liblzma = tiff_has_liblzma,
            .use_system_liblzma = tiff_use_system_liblzma,
            .has_libwebp = tiff_has_libwebp,
            .use_system_libwebp = tiff_use_system_libwebp,
            .has_libzstd = tiff_has_libzstd,
            .use_system_libzstd = tiff_use_system_libzstd,
            .has_liblerc = tiff_has_liblerc,
            .use_system_liblerc = tiff_use_system_liblerc,
        } else null,
    });
    b.installArtifact(imgz);

    const test_step = b.step("test", "Run tests");
    const test_exe = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_exe.linkLibrary(imgz);
    const run_test_exe = b.addRunArtifact(test_exe);
    test_step.dependOn(&run_test_exe.step);
}

pub const Options = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    jpeg_turbo: ?JpegTurbo.Options = null,
    spng: ?Spng.Options = null,
    tiff: ?Tiff.Options = null,
};

pub fn get(b: *std.Build, options: Options) !*std.Build.Step.Compile {
    const target = options.target;
    const optimize = options.optimize;

    const self = b.dependencyFromBuildZig(@This(), .{
        .target = target,
        .optimize = optimize,
    });
    return buildImgz(self.builder, options);
}

fn buildImgz(b: *std.Build, options: Options) !*std.Build.Step.Compile {
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

    var maybe_libjpeg: ?*std.Build.Step.Compile = null;
    if (options.jpeg_turbo) |jpeg_turbo_options| {
        const jpeg_turbo = try JpegTurbo.get(b, target, optimize, jpeg_turbo_options);
        try imgz.installed_headers.appendSlice(jpeg_turbo.installed_headers.items);
        imgz.linkLibrary(jpeg_turbo);
        maybe_libjpeg = jpeg_turbo;
    }

    if (options.spng) |spng_options| {
        const spng = try Spng.get(b, target, optimize, spng_options);
        try imgz.installed_headers.appendSlice(spng.installed_headers.items);
        imgz.linkLibrary(spng);
    }

    if (options.tiff) |tiff_options| {
        const tiff = try Tiff.get(b, target, optimize, tiff_options, .{
            .libjpeg = maybe_libjpeg,
        });
        try imgz.installed_headers.appendSlice(tiff.installed_headers.items);
        imgz.linkLibrary(tiff);
    }

    return imgz;
}
