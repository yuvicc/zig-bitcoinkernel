const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const kernel_lib_dir = b.option(
        []const u8,
        "kernel-lib-dir",
        "Directory containing libbitcoinkernel. Defaults to searching the system library paths.",
    );
    const kernel_static = b.option(
        bool,
        "kernel-static",
        "Link libbitcoinkernel statically (default: false, link the shared library)",
    ) orelse false;

    const mod = b.addModule("bitcoinkernel", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        // A static libbitcoinkernel needs the C++ standard library.
        .link_libcpp = if (kernel_static) true else null,
    });
    linkKernel(b, mod, target, kernel_lib_dir, kernel_static);

    const test_step = b.step("test", "Run all tests");

    // Unit tests embedded in the library sources.
    const unit_tests = b.addTest(.{ .root_module = mod });
    test_step.dependOn(&b.addRunArtifact(unit_tests).step);

    // Integration tests against the kernel library.
    const integration_tests = b.addTest(.{
        .name = "kernel-tests",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/kernel_tests.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "bitcoinkernel", .module = mod }},
        }),
    });
    test_step.dependOn(&b.addRunArtifact(integration_tests).step);

    // Compile-time check that `src/c.zig` matches the upstream header.
    const translated_header = b.addTranslateC(.{
        .root_source_file = b.path("include/bitcoinkernel.h"),
        .target = target,
        .optimize = optimize,
    });
    const conformance_tests = b.addTest(.{
        .name = "header-conformance",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/header_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "bitcoinkernel", .module = mod },
                .{ .name = "bitcoinkernel_h", .module = translated_header.createModule() },
            },
        }),
    });
    test_step.dependOn(&b.addRunArtifact(conformance_tests).step);

    // Examples.
    const examples_step = b.step("examples", "Build the examples");
    inline for (.{"verify_script"}) |name| {
        const exe = b.addExecutable(.{
            .name = name,
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/" ++ name ++ ".zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{.{ .name = "bitcoinkernel", .module = mod }},
            }),
        });
        const install = b.addInstallArtifact(exe, .{});
        examples_step.dependOn(&install.step);

        const run = b.addRunArtifact(exe);
        run.addPassthruArgs();
        b.step("run-" ++ name, "Run the " ++ name ++ " example").dependOn(&run.step);
    }
}

/// Links libbitcoinkernel into `mod`. When `lib_dir` is given, the library
/// file inside it is linked directly so that other copies on the default
/// search paths (e.g. /usr/local/lib) cannot shadow it.
fn linkKernel(
    b: *std.Build,
    mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    lib_dir: ?[]const u8,
    static: bool,
) void {
    const os = target.result.os.tag;
    if (lib_dir) |dir| {
        if (os != .windows) {
            const file_name = if (static)
                "libbitcoinkernel.a"
            else if (os.isDarwin())
                "libbitcoinkernel.dylib"
            else
                "libbitcoinkernel.so";
            mod.addObjectFile(.{ .cwd_relative = b.pathJoin(&.{ dir, file_name }) });
            if (!static) mod.addRPath(.{ .cwd_relative = dir });
            return;
        }
        mod.addLibraryPath(.{ .cwd_relative = dir });
    }
    mod.linkSystemLibrary("bitcoinkernel", .{
        .preferred_link_mode = if (static) .static else .dynamic,
        .search_strategy = .mode_first,
    });
}
