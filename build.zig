const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = .{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .eabi,
    };
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "visionfive2",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.setLinkerScriptPath(.{ .path = "visionfive2.ld" });
    b.installArtifact(exe);

    const obj_copy = exe.addObjCopy(.{
        .basename = "visionfive2",
        .format = .bin,
    });
    const copy_bin = b.addInstallFileWithDir(.{ .generated = &obj_copy.output_file }, .bin, "visionfive2.bin");
    copy_bin.step.dependOn(&obj_copy.step);
    b.getInstallStep().dependOn(&copy_bin.step);
}
