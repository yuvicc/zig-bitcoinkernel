//! Internal helpers shared by the wrapper modules. Not part of the public API.

const std = @import("std");
const c = @import("c.zig");

/// Returns a pointer suitable for passing a (possibly empty) byte slice to the
/// kernel. The kernel asserts that the data pointer is non-null whenever the
/// length is non-zero, and Zig does not guarantee a meaningful pointer for
/// empty slices, so empty slices are passed as null.
pub fn bytesPtr(bytes: []const u8) ?*const anyopaque {
    return if (bytes.len == 0) null else bytes.ptr;
}

pub fn toCBool(value: bool) c_int {
    return @intFromBool(value);
}

/// State passed through the `btck_WriteBytes` callback when collecting
/// serialized output into an allocator-backed buffer.
const Collector = struct {
    gpa: std.mem.Allocator,
    list: std.ArrayList(u8) = .empty,
    failed: bool = false,

    fn write(bytes: ?*const anyopaque, size: usize, user_data: ?*anyopaque) callconv(.c) c_int {
        const self: *Collector = @ptrCast(@alignCast(user_data.?));
        if (size == 0) return 0;
        const data: [*]const u8 = @ptrCast(bytes.?);
        self.list.appendSlice(self.gpa, data[0..size]) catch {
            self.failed = true;
            return 1;
        };
        return 0;
    }
};

/// Calls a kernel serialization function `func(handle, extra_args..., writer, user_data)`
/// and collects all written bytes into a newly allocated slice owned by the caller.
pub fn collectBytes(
    gpa: std.mem.Allocator,
    comptime func: anytype,
    args: anytype,
) std.mem.Allocator.Error![]u8 {
    var collector: Collector = .{ .gpa = gpa };
    errdefer collector.list.deinit(gpa);
    const rc = @call(.auto, func, args ++ .{ &Collector.write, @as(?*anyopaque, @ptrCast(&collector)) });
    if (rc != 0 or collector.failed) {
        // The only way our writer fails is through allocation failure; the
        // kernel itself just forwards the writer's return value.
        return error.OutOfMemory;
    }
    return collector.list.toOwnedSlice(gpa);
}

/// Adapter that forwards kernel serialization output into a `std.Io.Writer`.
const IoForwarder = struct {
    writer: *std.Io.Writer,
    failed: bool = false,

    fn write(bytes: ?*const anyopaque, size: usize, user_data: ?*anyopaque) callconv(.c) c_int {
        const self: *IoForwarder = @ptrCast(@alignCast(user_data.?));
        if (size == 0) return 0;
        const data: [*]const u8 = @ptrCast(bytes.?);
        self.writer.writeAll(data[0..size]) catch {
            self.failed = true;
            return 1;
        };
        return 0;
    }
};

/// Calls a kernel serialization function and streams its output into `writer`.
pub fn forwardBytes(
    writer: *std.Io.Writer,
    comptime func: anytype,
    args: anytype,
) std.Io.Writer.Error!void {
    var forwarder: IoForwarder = .{ .writer = writer };
    const rc = @call(.auto, func, args ++ .{ &IoForwarder.write, @as(?*anyopaque, @ptrCast(&forwarder)) });
    if (rc != 0 or forwarder.failed) return error.WriteFailed;
}

/// Simple index-based iterator over items exposed by the kernel through a
/// `count` / `get_at` function pair.
pub fn IndexIterator(comptime Parent: type, comptime Item: type, comptime getAt: fn (Parent, usize) Item) type {
    return struct {
        const Self = @This();

        parent: Parent,
        index: usize = 0,
        len: usize,

        pub fn next(self: *Self) ?Item {
            if (self.index >= self.len) return null;
            defer self.index += 1;
            return getAt(self.parent, self.index);
        }

        pub fn reset(self: *Self) void {
            self.index = 0;
        }
    };
}
