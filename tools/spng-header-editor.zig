const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, arena);
    defer args.deinit();
    _ = args.skip();
    const source_path = args.next() orelse return error.InvalidArguments;
    if (args.next() != null) return error.InvalidArguments;

    const source_contents = try std.Io.Dir.cwd().readFileAlloc(init.io, source_path, arena, .unlimited);

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.writeAll(
        \\#ifndef SPNG_STATIC
        \\#define SPNG_STATIC
        \\#endif
        \\
    );
    try stdout.writeAll(source_contents);
    try stdout.flush();
}
