const std = @import("std");

pub const Options = struct {};

pub fn get(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    lib: *std.Build.Step.Compile,
    options: Options,
) !void {
    _ = options;
    const mod = lib.root_module;

    if (b.lazyDependency("zlib", .{
        .target = target,
        .optimize = optimize,
    })) |zlib_dep| {
        mod.linkLibrary(zlib_dep.artifact("z"));
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
}
