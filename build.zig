const std = @import("std");
const Build = std.Build;

pub fn build(b: *Build) void {
    const target = .{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .eabi,
    };
    const optimize = b.standardOptimizeOption(.{});

    const spl_exe_name = "spl";
    const spl_exe_bin_name = "spl.bin";
    const spl_exe_headerified_name = "spl.bin.normal.out";

    const spl_exe = b.addExecutable(.{
        .name = spl_exe_name,
        .root_source_file = .{ .path = "src/spl/spl.zig" },
        .target = target,
        .optimize = optimize,
    });
    spl_exe.setLinkerScriptPath(.{ .path = "src/spl/spl.ld" });
    b.installArtifact(spl_exe);

    const obj_copy = spl_exe.addObjCopy(.{
        .basename = spl_exe_bin_name,
        .format = .bin,
    });
    const copy_bin = b.addInstallFileWithDir(.{ .generated = &obj_copy.output_file }, .bin, spl_exe_bin_name);
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
    const spl_tool_output = spl_tool_step.addOutputFileArg(spl_exe_headerified_name);
    b.getInstallStep().dependOn(&spl_tool_step.step);
    b.getInstallStep().dependOn(&b.addInstallBinFile(spl_tool_output, spl_exe_headerified_name).step);

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
