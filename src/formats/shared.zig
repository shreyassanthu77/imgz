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
