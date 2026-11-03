//! Chain parameters, kernel context options (including notification and
//! validation interface callbacks), and the kernel context itself.

const std = @import("std");
const c = @import("c.zig");
const internal = @import("internal.zig");
const types = @import("types.zig");
const errors = @import("errors.zig");
const block = @import("block.zig");
const BlockTreeEntry = @import("chainstate.zig").BlockTreeEntry;

const Error = errors.Error;

/// Parameters describing the properties of a chain (mainnet, testnet, ...).
pub const ChainParameters = extern struct {
    ptr: *const c.btck_ChainParameters,

    /// Create owned default chain parameters for `chain_type`.
    pub fn init(chain_type: types.ChainType) ChainParameters {
        return .{ .ptr = c.btck_chain_parameters_create(@intFromEnum(chain_type)).? };
    }

    /// Create owned signet chain parameters with a custom signet challenge.
    pub fn initSignet(challenge: []const u8) ChainParameters {
        return .{ .ptr = c.btck_chain_parameters_create_signet(internal.bytesPtr(challenge), challenge.len).? };
    }

    pub fn copy(self: ChainParameters) ChainParameters {
        return .{ .ptr = c.btck_chain_parameters_copy(self.ptr).? };
    }

    pub fn deinit(self: ChainParameters) void {
        c.btck_chain_parameters_destroy(@constCast(self.ptr));
    }

    /// The consensus parameters (borrowed from the chain parameters).
    pub fn consensusParams(self: ChainParameters) ConsensusParams {
        return .{ .ptr = c.btck_chain_parameters_get_consensus_params(self.ptr).? };
    }
};

/// Consensus parameters of a chain. Always borrowed from `ChainParameters`.
pub const ConsensusParams = extern struct {
    ptr: *const c.btck_ConsensusParams,
};

/// Options for creating a kernel `Context`.
pub const ContextOptions = extern struct {
    ptr: *c.btck_ContextOptions,

    /// Create owned, empty context options.
    pub fn init() ContextOptions {
        return .{ .ptr = c.btck_context_options_create().? };
    }

    pub fn deinit(self: ContextOptions) void {
        c.btck_context_options_destroy(self.ptr);
    }

    /// Configure the context for `chain_parameters`. The parameters are
    /// copied and may be released afterwards.
    pub fn setChainParams(self: ContextOptions, chain_parameters: ChainParameters) void {
        c.btck_context_options_set_chainparams(self.ptr, chain_parameters.ptr);
    }

    /// Register kernel notification callbacks.
    ///
    /// `handler` must be a pointer to a struct that may declare any of the
    /// following methods; only declared methods are registered:
    ///
    /// ```
    /// fn blockTip(self: *T, state: SynchronizationState, entry: BlockTreeEntry, verification_progress: f64) void
    /// fn headerTip(self: *T, state: SynchronizationState, height: i64, timestamp: i64, presync: bool) void
    /// fn progress(self: *T, title: []const u8, progress_percent: i32, resume_possible: bool) void
    /// fn warningSet(self: *T, warning: Warning, message: []const u8) void
    /// fn warningUnset(self: *T, warning: Warning) void
    /// fn flushError(self: *T, message: []const u8) void
    /// fn fatalError(self: *T, message: []const u8) void
    /// fn destroy(self: *T) void // called when the kernel releases the handler
    /// ```
    ///
    /// Unless `destroy` is declared, the handler must outlive the context
    /// and everything created from it. Callbacks may be invoked from kernel
    /// threads; the handler is responsible for its own synchronization.
    pub fn setNotifications(self: ContextOptions, handler: anytype) void {
        self.setNotificationsRaw(notificationCallbacks(handler));
    }

    /// Register raw C notification callbacks.
    pub fn setNotificationsRaw(self: ContextOptions, callbacks: c.btck_NotificationInterfaceCallbacks) void {
        c.btck_context_options_set_notifications(self.ptr, callbacks);
    }

    /// Register validation interface callbacks. These are triggered by
    /// validation events of chainstate managers created from the context.
    ///
    /// `handler` must be a pointer to a struct that may declare any of the
    /// following methods; only declared methods are registered:
    ///
    /// ```
    /// fn blockChecked(self: *T, block: Block, state: BlockValidationState) void
    /// fn powValidBlock(self: *T, block: Block, entry: BlockTreeEntry) void
    /// fn blockConnected(self: *T, block: Block, entry: BlockTreeEntry) void
    /// fn blockDisconnected(self: *T, block: Block, entry: BlockTreeEntry) void
    /// fn destroy(self: *T) void // called when the kernel releases the handler
    /// ```
    ///
    /// The `block`, `state` and `entry` arguments are borrowed for the
    /// duration of the call; use `copy` to retain them. Callbacks block
    /// further validation while they run and are invoked from a kernel
    /// thread. Unless `destroy` is declared, the handler must outlive the
    /// context and everything created from it.
    pub fn setValidationInterface(self: ContextOptions, handler: anytype) void {
        self.setValidationInterfaceRaw(validationInterfaceCallbacks(handler));
    }

    /// Register raw C validation interface callbacks.
    pub fn setValidationInterfaceRaw(self: ContextOptions, callbacks: c.btck_ValidationInterfaceCallbacks) void {
        c.btck_context_options_set_validation_interface(self.ptr, callbacks);
    }
};

/// The kernel context. Holds chain parameters and callbacks, and must outlive
/// all objects created from it. Safe to use from multiple threads.
pub const Context = extern struct {
    ptr: *c.btck_Context,

    /// Create an owned kernel context. Without options, a mainnet context
    /// without callbacks is created.
    pub fn init(options: ?ContextOptions) Error!Context {
        const ptr = c.btck_context_create(if (options) |o| o.ptr else null) orelse
            return error.ContextCreationFailed;
        return .{ .ptr = ptr };
    }

    pub fn copy(self: Context) Context {
        return .{ .ptr = c.btck_context_copy(self.ptr).? };
    }

    pub fn deinit(self: Context) void {
        c.btck_context_destroy(self.ptr);
    }

    /// Halt long-running validation functions, e.g. reindexing, importing or
    /// processing blocks.
    pub fn interrupt(self: Context) Error!void {
        if (c.btck_context_interrupt(self.ptr) != 0) return error.InterruptFailed;
    }
};

fn HandlerType(comptime Ptr: type) type {
    const info = @typeInfo(Ptr);
    if (info != .pointer or info.pointer.size != .one or @typeInfo(info.pointer.child) != .@"struct") {
        @compileError("expected a pointer to a handler struct, found " ++ @typeName(Ptr));
    }
    return info.pointer.child;
}

fn castHandler(comptime T: type, user_data: ?*anyopaque) *T {
    return @ptrCast(@alignCast(user_data.?));
}

fn cString(ptr: [*c]const u8, len: usize) []const u8 {
    return if (len == 0) "" else ptr[0..len];
}

fn destroyCallback(comptime T: type) c.btck_DestroyCallback {
    if (!@hasDecl(T, "destroy")) return null;
    return &struct {
        fn f(user_data: ?*anyopaque) callconv(.c) void {
            castHandler(T, user_data).destroy();
        }
    }.f;
}

/// Build C notification callbacks dispatching to the methods of `handler`.
pub fn notificationCallbacks(handler: anytype) c.btck_NotificationInterfaceCallbacks {
    const T = HandlerType(@TypeOf(handler));
    const Tramp = struct {
        fn blockTip(ud: ?*anyopaque, state: c.btck_SynchronizationState, entry: ?*const c.btck_BlockTreeEntry, verification_progress: f64) callconv(.c) void {
            castHandler(T, ud).blockTip(@enumFromInt(state), .{ .ptr = entry.? }, verification_progress);
        }
        fn headerTip(ud: ?*anyopaque, state: c.btck_SynchronizationState, height: i64, timestamp: i64, presync: c_int) callconv(.c) void {
            castHandler(T, ud).headerTip(@enumFromInt(state), height, timestamp, presync != 0);
        }
        fn progress(ud: ?*anyopaque, title: [*c]const u8, title_len: usize, percent: c_int, resume_possible: c_int) callconv(.c) void {
            castHandler(T, ud).progress(cString(title, title_len), @intCast(percent), resume_possible != 0);
        }
        fn warningSet(ud: ?*anyopaque, warning: c.btck_Warning, message: [*c]const u8, message_len: usize) callconv(.c) void {
            castHandler(T, ud).warningSet(@enumFromInt(warning), cString(message, message_len));
        }
        fn warningUnset(ud: ?*anyopaque, warning: c.btck_Warning) callconv(.c) void {
            castHandler(T, ud).warningUnset(@enumFromInt(warning));
        }
        fn flushError(ud: ?*anyopaque, message: [*c]const u8, message_len: usize) callconv(.c) void {
            castHandler(T, ud).flushError(cString(message, message_len));
        }
        fn fatalError(ud: ?*anyopaque, message: [*c]const u8, message_len: usize) callconv(.c) void {
            castHandler(T, ud).fatalError(cString(message, message_len));
        }
    };
    return .{
        .user_data = @ptrCast(handler),
        .user_data_destroy = destroyCallback(T),
        .block_tip = if (@hasDecl(T, "blockTip")) &Tramp.blockTip else null,
        .header_tip = if (@hasDecl(T, "headerTip")) &Tramp.headerTip else null,
        .progress = if (@hasDecl(T, "progress")) &Tramp.progress else null,
        .warning_set = if (@hasDecl(T, "warningSet")) &Tramp.warningSet else null,
        .warning_unset = if (@hasDecl(T, "warningUnset")) &Tramp.warningUnset else null,
        .flush_error = if (@hasDecl(T, "flushError")) &Tramp.flushError else null,
        .fatal_error = if (@hasDecl(T, "fatalError")) &Tramp.fatalError else null,
    };
}

/// Build C validation interface callbacks dispatching to the methods of `handler`.
pub fn validationInterfaceCallbacks(handler: anytype) c.btck_ValidationInterfaceCallbacks {
    const T = HandlerType(@TypeOf(handler));
    const Tramp = struct {
        // The kernel passes a new reference to the block that the callee
        // owns. It is released once the handler returns.
        fn blockChecked(ud: ?*anyopaque, blk: ?*c.btck_Block, state: ?*const c.btck_BlockValidationState) callconv(.c) void {
            const b: block.Block = .{ .ptr = blk.? };
            defer b.deinit();
            castHandler(T, ud).blockChecked(b, .{ .ptr = @constCast(state.?) });
        }
        fn powValidBlock(ud: ?*anyopaque, blk: ?*c.btck_Block, entry: ?*const c.btck_BlockTreeEntry) callconv(.c) void {
            const b: block.Block = .{ .ptr = blk.? };
            defer b.deinit();
            castHandler(T, ud).powValidBlock(b, BlockTreeEntry{ .ptr = entry.? });
        }
        fn blockConnected(ud: ?*anyopaque, blk: ?*c.btck_Block, entry: ?*const c.btck_BlockTreeEntry) callconv(.c) void {
            const b: block.Block = .{ .ptr = blk.? };
            defer b.deinit();
            castHandler(T, ud).blockConnected(b, BlockTreeEntry{ .ptr = entry.? });
        }
        fn blockDisconnected(ud: ?*anyopaque, blk: ?*c.btck_Block, entry: ?*const c.btck_BlockTreeEntry) callconv(.c) void {
            const b: block.Block = .{ .ptr = blk.? };
            defer b.deinit();
            castHandler(T, ud).blockDisconnected(b, BlockTreeEntry{ .ptr = entry.? });
        }
    };
    return .{
        .user_data = @ptrCast(handler),
        .user_data_destroy = destroyCallback(T),
        .block_checked = if (@hasDecl(T, "blockChecked")) &Tramp.blockChecked else null,
        .pow_valid_block = if (@hasDecl(T, "powValidBlock")) &Tramp.powValidBlock else null,
        .block_connected = if (@hasDecl(T, "blockConnected")) &Tramp.blockConnected else null,
        .block_disconnected = if (@hasDecl(T, "blockDisconnected")) &Tramp.blockDisconnected else null,
    };
}
