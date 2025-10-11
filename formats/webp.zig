const std = @import("std");

pub const Options = struct {
    enable_encoding: bool = true,
    enable_mux: bool = true,
    enable_threading: bool = true,
    enable_simd: bool = true,
    has_libjpeg: bool = false,
    use_system_libjpeg: bool = false,
};

pub const InternalOptions = struct {
    libjpeg: ?*std.Build.Step.Compile = null,
};

pub fn get(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: Options,
    internal_options: InternalOptions,
) !*std.Build.Step.Compile {
    const webp_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const webp_lib = b.addLibrary(.{
        .name = "webp",
        .root_module = webp_mod,
    });

    const sharpyuv_lib = try getSharpyuv(b, target, optimize);

    if (b.lazyDependency("libwebp_upstream", .{})) |webp_dep| {
        const config = b.addConfigHeader(.{
            .style = .{ .cmake = webp_dep.path("cmake/config.h.in") },
        }, .{
            .LT_OBJDIR = ".libs",
            .PROJECT_NAME = "WebP",
            .PACKAGE = "libwebp",
            .PACKAGE_BUGREPORT = "https://github.com/webmproject/libwebp/issues",
            .PACKAGE_NAME = "libwebp",
            .PACKAGE_STRING = "libwebp 1.4.0",
            .PACKAGE_TARNAME = "libwebp",
            .PACKAGE_URL = "https://github.com/webmproject/libwebp",
            .PACKAGE_VERSION = "1.4.0",
            .VERSION = "1.4.0",
            .WEBP_USE_THREAD = options.enable_threading,
            .WORDS_BIGENDIAN = false,
            .HAVE_BUILTIN_BSWAP16 = true,
            .HAVE_BUILTIN_BSWAP32 = true,
            .HAVE_BUILTIN_BSWAP64 = true,
            .HAVE_CPU_FEATURES_H = false,
            .HAVE_GLUT_GLUT_H = false,
            .HAVE_GL_GLUT_H = false,
            .HAVE_OPENGL_GLUT_H = false,
            .HAVE_SHLWAPI_H = false,
            .HAVE_UNISTD_H = target.result.os.tag != .windows,
            .HAVE_WINCODEC_H = target.result.os.tag == .windows,
            .HAVE_WINDOWS_H = target.result.os.tag == .windows,
            .WEBP_HAVE_GIF = false,
            .WEBP_HAVE_JPEG = internal_options.libjpeg != null or options.has_libjpeg,
            .WEBP_HAVE_PNG = false,
            .WEBP_HAVE_TIFF = false,
            .WEBP_HAVE_SDL = false,
            .WEBP_HAVE_NEON = target.result.cpu.arch.isAARCH64() or target.result.cpu.arch == .arm,
            .WEBP_HAVE_NEON_RTCD = false,
            .WEBP_HAVE_SSE2 = target.result.cpu.arch.isX86(),
            .WEBP_HAVE_SSE41 = target.result.cpu.arch.isX86(),
            .WEBP_HAVE_AVX2 = target.result.cpu.arch.isX86(),
            .WEBP_NEAR_LOSSLESS = true,
        });
        webp_mod.addConfigHeader(config);
        webp_mod.addIncludePath(webp_dep.path("."));

        // Add common sources
        webp_mod.addCSourceFiles(.{
            .files = &.{
                // dec sources
                "src/dec/alpha_dec.c",
                "src/dec/buffer_dec.c",
                "src/dec/frame_dec.c",
                "src/dec/idec_dec.c",
                "src/dec/io_dec.c",
                "src/dec/quant_dec.c",
                "src/dec/tree_dec.c",
                "src/dec/vp8_dec.c",
                "src/dec/vp8l_dec.c",
                "src/dec/webp_dec.c",
                // dsp common sources
                "src/dsp/alpha_processing.c",
                "src/dsp/cpu.c",
                "src/dsp/dec.c",
                "src/dsp/dec_clip_tables.c",
                "src/dsp/filters.c",
                "src/dsp/lossless.c",
                "src/dsp/rescaler.c",
                "src/dsp/upsampling.c",
                "src/dsp/yuv.c",
                // utils common sources
                "src/utils/bit_reader_utils.c",
                "src/utils/color_cache_utils.c",
                "src/utils/filters_utils.c",
                "src/utils/huffman_utils.c",
                "src/utils/palette.c",
                "src/utils/quant_levels_dec_utils.c",
                "src/utils/rescaler_utils.c",
                "src/utils/random_utils.c",
                "src/utils/utils.c",
            },
            .flags = &.{"-std=c99"},
            .root = webp_dep.path("."),
        });

        if (options.enable_threading) {
            webp_mod.addCSourceFiles(.{
                .files = &.{"src/utils/thread_utils.c"},
                .flags = &.{"-std=c99"},
                .root = webp_dep.path("."),
            });
        }

        if (options.enable_encoding) {
            webp_mod.addCSourceFiles(.{
                .files = &.{
                    // dsp enc sources
                    "src/dsp/cost.c",
                    "src/dsp/enc.c",
                    "src/dsp/lossless_enc.c",
                    "src/dsp/ssim.c",
                    // enc sources
                    "src/enc/alpha_enc.c",
                    "src/enc/analysis_enc.c",
                    "src/enc/backward_references_cost_enc.c",
                    "src/enc/backward_references_enc.c",
                    "src/enc/config_enc.c",
                    "src/enc/cost_enc.c",
                    "src/enc/filter_enc.c",
                    "src/enc/frame_enc.c",
                    "src/enc/histogram_enc.c",
                    "src/enc/iterator_enc.c",
                    "src/enc/near_lossless_enc.c",
                    "src/enc/picture_enc.c",
                    "src/enc/picture_csp_enc.c",
                    "src/enc/picture_psnr_enc.c",
                    "src/enc/picture_rescale_enc.c",
                    "src/enc/picture_tools_enc.c",
                    "src/enc/predictor_enc.c",
                    "src/enc/quant_enc.c",
                    "src/enc/syntax_enc.c",
                    "src/enc/token_enc.c",
                    "src/enc/tree_enc.c",
                    "src/enc/vp8l_enc.c",
                    "src/enc/webp_enc.c",
                    // utils enc sources
                    "src/utils/bit_writer_utils.c",
                    "src/utils/huffman_encode_utils.c",
                    "src/utils/quant_levels_utils.c",
                },
                .flags = &.{"-std=c99"},
                .root = webp_dep.path("."),
            });
        }

        // Add SIMD sources based on target architecture
        const arch = target.result.cpu.arch;
        switch (arch) {
            .x86_64, .x86 => {
                // SSE2 sources
                webp_mod.addCSourceFiles(.{
                    .files = &.{
                        "src/dsp/alpha_processing_sse2.c",
                        "src/dsp/dec_sse2.c",
                        "src/dsp/filters_sse2.c",
                        "src/dsp/lossless_sse2.c",
                        "src/dsp/rescaler_sse2.c",
                        "src/dsp/upsampling_sse2.c",
                        "src/dsp/yuv_sse2.c",
                        "src/dsp/cost_sse2.c",
                        "src/dsp/enc_sse2.c",
                        "src/dsp/lossless_enc_sse2.c",
                        "src/dsp/ssim_sse2.c",
                    },
                    .flags = &.{"-std=c99"},
                    .root = webp_dep.path("."),
                });

                // SSE4.1 sources (available on most x86_64 systems)
                webp_mod.addCSourceFiles(.{
                    .files = &.{
                        "src/dsp/alpha_processing_sse41.c",
                        "src/dsp/dec_sse41.c",
                        "src/dsp/lossless_sse41.c",
                        "src/dsp/upsampling_sse41.c",
                        "src/dsp/yuv_sse41.c",
                        "src/dsp/enc_sse41.c",
                        "src/dsp/lossless_enc_sse41.c",
                    },
                    .flags = &.{"-std=c99"},
                    .root = webp_dep.path("."),
                });

                // AVX2 sources (available on newer x86_64 systems)
                webp_mod.addCSourceFiles(.{
                    .files = &.{
                        "src/dsp/lossless_enc_avx2.c",
                        "src/dsp/lossless_avx2.c",
                    },
                    .flags = &.{"-std=c99"},
                    .root = webp_dep.path("."),
                });
            },
            .aarch64, .arm => {
                // ARM NEON sources
                webp_mod.addCSourceFiles(.{
                    .files = &.{
                        "src/dsp/alpha_processing_neon.c",
                        "src/dsp/cost_neon.c",
                        "src/dsp/dec_neon.c",
                        "src/dsp/enc_neon.c",
                        "src/dsp/filters_neon.c",
                        "src/dsp/lossless_enc_neon.c",
                        "src/dsp/lossless_neon.c",
                        "src/dsp/rescaler_neon.c",
                        "src/dsp/upsampling_neon.c",
                        "src/dsp/yuv_neon.c",
                    },
                    .flags = &.{"-std=c99"},
                    .root = webp_dep.path("."),
                });
            },
            .mips, .mips64 => {
                // MIPS sources
                webp_mod.addCSourceFiles(.{
                    .files = &.{
                        "src/dsp/alpha_processing_mips_dsp_r2.c",
                        "src/dsp/cost_mips32.c",
                        "src/dsp/cost_mips_dsp_r2.c",
                        "src/dsp/dec_mips32.c",
                        "src/dsp/dec_mips_dsp_r2.c",
                        "src/dsp/enc_mips32.c",
                        "src/dsp/enc_mips_dsp_r2.c",
                        "src/dsp/filters_mips_dsp_r2.c",
                        "src/dsp/lossless_enc_mips32.c",
                        "src/dsp/lossless_enc_mips_dsp_r2.c",
                        "src/dsp/lossless_mips_dsp_r2.c",
                        "src/dsp/rescaler_mips32.c",
                        "src/dsp/rescaler_mips_dsp_r2.c",
                        "src/dsp/upsampling_mips_dsp_r2.c",
                        "src/dsp/yuv_mips32.c",
                        "src/dsp/yuv_mips_dsp_r2.c",
                    },
                    .flags = &.{"-std=c99"},
                    .root = webp_dep.path("."),
                });
            },
            else => {},
        }

        webp_mod.linkLibrary(sharpyuv_lib);

        webp_lib.installHeader(webp_dep.path("src/webp/decode.h"), "webp/decode.h");
        if (options.enable_encoding) {
            webp_lib.installHeader(webp_dep.path("src/webp/encode.h"), "webp/encode.h");
        }
        webp_lib.installHeader(webp_dep.path("src/webp/types.h"), "webp/types.h");

        if (options.has_libjpeg) {
            if (options.use_system_libjpeg) {
                webp_mod.linkSystemLibrary("jpeg", .{});
            } else if (internal_options.libjpeg) |libjpeg| {
                webp_lib.linkLibrary(libjpeg);
            }
        }

        return webp_lib;
    }

    return error.WebPDependencyNotFound;
}

pub fn getSharpyuv(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) !*std.Build.Step.Compile {
    const sharpyuv_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const sharpyuv_lib = b.addLibrary(.{
        .name = "sharpyuv",
        .root_module = sharpyuv_mod,
    });

    if (b.lazyDependency("libwebp_upstream", .{})) |webp_dep| {
        sharpyuv_mod.addIncludePath(webp_dep.path("."));

        // Add common sharpyuv sources
        sharpyuv_mod.addCSourceFiles(.{
            .files = &.{
                "sharpyuv/sharpyuv_cpu.c",
                "sharpyuv/sharpyuv_csp.c",
                "sharpyuv/sharpyuv_dsp.c",
                "sharpyuv/sharpyuv_gamma.c",
                "sharpyuv/sharpyuv.c",
            },
            .flags = &.{"-std=c99"},
            .root = webp_dep.path("."),
        });

        // Add SIMD sources based on target architecture
        const arch = target.result.cpu.arch;
        switch (arch) {
            .x86_64, .x86 => {
                sharpyuv_mod.addCSourceFiles(.{
                    .files = &.{"sharpyuv/sharpyuv_sse2.c"},
                    .flags = &.{"-std=c99"},
                    .root = webp_dep.path("."),
                });
            },
            .aarch64, .arm => {
                sharpyuv_mod.addCSourceFiles(.{
                    .files = &.{"sharpyuv/sharpyuv_neon.c"},
                    .flags = &.{"-std=c99"},
                    .root = webp_dep.path("."),
                });
            },
            else => {},
        }

        sharpyuv_lib.installHeader(webp_dep.path("sharpyuv/sharpyuv.h"), "sharpyuv.h");
        sharpyuv_lib.installHeader(webp_dep.path("sharpyuv/sharpyuv_csp.h"), "sharpyuv_csp.h");
    }

    return sharpyuv_lib;
}
