const std = @import("std");
pub const RequiredLibrary = @import("src/formats/shared.zig").RequiredLibrary;
pub const Spng = @import("src/formats/spng.zig");
pub const JpegTurbo = @import("src/formats/jpeg-turbo.zig");
pub const Tiff = @import("src/formats/tiff.zig");
pub const Webp = @import("src/formats/webp.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const enable_spng = b.option(bool, "spng", "libspng: Enable") orelse true;

    const enable_jpeg_turbo = b.option(bool, "jpeg_turbo", "libjpeg-turbo: Enable") orelse true;
    const jpeg_turbo_arith_enc = b.option(bool, "jpeg_turbo_arith_enc", "libjpeg-turbo: Enable arithmetic encoding") orelse true;
    const jpeg_turbo_arith_dec = b.option(bool, "jpeg_turbo_arith_dec", "libjpeg-turbo: Enable arithmetic decoding") orelse true;
    const jpeg_turbo_simd = b.option(bool, "jpeg_turbo_simd", "libjpeg-turbo: Enable SIMD extensions") orelse true;

    const enable_tiff = b.option(bool, "tiff", "libtiff: Enable") orelse true;

    const enable_webp = b.option(bool, "webp", "libwebp: Enable") orelse true;
    const webp_encoding = b.option(bool, "webp_encoding", "libwebp: Enable encoding") orelse true;
    const webp_mux = b.option(bool, "webp_mux", "libwebp: Enable mux support") orelse true;
    const webp_threading = b.option(bool, "webp_threading", "libwebp: Enable threading") orelse true;
    const webp_simd = b.option(bool, "webp_simd", "libwebp: Enable SIMD") orelse true;

    const libz = b.option(RequiredLibrary, "libz", "Choose which version of libz to use") orelse .bundled;
    const libsharpyuv = b.option(RequiredLibrary, "libsharpyuv", "Choose which version of libsharpyuv to use") orelse .bundled;
    const liblerc = b.option(bool, "liblerc", "Enable lerc support in libtiff. If enabled, system must have liblerc headers during build and the library during linking") orelse false;
    const liblzma = b.option(bool, "liblzma", "Enable lzma support in libtiff. If enabled, system must have liblzma headers during build and the library during linking") orelse false;
    const libzstd = b.option(bool, "libzstd", "Enable zstd support in libtiff. If enabled, system must have libzstd headers during build and the library during linking") orelse false;

    const options = Options{
        .target = target,
        .optimize = optimize,
        .spng = if (enable_spng) Spng.Options{} else null,
        .jpeg_turbo = if (enable_jpeg_turbo) JpegTurbo.Options{
            .arith_enc = jpeg_turbo_arith_enc,
            .arith_dec = jpeg_turbo_arith_dec,
            .simd = jpeg_turbo_simd,
        } else null,
        .tiff = if (enable_tiff) Tiff.Options{} else null,
        .webp = if (enable_webp) Webp.Options{
            .enable_encoding = webp_encoding,
            .enable_mux = webp_mux,
            .enable_threading = webp_threading,
            .enable_simd = webp_simd,
        } else null,
        .libz = libz,
        .libsharpyuv = libsharpyuv,
        .liblerc = if (liblerc) .custom else .disabled,
        .liblzma = if (liblzma) .custom else .disabled,
        .libzstd = if (libzstd) .custom else .disabled,
    };
    try buildLibs(b, options, .{}, b.getInstallStep());

    const zig_tests: []const struct { path: []const u8, enabled: bool } = &.{
        .{ .path = "src/tests/spng.zig", .enabled = enable_spng },
        .{ .path = "src/tests/jpeg-turbo.zig", .enabled = enable_jpeg_turbo },
        .{ .path = "src/tests/tiff.zig", .enabled = enable_tiff },
        .{ .path = "src/tests/webp.zig", .enabled = enable_webp },
    };
    const test_step = b.step("test", "Run tests");
    for (zig_tests) |t| if (t.enabled) {
        const test_exe = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(t.path),
                .target = target,
                .optimize = optimize,
            }),
        });
        try addToModule1(b, test_exe.root_module, options);
        const run_test_exe = b.addRunArtifact(test_exe);
        test_step.dependOn(&run_test_exe.step);
    };

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
        var options_copy = options;
        options_copy.target = t;

        const out_dir = try target_query.zigTriple(b.allocator);
        const h_dir = try std.fs.path.join(b.allocator, &.{ out_dir, "include" });
        try buildLibs(b, options_copy, .{
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
        }, ci_step);
    }
}

pub const Options = struct {
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    jpeg_turbo: ?JpegTurbo.Options = .{},
    spng: ?Spng.Options = .{},
    tiff: ?Tiff.Options = .{},
    webp: ?Webp.Options = .{},

    /// Required for spng, Optional for tiff and webp
    libz: RequiredLibrary = .bundled,
    /// Required for webp
    libsharpyuv: RequiredLibrary = .bundled,
    /// Required for tiff
    liblerc: RequiredLibrary = .disabled,
    /// Required for tiff
    liblzma: RequiredLibrary = .disabled,
    /// Required for tiff
    libzstd: RequiredLibrary = .disabled,
};

pub fn addToModule(b: *std.Build, mod: *std.Build.Module, options: Options) !void {
    const self = b.dependencyFromBuildZig(@This(), .{
        .target = options.target,
        .optimize = options.optimize,
    });
    try addToModule1(self.builder, mod, options);
}

fn addToModule1(b: *std.Build, mod: *std.Build.Module, options: Options) !void {
    const target = options.target;
    const optimize = options.optimize;

    const has_libjpeg = options.jpeg_turbo != null;
    const has_libwebp = options.webp != null;

    if (options.spng) |spng_options| {
        const spng = try Spng.get(b, target, optimize, spng_options, .{
            .libz = options.libz,
        });
        mod.linkLibrary(spng);
    }

    if (options.jpeg_turbo) |jpeg_turbo_options| {
        const jpeg = try JpegTurbo.get(b, target, optimize, jpeg_turbo_options);
        mod.linkLibrary(jpeg);
    }

    if (options.webp) |webp_options| {
        const webp = try Webp.get(b, target, optimize, webp_options, .{
            .libjpeg_turbo = if (has_libjpeg) .custom else .disabled,
            .libsharpyuv = options.libsharpyuv,
            .libz = options.libz,
        });
        mod.linkLibrary(webp);
    }

    if (options.tiff) |tiff_options| {
        const tiff = try Tiff.get(b, target, optimize, tiff_options, .{
            .libjpeg_turbo = if (has_libjpeg) .custom else .disabled,
            .libwebp = if (has_libwebp and options.webp.?.enable_encoding) .custom else .disabled,
            .libz = options.libz,
            .liblerc = options.liblerc,
            .liblzma = options.liblzma,
            .libzstd = options.libzstd,
        });
        mod.linkLibrary(tiff);
    }
}

pub fn buildLibs(
    b: *std.Build,
    options: Options,
    install_options: std.Build.Step.InstallArtifact.Options,
    step: *std.Build.Step,
) !void {
    const target = options.target;
    const optimize = options.optimize;

    const has_libjpeg = options.jpeg_turbo != null;
    const has_libwebp = options.webp != null;

    if (options.libz == .bundled) {
        if (b.lazyDependency("zlib", .{
            .target = target,
            .optimize = optimize,
        })) |zlib_dep| {
            installLib(b, zlib_dep.artifact("z"), install_options, step);
        }
    }

    if (options.spng) |spng_options| {
        const spng = try Spng.get(b, target, optimize, spng_options, .{
            .libz = options.libz,
        });
        installLib(b, spng, install_options, step);
    }

    var maybe_jpeg: ?*std.Build.Step.Compile = null;
    if (options.jpeg_turbo) |jpeg_turbo_options| {
        const jpeg = try JpegTurbo.get(b, target, optimize, jpeg_turbo_options);
        maybe_jpeg = jpeg;

        installLib(b, jpeg, install_options, step);
    }

    var maybe_webp: ?*std.Build.Step.Compile = null;
    if (options.webp) |webp_options| {
        const webp = try Webp.get(b, target, optimize, webp_options, .{
            .libjpeg_turbo = if (has_libjpeg) .custom else .disabled,
            .libsharpyuv = options.libsharpyuv,
            .libz = options.libz,
        });

        if (has_libjpeg) {
            const jpeg = maybe_jpeg orelse unreachable;
            webp.linkLibrary(jpeg); // so that jpeg headers are available to webp
        }

        maybe_webp = webp;
        installLib(b, webp, install_options, step);
    }

    if (options.tiff) |tiff_options| {
        const tiff = try Tiff.get(b, target, optimize, tiff_options, .{
            .libjpeg_turbo = if (has_libjpeg) .custom else .disabled,
            .libwebp = if (has_libwebp and options.webp.?.enable_encoding) .custom else .disabled,
            .libz = options.libz,
            .liblerc = options.liblerc,
            .liblzma = options.liblzma,
            .libzstd = options.libzstd,
        });

        if (has_libwebp) {
            const webp = maybe_webp orelse unreachable;
            tiff.linkLibrary(webp); // so that webp headers are available to tiff
        }
        if (has_libjpeg) {
            const jpeg = maybe_jpeg orelse unreachable;
            tiff.linkLibrary(jpeg); // so that jpeg headers are available to tiff
        }

        installLib(b, tiff, install_options, step);
    }
}

fn installLib(b: *std.Build, lib: *std.Build.Step.Compile, options: std.Build.Step.InstallArtifact.Options, step: *std.Build.Step) void {
    lib.bundle_ubsan_rt = true;
    const artifact = b.addInstallArtifact(lib, options);
    step.dependOn(&artifact.step);
}
