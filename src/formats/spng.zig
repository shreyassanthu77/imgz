const std = @import("std");
const shared = @import("shared.zig");
const RequiredLibrary = shared.RequiredLibrary;
const LazyFileEditor = shared.LazyFileEditor;

pub const Options = struct {};

pub const Deps = struct {
    libz: RequiredLibrary = RequiredLibrary.bundled,
};

pub fn get(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    option: Options,
    deps: Deps,
) !*std.Build.Step.Compile {
    _ = option;

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    const lib = b.addLibrary(.{
        .name = "spng",
        .root_module = mod,
        .linkage = .static,
    });

    switch (deps.libz) {
        .system => {
            mod.linkSystemLibrary("z", .{});
        },
        .bundled => if (b.lazyDependency("zlib", .{
            .target = target,
            .optimize = optimize,
        })) |zlib_dep| {
            mod.linkLibrary(zlib_dep.artifact("z"));
        },
        .custom => {}, // user is responsible for providing the library
        .disabled => {
            std.log.err("Spng requires zlib, but it was disabled", .{});
            return error.ZlibDisabled;
        },
    }

    if (b.lazyDependency("spng_upstream", .{})) |spng_dep| {
        mod.addIncludePath(spng_dep.path("spng"));
        mod.addCSourceFiles(.{
            .files = &.{"spng.c"},
            .flags = &.{ "-std=c99", "-DSPNG_STATIC" },
            .root = spng_dep.path("spng"),
        });

        const spng_out_h_gen = LazyFileEditor.create(b, spng_dep.path("spng/spng.h"), "spng.h", b.path("tools/spng-header-editor.zig"));
        lib.installHeader(spng_out_h_gen.result, "spng.h");
    }

    return lib;
}
