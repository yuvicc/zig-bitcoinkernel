const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const kernel_lib_dir = b.option(
        []const u8,
        "kernel-lib-dir",
        "Directory containing an installed libbitcoinkernel (implies -Dkernel=system)",
    );
    const kernel_source = b.option(
        KernelSource,
        "kernel",
        "Where libbitcoinkernel comes from (default: subtree, or system if -Dkernel-lib-dir is set)",
    ) orelse if (kernel_lib_dir != null) KernelSource.system else KernelSource.subtree;
    const kernel_static = b.option(
        bool,
        "kernel-static",
        "Link libbitcoinkernel statically (default: true for subtree, false for system)",
    ) orelse (kernel_source == .subtree);

    if (kernel_source == .subtree and kernel_lib_dir != null) {
        std.log.err("-Dkernel-lib-dir requires -Dkernel=system", .{});
        std.process.exit(1);
    }

    const mod = b.addModule("bitcoinkernel", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        // A static libbitcoinkernel needs the C++ standard library.
        .link_libcpp = if (kernel_static) true else null,
    });
    switch (kernel_source) {
        .subtree => linkSubtreeKernel(b, mod, target, kernel_static),
        .system => linkSystemKernel(b, mod, target, kernel_lib_dir, kernel_static),
    }

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
    // Regtest blocks from the upstream kernel test suite.
    integration_tests.root_module.addAnonymousImport("block_data.h", .{
        .root_source_file = b.path("depend/bitcoin/src/test/kernel/block_data.h"),
    });
    test_step.dependOn(&b.addRunArtifact(integration_tests).step);

    // Compile-time check that `src/c.zig` matches the upstream header.
    const translated_header = b.addTranslateC(.{
        .root_source_file = b.path("depend/bitcoin/src/kernel/bitcoinkernel.h"),
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

const KernelSource = enum {
    /// Build libbitcoinkernel from the Bitcoin Core subtree in depend/bitcoin with CMake.
    subtree,
    /// Link an already installed libbitcoinkernel.
    system,
};

/// Builds libbitcoinkernel from the Bitcoin Core subtree with CMake and links
/// it into `mod`. The CMake build directory lives in the local Zig cache and
/// is reused between runs, so only the first build compiles the kernel.
fn linkSubtreeKernel(
    b: *std.Build,
    mod: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    static: bool,
) void {
    if (!target.query.isNative()) {
        std.log.err("building libbitcoinkernel from the subtree only supports the native target; " ++
            "build it for the target yourself and use -Dkernel=system", .{});
        std.process.exit(1);
    }

    const build_dir = std.Build.LazyPath.cache_root.path(b, if (static) "bitcoinkernel/static" else "bitcoinkernel/shared");

    const configure = b.addSystemCommand(&.{ "cmake", "-S" });
    configure.setName("configure libbitcoinkernel");
    configure.addDirectoryArg(b.path("depend/bitcoin"));
    configure.addArg("-B");
    configure.addDirectoryArg(build_dir);
    configure.addArgs(&.{
        // Only show CMake warnings and errors, not the configure summary.
        "--log-level=WARNING",
        "-DCMAKE_BUILD_TYPE=Release",
        "-DCMAKE_INSTALL_LIBDIR=lib",
        "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
        if (static) "-DBUILD_SHARED_LIBS=OFF" else "-DBUILD_SHARED_LIBS=ON",
        "-DBUILD_KERNEL_LIB=ON",
        "-DBUILD_KERNEL_TEST=OFF",
        "-DBUILD_DAEMON=OFF",
        "-DBUILD_CLI=OFF",
        "-DBUILD_TX=OFF",
        "-DBUILD_UTIL=OFF",
        "-DBUILD_WALLET_TOOL=OFF",
        "-DBUILD_TESTS=OFF",
        "-DBUILD_BENCH=OFF",
        "-DBUILD_GUI=OFF",
        "-DENABLE_WALLET=OFF",
        "-DENABLE_IPC=OFF",
    });
    // CMake tracks its own inputs; always let it decide what is out of date.
    configure.has_side_effects = true;
    configure.expectExitCode(0); // capture output; it is shown on failure

    const jobs = std.Thread.getCpuCount() catch 4;
    const compile = b.addSystemCommand(&.{ "cmake", "--build" });
    compile.setName("build libbitcoinkernel");
    compile.addDirectoryArg(build_dir);
    compile.addArgs(&.{ "--target", "bitcoinkernel", "--parallel", b.fmt("{d}", .{jobs}) });
    compile.has_side_effects = true;
    compile.expectExitCode(0); // capture output; it is shown on failure
    compile.step.dependOn(&configure.step);

    const install = b.addSystemCommand(&.{ "cmake", "--install" });
    install.setName("install libbitcoinkernel");
    install.addDirectoryArg(build_dir);
    install.addArgs(&.{ "--component", "libbitcoinkernel", "--prefix" });
    const prefix = install.addOutputDirectoryArg("libbitcoinkernel");
    install.has_side_effects = true;
    install.expectExitCode(0); // capture output; it is shown on failure
    install.step.dependOn(&compile.step);

    const os = target.result.os.tag;
    const file_name = if (static)
        "lib/libbitcoinkernel.a"
    else if (os.isDarwin())
        "lib/libbitcoinkernel.dylib"
    else
        "lib/libbitcoinkernel.so";
    mod.addObjectFile(prefix.path(b, file_name));
    if (!static) mod.addRPath(prefix.path(b, "lib"));
}

/// Links an installed libbitcoinkernel into `mod`. When `lib_dir` is given,
/// the library file inside it is linked directly so that other copies on the
/// default search paths (e.g. /usr/local/lib) cannot shadow it.
fn linkSystemKernel(
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
