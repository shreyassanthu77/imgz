# imgz

Popular image libraries packaged for the Zig build system.
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

## Usage in Code

Use the C APIs directly via `@cImport`. See the official documentation for each library for API details and examples.

## Build Options

You can customize the build by passing options to the `imgz.get()` function:

```zig
const imgz = try imgz.get(b, .{
    .target = target,
    .optimize = optimize,
    .jpeg_turbo = .{
        .pic = true,        // Enable position independent code
        .arith_enc = true,  // Enable arithmetic encoding
        .arith_dec = true,  // Enable arithmetic decoding
        .simd = true,       // Enable SIMD extensions
    },
    .spng = .{},           // Enable libspng (no options currently)
    .tiff = .{
        .has_liblzma = false,     // Enable liblzma support
        .use_system_liblzma = false,
        .has_libwebp = false,     // Enable libwebp support
        .use_system_libwebp = false,
        .has_libzstd = false,     // Enable libzstd support
        .use_system_libzstd = false,
        .has_liblerc = false,     // Enable liblerc support
        .use_system_liblerc = false,
    },
});
```

Set any library option to `null` to exclude it from the build:

```zig
const imgz = try imgz.get(b, .{
    .target = target,
    .optimize = optimize,
    .jpeg_turbo = null,  // Exclude libjpeg-turbo
    .spng = .{},
    .tiff = .{},
});
```

**Note:** `libtiff` itself doesn't require `libjpeg_turbo`, but if you need JPEG compression support within TIFF containers, you must also enable `libjpeg_turbo`.

## Testing

Run the test suite to verify that all libraries are working correctly:

```sh
zig build test
```

The tests include basic encode/decode operations for each supported format using sample images in the `test-images/` directory.

## Cross-Compilation

This package supports cross-compilation to all platforms supported by Zig. The underlying C libraries are built from source for each target platform, ensuring compatibility and optimal performance.

## Supported libraries

- [libjpeg-turbo](https://libjpeg-turbo.org/)
- [libspng](https://libspng.org/)
- [libtiff](https://libtiff.gitlab.io/libtiff/)

(PRs are welcome for more libraries :) )

## Contributing

Contributions are welcome! Please feel free to submit pull requests for:

- Additional image format libraries
- Bug fixes and improvements
- Documentation enhancements
- Test coverage improvements

When adding new libraries, please include:
- Build configuration in the appropriate `formats/*.zig` file
- Tests in `test.zig`
- Documentation in this README
