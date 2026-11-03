//! Global kernel logging configuration and logging connections.
//!
//! All functions here change global settings that apply to every
//! `LoggingConnection`.

const c = @import("c.zig");
const types = @import("types.zig");
const errors = @import("errors.zig");

const Error = errors.Error;

/// Permanently disable the global internal logger. Must be called at most
/// once, not concurrently, and not while a logging connection exists.
pub fn disable() void {
    c.btck_logging_disable();
}

/// Set formatting options of log messages.
pub fn setOptions(options: types.LoggingOptions) void {
    c.btck_logging_set_options(options.toC());
}

/// Set the log level of `category`. For `.all`, sets the global fallback
/// level as well as the level of messages logged in the `.all` category.
/// This does not enable the category; see `enableCategory`.
pub fn setLevelCategory(category: types.LogCategory, level: types.LogLevel) void {
    c.btck_logging_set_level_category(@intFromEnum(category), @intFromEnum(level));
}

/// Enable logging of `category` (`.all` enables every category).
pub fn enableCategory(category: types.LogCategory) void {
    c.btck_logging_enable_category(@intFromEnum(category));
}

/// Disable logging of `category` (`.all` disables every category).
pub fn disableCategory(category: types.LogCategory) void {
    c.btck_logging_disable_category(@intFromEnum(category));
}

/// A connection receiving kernel log messages. Messages logged before the
/// first connection is created are buffered and delivered on creation.
pub const LoggingConnection = extern struct {
    ptr: *c.btck_LoggingConnection,

    /// Start delivering log messages to `handler`, a pointer to a struct
    /// declaring:
    ///
    /// ```
    /// fn log(self: *T, message: []const u8) void
    /// fn destroy(self: *T) void // optional, called when the connection is destroyed
    /// ```
    ///
    /// Unless `destroy` is declared, `handler` must outlive the connection.
    /// Messages may be delivered from any kernel thread.
    pub fn init(handler: anytype) Error!LoggingConnection {
        const Ptr = @TypeOf(handler);
        const T = @typeInfo(Ptr).pointer.child;
        const Tramp = struct {
            fn log(user_data: ?*anyopaque, message: [*c]const u8, len: usize) callconv(.c) void {
                const self: *T = @ptrCast(@alignCast(user_data.?));
                self.log(if (len == 0) "" else message[0..len]);
            }
            fn destroy(user_data: ?*anyopaque) callconv(.c) void {
                const self: *T = @ptrCast(@alignCast(user_data.?));
                self.destroy();
            }
        };
        const ptr = c.btck_logging_connection_create(
            &Tramp.log,
            @ptrCast(handler),
            if (@hasDecl(T, "destroy")) &Tramp.destroy else null,
        ) orelse return error.LoggingConnectionFailed;
        return .{ .ptr = ptr };
    }

    /// Start delivering log messages to a plain function.
    pub fn initFn(comptime logFn: fn (message: []const u8) void) Error!LoggingConnection {
        const Tramp = struct {
            fn log(_: ?*anyopaque, message: [*c]const u8, len: usize) callconv(.c) void {
                logFn(if (len == 0) "" else message[0..len]);
            }
        };
        const ptr = c.btck_logging_connection_create(&Tramp.log, null, null) orelse
            return error.LoggingConnectionFailed;
        return .{ .ptr = ptr };
    }

    /// Stop logging and destroy the connection.
    pub fn deinit(self: LoggingConnection) void {
        c.btck_logging_connection_destroy(self.ptr);
    }
};
