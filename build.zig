const std = @import("std");
const Spng = @import("formats/spng.zig");
const JpegTurbo = @import("formats/jpeg-turbo.zig");
const Tiff = @import("formats/tiff.zig");
const Webp = @import("formats/webp.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const enable_spng = b.option(bool, "spng", "libspng: Enable") orelse true;

    const enable_jpeg_turbo = b.option(bool, "jpeg_turbo", "libjpeg-turbo: Enable") orelse true;
    const jpeg_turbo_arith_enc = b.option(bool, "jpeg_turbo_arith_enc", "libjpeg-turbo: Enable arithmetic encoding") orelse true;
    const jpeg_turbo_arith_dec = b.option(bool, "jpeg_turbo_arith_dec", "libjpeg-turbo: Enable arithmetic decoding") orelse true;
    const jpeg_turbo_simd = b.option(bool, "jpeg_turbo_simd", "libjpeg-turbo: Enable SIMD extensions") orelse true;

    const enable_tiff = b.option(bool, "tiff", "libtiff: Enable") orelse true;
    const tiff_has_liblzma = b.option(bool, "tiff_has_liblzma", "libtiff: Enable liblzma support") orelse false;
    const tiff_use_system_liblzma = b.option(bool, "tiff_use_system_liblzma", "libtiff: Use system liblzma") orelse false;
    const tiff_has_libzstd = b.option(bool, "tiff_has_libzstd", "libtiff: Enable libzstd support") orelse false;
    const tiff_use_system_libzstd = b.option(bool, "tiff_use_system_libzstd", "libtiff: Use system libzstd") orelse false;
    const tiff_has_liblerc = b.option(bool, "tiff_has_liblerc", "libtiff: Enable liblerc support") orelse false;
    const tiff_use_system_liblerc = b.option(bool, "tiff_use_system_liblerc", "libtiff: Use system liblerc") orelse false;

    const enable_webp = b.option(bool, "webp", "libwebp: Enable") orelse true;
    const webp_encoding = b.option(bool, "webp_encoding", "libwebp: Enable encoding") orelse true;
    const webp_mux = b.option(bool, "webp_mux", "libwebp: Enable mux support") orelse true;
    const webp_threading = b.option(bool, "webp_threading", "libwebp: Enable threading") orelse true;
    const webp_simd = b.option(bool, "webp_simd", "libwebp: Enable SIMD") orelse true;

    const imgz = try buildImgz(b, .{
        .target = target,
        .optimize = optimize,
        .spng = if (enable_spng) .{} else null,
        .jpeg_turbo = if (enable_jpeg_turbo) .{
            .arith_enc = jpeg_turbo_arith_enc,
            .arith_dec = jpeg_turbo_arith_dec,
            .simd = jpeg_turbo_simd,
        } else null,
        .tiff = if (enable_tiff) .{
            .has_liblzma = tiff_has_liblzma,
            .use_system_liblzma = tiff_use_system_liblzma,
            .has_libzstd = tiff_has_libzstd,
            .use_system_libzstd = tiff_use_system_libzstd,
            .has_liblerc = tiff_has_liblerc,
            .use_system_liblerc = tiff_use_system_liblerc,
        } else null,
        .webp = if (enable_webp) .{
            .enable_encoding = webp_encoding,
            .enable_mux = webp_mux,
            .enable_threading = webp_threading,
            .enable_simd = webp_simd,
        } else null,
    });
    b.installArtifact(imgz);

    const test_step = b.step("test", "Run tests");
    const test_options = b.addOptions();
    test_options.addOption(bool, "spng_enabled", enable_spng);
    test_options.addOption(bool, "jpeg_turbo_enabled", enable_jpeg_turbo);
    test_options.addOption(bool, "tiff_enabled", enable_tiff);
    test_options.addOption(bool, "webp_enabled", enable_webp);
    test_options.addOption(bool, "webp_encoding_enabled", webp_encoding);

    const test_exe = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("test.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "opts", .module = test_options.createModule() },
            },
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
    webp: ?Webp.Options = null,
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

    const has_libjpeg = options.jpeg_turbo != null;
    const has_libwebp = options.webp != null;

    if (options.spng) |spng_options| {
        const spng = try Spng.get(b, target, optimize, spng_options);
        try imgz.installed_headers.appendSlice(spng.installed_headers.items);
        imgz.linkLibrary(spng);
    }

    const maybe_jpeg: ?*std.Build.Step.Compile = if (options.jpeg_turbo) |jpeg_turbo_options| blk: {
        const jpeg_turbo = try JpegTurbo.get(b, target, optimize, jpeg_turbo_options);
        try imgz.installed_headers.appendSlice(jpeg_turbo.installed_headers.items);
        imgz.linkLibrary(jpeg_turbo);
        break :blk jpeg_turbo;
    } else null;

    const maybe_webp: ?*std.Build.Step.Compile = if (options.webp) |webp_options| blk: {
        const webp = try Webp.get(b, target, optimize, webp_options, .{
            .has_libjpeg = options.jpeg_turbo != null,
        });
        try imgz.installed_headers.appendSlice(webp.installed_headers.items);
        imgz.linkLibrary(webp);
        break :blk webp;
    } else null;

    const maybe_tiff: ?*std.Build.Step.Compile = if (options.tiff) |tiff_options| blk: {
        const tiff = try Tiff.get(b, target, optimize, tiff_options, .{
            .has_libjpeg = options.jpeg_turbo != null,
            .has_libwebp = options.webp != null,
        });
        try imgz.installed_headers.appendSlice(tiff.installed_headers.items);
        imgz.linkLibrary(tiff);
        break :blk tiff;
    } else null;

    if (has_libjpeg) {
        const libjpeg = maybe_jpeg orelse @panic("unreachable");
        if (maybe_webp) |webp| {
            webp.linkLibrary(libjpeg);
        }
        if (maybe_tiff) |tiff| {
            tiff.linkLibrary(libjpeg);
        }
    }

    if (has_libwebp) {
        const libwebp = maybe_webp orelse @panic("unreachable");
        if (maybe_tiff) |tiff| {
            tiff.linkLibrary(libwebp);
        }
    }

    return imgz;
}
