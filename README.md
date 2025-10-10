# imgz

Popular image libraries packaged for the Zig build system.
All dependencies fetched from upstream and built from source with Zig.
Supports cross-compilation to almost all platforms (create an issue if it doesn't build for any platforms).

## Requirements

- Zig: 0.15.1 or newer
- NASM: required on x86/x86_64 for libjpeg-turbo SIMD. If unavailable, disable SIMD via `.simd = false` (consumer) or `-Djpeg_turbo_simd=false` (when building this repo).

## Install

```sh
zig fetch --save git+https://github.com/shreyassanthu77/imgz.git
```

## In your build.zig

```zig
const std = @import("std");
const imgz_pkg = @import("imgz");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // returns a static library with selected dependencies linked
    const imgz_lib = try imgz_pkg.get(b, .{
        .target = target,
        .optimize = optimize,
        .jpeg_turbo = .{},
        .spng = .{},
        .tiff = .{},
    });

    exe.linkLibrary(imgz_lib);
    b.installArtifact(exe);
}
```

## Usage in Code

Use the C APIs directly via `@cImport`. Headers from enabled libraries are provided by linking `imgz_lib`, so no extra include paths are typically required.

## Configuration

You can configure imgz either as a dependency (via the `get` API) or when building this repository with `zig build` flags.

- As a dependency (recommended) — pass options to `imgz_pkg.get(...)`:

```zig
const imgz_lib = try imgz_pkg.get(b, .{
    .target = target,
    .optimize = optimize,
    .jpeg_turbo = .{
        .arith_enc = true,  // arithmetic encoding
        .arith_dec = true,  // arithmetic decoding
        .simd = true,       // SIMD extensions
    },
    .spng = .{},            // libspng (no options currently)
    .tiff = .{
        .has_liblzma = false,
        .use_system_liblzma = false,
        .has_libwebp = false,
        .use_system_libwebp = false,
        .has_libzstd = false,
        .use_system_libzstd = false,
        .has_liblerc = false,
        .use_system_liblerc = false,
    },
});
```

Set any library option to `null` to exclude it from the build:

```zig
const imgz_lib = try imgz_pkg.get(b, .{
    .target = target,
    .optimize = optimize,
    .jpeg_turbo = null,  // exclude libjpeg-turbo
    .spng = .{},
    .tiff = .{},
});
```

- When building this repo directly — available flags (defaults in parentheses):
  - `-Dspng` (true): enable libspng
  - `-Djpeg_turbo` (true): enable libjpeg-turbo
  - `-Djpeg_turbo_arith_enc` (true)
  - `-Djpeg_turbo_arith_dec` (true)
  - `-Djpeg_turbo_simd` (true)
  - `-Dtiff` (true): enable libtiff
  - `-Dtiff_has_liblzma` (false), `-Dtiff_use_system_liblzma` (false)
  - `-Dtiff_has_libwebp` (false), `-Dtiff_use_system_libwebp` (false)
  - `-Dtiff_has_libzstd` (false), `-Dtiff_use_system_libzstd` (false)
  - `-Dtiff_has_liblerc` (false), `-Dtiff_use_system_liblerc` (false)

Examples:

```sh
zig build -Djpeg_turbo=false
zig build -Dtiff_has_liblzma=true -Dtiff_use_system_liblzma=true
zig build -Djpeg_turbo_simd=false   # if nasm is unavailable
```

## Testing

Run the test suite to verify that all libraries are working correctly:

```sh
zig build test
```

The tests include basic encode/decode operations for each supported format using sample images in the `test-images/` directory.

## Cross-Compilation

This package supports cross-compilation to all platforms supported by Zig. The underlying C libraries are built from source for each target platform.

Notes:
- x86/x86_64 SIMD for libjpeg-turbo uses NASM; install NASM or disable SIMD.
- RISC-V has no libjpeg-turbo SIMD support (automatically disabled).

## Upstream Versions

These are pinned in `build.zig.zon`:

- libspng: v0.7.4 — https://github.com/randy408/libspng
- libjpeg-turbo: 3.1.2 (JPEG_LIB_VERSION 80) — https://github.com/libjpeg-turbo/libjpeg-turbo
- libtiff: commit 57dd777… — https://gitlab.com/libtiff/libtiff
- zlib (vendored for consumers): 1.3.1 — https://github.com/allyourcodebase/zlib

## Supported Libraries

- [libjpeg-turbo](https://libjpeg-turbo.org/)
- [libspng](https://libspng.org/)
- [libtiff](https://libtiff.gitlab.io/libtiff/)

(PRs are welcome for more libraries.)

## Troubleshooting

- `nasm: command not found` or assembler errors on x86/x86_64: install NASM or set `.simd = false` / `-Djpeg_turbo_simd=false`.
- `@cImport` cannot find headers: ensure your artifact links the returned `imgz_lib` from `imgz_pkg.get(...)` before compiling sources that `@cInclude`.
- Missing system libs when enabling TIFF extras: when using `use_system_* = true`, ensure the corresponding system library is installed and discoverable by the host toolchain.

## Contributing

Contributions are welcome! Please feel free to submit pull requests for:

- Additional image format libraries
- Bug fixes and improvements
- Documentation enhancements
- Test coverage improvements

When adding new libraries, please include:
- Build configuration in the appropriate `formats/*.zig` file
- Tests in `test.zig`
- Documentation updates in this README
