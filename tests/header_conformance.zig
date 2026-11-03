//! Checks at compile time that the hand-written declarations in `src/c.zig`
//! match the vendored upstream `include/bitcoinkernel.h` (translated with
//! translate-c): every function, constant, typedef and struct must exist on
//! both sides with compatible signatures and identical values.

const std = @import("std");
const h = @import("bitcoinkernel_h");
const c = @import("bitcoinkernel").c;

const Shape = union(enum) {
    void,
    bool,
    int: std.builtin.Type.Int,
    float: u16,
    pointer,
    @"struct": usize,
    other,
};

fn shapeOf(comptime T: type) Shape {
    return switch (@typeInfo(T)) {
        .void => .void,
        .bool => .bool,
        .int => |i| .{ .int = i },
        .float => |f| .{ .float = f.bits },
        .pointer => .pointer,
        .optional => |o| if (@typeInfo(o.child) == .pointer) .pointer else .other,
        .@"struct" => .{ .@"struct" = @sizeOf(T) },
        else => .other,
    };
}

fn expectSameShape(comptime name: []const u8, comptime what: []const u8, comptime A: type, comptime B: type) void {
    const a = shapeOf(A);
    const b = shapeOf(B);
    if (!std.meta.eql(a, b) or a == .other) {
        @compileError(name ++ ": " ++ what ++ " mismatch: header has " ++ @typeName(A) ++ ", bindings have " ++ @typeName(B));
    }
}

fn checkFn(comptime name: []const u8, comptime HFn: type, comptime CFn: type) void {
    const hf = @typeInfo(HFn).@"fn";
    const cf = @typeInfo(CFn).@"fn";
    if (hf.param_types.len != cf.param_types.len) @compileError(name ++ ": parameter count mismatch");
    if (!std.meta.eql(hf.attrs.@"callconv", cf.attrs.@"callconv")) @compileError(name ++ ": calling convention mismatch");
    expectSameShape(name, "return type", hf.return_type.?, cf.return_type.?);
    for (hf.param_types, cf.param_types, 0..) |hp, cp, i| {
        expectSameShape(name, std.fmt.comptimePrint("parameter {d}", .{i}), hp.?, cp.?);
    }
}

fn checkStruct(comptime name: []const u8, comptime HS: type, comptime CS: type) void {
    const hs = @typeInfo(HS).@"struct";
    const cs = @typeInfo(CS).@"struct";
    if (hs.layout != .@"extern" or cs.layout != .@"extern") @compileError(name ++ ": expected extern structs");
    if (@sizeOf(HS) != @sizeOf(CS)) @compileError(name ++ ": size mismatch");
    if (hs.field_names.len != cs.field_names.len) @compileError(name ++ ": field count mismatch");
    for (hs.field_names, cs.field_names, hs.field_types, cs.field_types) |hname, cname, HF, CF| {
        if (!std.mem.eql(u8, hname, cname)) @compileError(name ++ ": field name mismatch: " ++ hname ++ " vs " ++ cname);
        if (@offsetOf(HS, hname) != @offsetOf(CS, cname)) @compileError(name ++ "." ++ hname ++ ": offset mismatch");
        // Callback fields are optional function pointers on both sides.
        if (@typeInfo(HF) == .optional and @typeInfo(@typeInfo(HF).optional.child) == .pointer and
            @typeInfo(@typeInfo(@typeInfo(HF).optional.child).pointer.child) == .@"fn")
        {
            checkFn(name ++ "." ++ hname, @typeInfo(@typeInfo(HF).optional.child).pointer.child, @typeInfo(@typeInfo(CF).optional.child).pointer.child);
        } else {
            expectSameShape(name ++ "." ++ hname, "field type", HF, CF);
        }
    }
}

fn isBtckName(comptime name: []const u8) bool {
    return std.mem.startsWith(u8, name, "btck_");
}

fn checkDecl(comptime name: []const u8) void {
    if (!@hasDecl(c, name)) @compileError("missing from bindings: " ++ name);
    const hv = @field(h, name);
    const cv = @field(c, name);
    const HT = @TypeOf(hv);
    if (@typeInfo(HT) == .@"fn") {
        checkFn(name, HT, @TypeOf(cv));
    } else if (HT == type) {
        switch (@typeInfo(hv)) {
            .@"opaque" => if (@typeInfo(cv) != .@"opaque") @compileError(name ++ ": expected opaque type"),
            .@"struct" => checkStruct(name, hv, cv),
            .int => if (hv != cv) @compileError(name ++ ": typedef mismatch"),
            .optional => {
                // Callback typedefs: optional function pointers.
                const HFn = @typeInfo(@typeInfo(hv).optional.child).pointer.child;
                const CFn = @typeInfo(@typeInfo(cv).optional.child).pointer.child;
                checkFn(name, HFn, CFn);
            },
            else => @compileError(name ++ ": unhandled type kind"),
        }
    } else {
        // Constants from `#define btck_X ((type)(value))`.
        if (@as(u64, hv) != @as(u64, cv)) {
            @compileError(std.fmt.comptimePrint("{s}: value mismatch: header {d}, bindings {d}", .{ name, hv, cv }));
        }
        if (@TypeOf(cv) != HT) @compileError(name ++ ": constant type mismatch");
    }
}

test "bindings match bitcoinkernel.h" {
    comptime {
        @setEvalBranchQuota(1_000_000);
        var header_count: usize = 0;
        for (std.meta.declarations(h)) |decl_name| {
            if (!isBtckName(decl_name)) continue;
            checkDecl(decl_name);
            header_count += 1;
        }
        // And nothing in the bindings that the header doesn't declare.
        for (std.meta.declarations(c)) |decl_name| {
            if (!isBtckName(decl_name)) continue;
            if (!@hasDecl(h, decl_name)) @compileError("not in header: " ++ decl_name);
        }
        if (header_count < 200) @compileError("suspiciously few declarations found in translated header");
    }
}
