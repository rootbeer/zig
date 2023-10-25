const std = @import("std");

pub fn build(b: *std.Build) void {
    const test_step = b.step("test", "Test");
    b.default_step = test_step;

    for ([_][]const u8{ "aarch64-linux-gnu.2.27", "aarch64-linux-gnu.2.34" }) |t| {
        const exe = b.addExecutable(.{
            .name = t,
            .root_source_file = .{ .path = "main.c" },
            .target = std.zig.CrossTarget.parse(
                .{ .arch_os_abi = t },
            ) catch unreachable,
        });
        exe.linkLibC();
        // TODO: actually test the output
        _ = exe.getEmittedBin();
        test_step.dependOn(&exe.step);
    }

    // Build & run against a sampling of supported glibc versions
    for ([_][]const u8{
        //"native-native-gnu.2.0",
        //"native-native-gnu.2.1.1",
        //"native-native-gnu.2.10", // pre-2.16 don't have getauxval(), which start.zig uses
        "native-native-gnu.2.16",
        "native-native-gnu.2.23",
        "native-native-gnu.2.28",
        "native-native-gnu.2.33",
        "native-native-gnu.2.38",
        "native-native-gnu",
    }) |t| {
        const exe = b.addExecutable(.{
            .name = t,
            .root_source_file = .{ .path = "glibc_runtime_check.zig" },
            .target = std.zig.CrossTarget.parse(
                .{ .arch_os_abi = t },
            ) catch unreachable,
        });
        exe.linkLibC();

        const run_cmd = b.addRunArtifact(exe);
        run_cmd.expectExitCode(0);

        test_step.dependOn(&run_cmd.step);
    }

}
