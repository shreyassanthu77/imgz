const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();

    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, arena);
    defer args.deinit();
    _ = args.skip();
    const template_path = args.next() orelse return error.InvalidArguments;
    const version_path = args.next() orelse return error.InvalidArguments;
    const release_date_path = args.next() orelse return error.InvalidArguments;
    if (args.next() != null) return error.InvalidArguments;

    const template = try std.Io.Dir.cwd().readFileAlloc(init.io, template_path, arena, .unlimited);
    const version_raw = try std.Io.Dir.cwd().readFileAlloc(init.io, version_path, arena, .unlimited);
    const release_date_raw = try std.Io.Dir.cwd().readFileAlloc(init.io, release_date_path, arena, .unlimited);
    const version = std.mem.trim(u8, version_raw, " \n\r\t");
    const release_date = std.mem.trim(u8, release_date_raw, " \n\r\t");

    var split = std.mem.splitScalar(u8, version, '.');
    const major = split.next() orelse return error.InvalidVersion;
    const minor = split.next() orelse return error.InvalidVersion;
    const micro = split.next() orelse return error.InvalidVersion;

    var rendered = std.Io.Writer.Allocating.init(arena);
    try render(template, &rendered.writer, &.{
        .{ .key = "LIBTIFF_VERSION", .value = version },
        .{ .key = "LIBTIFF_RELEASE_DATE", .value = release_date },
        .{ .key = "LIBTIFF_MAJOR_VERSION", .value = major },
        .{ .key = "LIBTIFF_MINOR_VERSION", .value = minor },
        .{ .key = "LIBTIFF_MICRO_VERSION", .value = micro },
    });
    try rendered.writer.flush();

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buffer);
    try stdout_writer.interface.writeAll(rendered.written());
    try stdout_writer.interface.flush();
}

fn render(template: []const u8, writer: *std.Io.Writer, vars: []const Var) !void {
    var rest = template;
    while (std.mem.indexOfScalar(u8, rest, '@')) |start| {
        try writer.writeAll(rest[0..start]);
        const after_start = rest[start + 1 ..];
        const end = std.mem.indexOfScalar(u8, after_start, '@') orelse {
            try writer.writeAll(rest[start..]);
            return;
        };
        const key = after_start[0..end];
        if (lookup(vars, key)) |value| {
            try writer.writeAll(value);
        } else {
            try writer.writeByte('@');
            try writer.writeAll(key);
            try writer.writeByte('@');
        }
        rest = after_start[end + 1 ..];
    }
    try writer.writeAll(rest);
}

const Var = struct {
    key: []const u8,
    value: []const u8,
};

fn lookup(vars: []const Var, key: []const u8) ?[]const u8 {
    for (vars) |v| if (std.mem.eql(u8, v.key, key)) return v.value;
    return null;
}
