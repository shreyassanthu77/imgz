const std = @import("std");
const RequiredLibrary = @import("shared.zig").RequiredLibrary;

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
            .flags = &.{"-std=c99"},
            .root = spng_dep.path("spng"),
        });
        lib.installHeader(spng_dep.path("spng/spng.h"), "spng.h");
    }

    return lib;
}
