# imgz

pupular image libraries packaged for the zig build system.
All dependencies fetched from upstream and built from source with zig.
Supports cross compilation to almost all platforms (create an issue if it doesn't build for any platforms)

## Usage

### Install

```sh
zig fetch --save git+https://github.com/shreyassanthu77/imgz.git
```

### In your build.zig

```zig
const std = @import("std");
const imgz = @import("imgz");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // returns a static library with all the dependencies linked
    const imgz = try imgz.get(b, .{
        .target = target,
        .optimize = optimize,
        // set to null to not include the library
        .jpeg_turbo = .{}, 
        .spng = .{},
        .tiff = .{},
    });

    // usage example (exe is your executable / module / library ...)
    exe.linkLibrary(imgz);
}
```

## Supported libraries
- libjpeg-turbo
- libspng
- libtiff
