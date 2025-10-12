const std = @import("std");
const Spng = @import("src/formats/spng.zig");
const JpegTurbo = @import("src/formats/jpeg-turbo.zig");
const Tiff = @import("src/formats/tiff.zig");
const Webp = @import("src/formats/webp.zig");

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
            .root_source_file = b.path("src/test.zig"),
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

    const ci_step = b.step("ci", "Run tests on CI");
    const build_targets: []const std.Target.Query = &.{
        .{ .cpu_arch = .aarch64, .os_tag = .macos },
        .{ .cpu_arch = .aarch64, .os_tag = .linux },
        .{ .cpu_arch = .aarch64, .os_tag = .windows },
        .{ .cpu_arch = .x86_64, .os_tag = .macos },
        .{ .cpu_arch = .x86_64, .os_tag = .linux },
        .{ .cpu_arch = .x86_64, .os_tag = .windows },
        .{ .cpu_arch = .riscv64, .os_tag = .linux },
        .{ .cpu_arch = .riscv32, .os_tag = .linux },
    };
    for (build_targets) |target_query| {
        const t = b.resolveTargetQuery(target_query);
        const imgz_lib = try buildImgz(b, .{
            .target = t,
            .optimize = optimize,
            .jpeg_turbo = .{},
            .spng = .{},
            .tiff = .{},
            .webp = .{},
        });
        const out_dir = try target_query.zigTriple(b.allocator);
        const h_dir = try std.fs.path.join(b.allocator, &.{ out_dir, "include" });
        const imgz_output = b.addInstallArtifact(imgz_lib, .{
            .h_dir = .{
                .override = .{
                    .custom = h_dir,
                },
            },
            .dest_dir = .{
                .override = .{
                    .custom = out_dir,
                },
            },
        });
        ci_step.dependOn(&imgz_output.step);
    }
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
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const has_libjpeg = options.jpeg_turbo != null;
    const has_libwebp = options.webp != null;

    if (options.spng) |spng_options| {
        try Spng.get(b, target, optimize, imgz, spng_options);
    }

    if (options.jpeg_turbo) |jpeg_turbo_options| {
        try JpegTurbo.get(b, target, optimize, imgz, jpeg_turbo_options);
    }

    if (options.webp) |webp_options| {
        try Webp.get(b, target, optimize, imgz, webp_options, .{
            .has_libjpeg = has_libjpeg,
        });
    }

    if (options.tiff) |tiff_options| {
        try Tiff.get(b, target, optimize, imgz, tiff_options, .{
            .has_libjpeg = has_libjpeg,
            .has_libwebp = has_libwebp and options.webp.?.enable_encoding,
        });
    }

    return imgz;
}
