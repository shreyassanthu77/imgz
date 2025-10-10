const std = @import("std");

pub const Options = struct {
    has_glut_glut_h: bool = false,
    has_gl_glut_h: bool = false,
    has_gl_glu_h: bool = false,
    has_gl_gl_h: bool = false,
    has_opengl_glu_h: bool = false,
    has_opengl_gl_h: bool = false,

    has_liblzma: bool = false,
    use_system_liblzma: bool = false,
    has_libwebp: bool = false,
    use_system_libwebp: bool = false,
    has_libzstd: bool = false,
    use_system_libzstd: bool = false,
    has_liblerc: bool = false,
    use_system_liblerc: bool = false,
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
    const has_glut_glut_h = options.has_glut_glut_h;
    const has_gl_glut_h = options.has_gl_glut_h;
    const has_gl_glu_h = options.has_gl_glu_h;
    const has_gl_gl_h = options.has_gl_gl_h;
    const has_opengl_glu_h = options.has_opengl_glu_h;
    const has_opengl_gl_h = options.has_opengl_gl_h;

    const has_liblzma = options.has_liblzma;
    const use_system_liblzma = options.use_system_liblzma;
    const has_libwebp = options.has_libwebp;
    const use_system_libwebp = options.use_system_libwebp;
    const has_libzstd = options.has_libzstd;
    const use_system_libzstd = options.use_system_libzstd;
    const has_liblerc = options.has_liblerc;
    const use_system_liblerc = options.use_system_liblerc;

    const has_libjpeg = internal_options.libjpeg != null;

    const tiff_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const lib_tiff = b.addLibrary(.{
        .name = "tiff",
        .root_module = tiff_mod,
    });

    if (b.lazyDependency("libtiff_upstream", .{})) |tiff_upstream| {
        const bit_width = target.result.ptrBitWidth() / 8;
        const tif_config = b.addConfigHeader(.{
            .style = .{ .cmake = tiff_upstream.path("libtiff/tif_config.h.cmake.in") },
            .include_path = "tif_config.h",
        }, .{
            .CCITT_SUPPORT = true,
            .CHECK_JPEG_YCBCR_SUBSAMPLING = true,
            .CHUNKY_STRIP_READ_SUPPORT = true,
            .CXX_SUPPORT = false,
            .DEFER_STRILE_LOAD = true,
            .HAVE_ASSERT_H = true,
            .HAVE_DECL_OPTARG = true,
            .HAVE_FCNTL_H = true,
            .HAVE_FSEEKO = true,
            .HAVE_GETOPT = true,
            .HAVE_GLUT_GLUT_H = has_glut_glut_h,
            .HAVE_GL_GLUT_H = has_gl_glut_h,
            .HAVE_GL_GLU_H = has_gl_glu_h,
            .HAVE_GL_GL_H = has_gl_gl_h,
            .HAVE_IO_H = target.result.os.tag == .windows,
            .HAVE_JBG_NEWLEN = false,
            .HAVE_MMAP = target.result.os.tag != .windows,
            .HAVE_OPENGL_GLU_H = has_opengl_glu_h,
            .HAVE_OPENGL_GL_H = has_opengl_gl_h,
            .HAVE_SETMODE = target.result.os.tag == .windows,
            .HAVE_STRINGS_H = true,
            .HAVE_SYS_TYPES_H = true,
            .HAVE_UNISTD_H = target.result.os.tag != .windows,
            .JPEG_DUAL_MODE_8_12 = has_libjpeg,
            .HAVE_JPEGTURBO_DUAL_MODE_8_12 = false,
            .LERC_SUPPORT = use_system_liblerc or has_liblerc,
            .LERC_STATIC = has_liblerc,
            .LZMA_SUPPORT = use_system_liblzma or has_liblzma,
            .WEBP_SUPPORT = use_system_libwebp or has_libwebp,
            .ZSTD_SUPPORT = use_system_libzstd or has_libzstd,
            .USE_WIN32_FILEIO = target.result.os.tag == .windows,
            .SIZEOF_SIZE_T = bit_width,
            .STRIP_SIZE_DEFAULT = 8192,
            .TIFF_MAX_DIR_COUNT = 65535,
            .LIBJPEG_12_PATH = "jpeglib.h",
            .PACKAGE = "libtiff",
            .PACKAGE_NAME = "libtiff",
            .PACKAGE_TARNAME = "libtiff",
            .PACKAGE_URL = "https://libtiff.gitlab.io/libtiff/",
            .PACKAGE_BUGREPORT = "https://gitlab.com/libtiff/libtiff/-/issues",
            .VAR = "lol",
        });

        const tiffconf = b.addConfigHeader(.{
            .style = .{ .cmake = tiff_upstream.path("libtiff/tiffconf.h.cmake.in") },
            .include_path = "tiffconf.h",
        }, .{
            .TIFF_INT16_T = "int16_t",
            .TIFF_INT32_T = "int32_t",
            .TIFF_INT64_T = "int64_t",
            .TIFF_INT8_T = "int8_t",
            .TIFF_UINT16_T = "uint16_t",
            .TIFF_UINT32_T = "uint32_t",
            .TIFF_UINT64_T = "uint64_t",
            .TIFF_UINT8_T = "uint8_t",
            .TIFF_SSIZE_T = if (bit_width == 4)
                "int32_t"
            else if (bit_width == 8)
                "int64_t"
            else
                return error.UnsupportedBitWidth,
            .HAVE_IEEEFP = true,
            .HOST_BIG_ENDIAN = target.result.cpu.arch.endian(),
            .CCITT_SUPPORT = true,
            .JPEG_SUPPORT = has_libjpeg,
            .JBIG_SUPPORT = false,
            .LERC_SUPPORT = use_system_liblerc or has_liblerc,
            .LOGLUV_SUPPORT = true,
            .LZW_SUPPORT = true,
            .NEXT_SUPPORT = false,
            .OJPEG_SUPPORT = false,
            .PACKBITS_SUPPORT = true,
            .PIXARLOG_SUPPORT = true,
            .THUNDER_SUPPORT = false,
            .ZIP_SUPPORT = true,
            .LIBDEFLATE_SUPPORT = false,
            .STRIPCHOP_DEFAULT = .TIFF_STRIPCHOP,
            .SUBIFD_SUPPORT = true,
            .DEFAULT_EXTRASAMPLE_AS_ALPHA = true,
            .CHECK_JPEG_YCBCR_SUBSAMPLING = true,
            .MDI_SUPPORT = false,

            .VAR = "lol",
        });

        const tiffvers = blk: {
            const version_file = tiff_upstream.path("VERSION").getPath(b);
            const version = try std.fs.cwd().readFileAlloc(b.allocator, version_file, 1024);
            const version_trimmed = std.mem.trim(u8, version, " \n");
            var version_split = std.mem.splitScalar(u8, version_trimmed, '.');
            const major_version = try std.fmt.parseInt(u16, version_split.next() orelse return error.InvalidVersion, 10);
            const minor_version = try std.fmt.parseInt(u16, version_split.next() orelse return error.InvalidVersion, 10);
            const micro_version = try std.fmt.parseInt(u16, version_split.next() orelse return error.InvalidVersion, 10);

            const release_date_file = tiff_upstream.path("RELEASE-DATE").getPath(b);
            const release_date = try std.fs.cwd().readFileAlloc(b.allocator, release_date_file, 1024);

            const tiffvers = b.addConfigHeader(.{
                .style = .{ .cmake = tiff_upstream.path("libtiff/tiffvers.h.cmake.in") },
                .include_path = "tiffvers.h",
            }, .{
                .LIBTIFF_VERSION = version_trimmed,
                .LIBTIFF_RELEASE_DATE = release_date,
                .LIBTIFF_MAJOR_VERSION = major_version,
                .LIBTIFF_MINOR_VERSION = minor_version,
                .LIBTIFF_MICRO_VERSION = micro_version,

                .VAR = "lol",
            });

            break :blk tiffvers;
        };

        tiff_mod.addConfigHeader(tif_config);
        tiff_mod.addConfigHeader(tiffconf);
        tiff_mod.addConfigHeader(tiffvers);

        tiff_mod.addCSourceFiles(.{
            .root = tiff_upstream.path("."),
            .files = &.{
                "libtiff/tif_aux.c",
                "libtiff/tif_close.c",
                "libtiff/tif_codec.c",
                "libtiff/tif_color.c",
                "libtiff/tif_compress.c",
                "libtiff/tif_dir.c",
                "libtiff/tif_dirinfo.c",
                "libtiff/tif_dirread.c",
                "libtiff/tif_dirwrite.c",
                "libtiff/tif_dumpmode.c",
                "libtiff/tif_error.c",
                "libtiff/tif_extension.c",
                "libtiff/tif_fax3.c",
                "libtiff/tif_fax3sm.c",
                "libtiff/tif_flush.c",
                "libtiff/tif_getimage.c",
                "libtiff/tif_hash_set.c",
                "libtiff/tif_jbig.c",
                "libtiff/tif_jpeg.c",
                "libtiff/tif_jpeg_12.c",
                "libtiff/tif_lerc.c",
                "libtiff/tif_luv.c",
                "libtiff/tif_lzma.c",
                "libtiff/tif_lzw.c",
                "libtiff/tif_next.c",
                "libtiff/tif_ojpeg.c",
                "libtiff/tif_open.c",
                "libtiff/tif_packbits.c",
                "libtiff/tif_pixarlog.c",
                "libtiff/tif_predict.c",
                "libtiff/tif_print.c",
                "libtiff/tif_read.c",
                "libtiff/tif_strip.c",
                "libtiff/tif_swab.c",
                "libtiff/tif_thunder.c",
                "libtiff/tif_tile.c",
                "libtiff/tif_version.c",
                "libtiff/tif_warning.c",
                "libtiff/tif_webp.c",
                "libtiff/tif_write.c",
                "libtiff/tif_zip.c",
                "libtiff/tif_zstd.c",
                if (target.result.os.tag == .windows)
                    "libtiff/tif_win32.c"
                else
                    "libtiff/tif_unix.c",
            },
            .flags = &.{
                "-std=c99",
                "-Wall",
                "-Wextra",
                "-Werror",
            },
        });

        if (b.lazyDependency("zlib", .{
            .target = target,
            .optimize = optimize,
        })) |zlib_dep| {
            tiff_mod.linkLibrary(zlib_dep.artifact("z"));
        }

        if (use_system_liblzma and !has_liblzma) {
            tiff_mod.linkSystemLibrary("lzma", .{});
        }
        if (use_system_liblerc and !has_liblerc) {
            tiff_mod.linkSystemLibrary("Lerc", .{});
        }
        if (use_system_libzstd and !has_libzstd) {
            tiff_mod.linkSystemLibrary("zstd", .{});
        }
        if (use_system_libwebp and !has_libwebp) {
            tiff_mod.linkSystemLibrary("webp", .{});
        }

        lib_tiff.installHeader(tiff_upstream.path("libtiff/tiff.h"), "tiff.h");
        lib_tiff.installHeader(tiff_upstream.path("libtiff/tiffio.h"), "tiffio.h");
        lib_tiff.installConfigHeader(tiffvers);
        lib_tiff.installConfigHeader(tif_config);
        lib_tiff.installConfigHeader(tiffconf);
    }

    if (internal_options.libjpeg) |libjpeg| {
        lib_tiff.linkLibrary(libjpeg);
    }

    return lib_tiff;
}
