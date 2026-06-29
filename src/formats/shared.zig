const std = @import("std");

pub const RequiredLibrary = enum {
    /// Use the system provided library
    system,
    /// Use imgz's bundled version of the library
    bundled,
    /// A custom library will be linked manually
    custom,
    /// Don't link to the library
    disabled,
};

pub const LazyFileEditor = struct {
    result: std.Build.LazyPath,

    pub fn create(
        b: *std.Build,
        path: std.Build.LazyPath,
        basename: []const u8,
        editor_source: std.Build.LazyPath,
    ) *LazyFileEditor {
        const self = b.allocator.create(LazyFileEditor) catch @panic("OOM");
        const editor_exe = b.addExecutable(.{
            .name = b.fmt("edit-{s}", .{std.fs.path.stem(basename)}),
            .root_module = b.createModule(.{
                .root_source_file = editor_source,
                .target = b.graph.host,
            }),
        });
        const run_editor = b.addRunArtifact(editor_exe);
        run_editor.addFileArg(path);
        self.* = .{
            .result = run_editor.captureStdOut(.{ .basename = basename }),
        };
        return self;
    }
};
