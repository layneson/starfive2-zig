const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
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
        .basename = "visionfive2.bin",
        .format = .bin,
    });
    const copy_bin = b.addInstallFileWithDir(.{ .generated = &obj_copy.output_file }, .bin, "visionfive2.bin");
    copy_bin.step.dependOn(&obj_copy.step);
    b.getInstallStep().dependOn(&copy_bin.step);

    const spl_tool_exe = b.addExecutable(.{
        .name = "spl_tool",
        .target = .{},
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    spl_tool_exe.addCSourceFiles(&.{
        "tools/starfive-tech-Tools/spl_tool/spl_tool.c",
        "tools/starfive-tech-Tools/spl_tool/crc32.c",
    }, &.{
        "-Wall", "-Wno-unused-result",
    });

    const spl_tool_step = b.addRunArtifact(spl_tool_exe);
    spl_tool_step.addArgs(&.{ "-c", "-f" });
    spl_tool_step.addFileSourceArg(obj_copy.getOutputSource());
    spl_tool_step.addArg("-o");
    const spl_tool_output = spl_tool_step.addOutputFileArg("visionfive2.bin.normal.out");
    b.getInstallStep().dependOn(&spl_tool_step.step);
    b.getInstallStep().dependOn(&b.addInstallBinFile(spl_tool_output, "visionfive2.bin.normal.out").step);

    const vf2_recover_exe = b.addExecutable(.{
        .name = "vf2-recover",
        .target = .{},
        .optimize = .ReleaseSafe,
        .link_libc = true,
    });
    vf2_recover_exe.addCSourceFiles(&.{
        "tools/JH71xx-tools/vf2-recover.c",
    }, &.{
        "-Wall",
    });
    b.installArtifact(vf2_recover_exe);
}
