const std = @import("std");

pub const Options = struct {};

pub fn get(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    options: Options,
) !*std.Build.Step.Compile {
    _ = options;
    const spng_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    const spng_lib = b.addLibrary(.{
        .name = "spng",
        .root_module = spng_mod,
    });

    if (b.lazyDependency("zlib", .{
        .target = target,
        .optimize = optimize,
    })) |zlib_dep| {
        spng_mod.linkLibrary(zlib_dep.artifact("z"));
    }

    if (b.lazyDependency("spng_upstream", .{})) |spng_dep| {
        spng_mod.addCSourceFiles(.{
            .files = &.{"spng.c"},
            .flags = &.{"-std=c99"},
            .root = spng_dep.path("spng"),
        });
        spng_lib.installHeader(spng_dep.path("spng/spng.h"), "spng.h");
    }

    return spng_lib;
}
