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

    // // TODO: REPLACE WITH Run STEP!
    // const spl_tool_step = SplToolStep.create(
    //     b,
    //     spl_tool_exe.getOutputSource(),
    //     obj_copy.getOutputSource(),
    //     "visionfive2.bin.normal.out",
    // );
    // b.getInstallStep().dependOn(&spl_tool_step.step);
    // b.getInstallStep().dependOn(&b.addInstallBinFile(spl_tool_step.getOutputSource(), "visionfive2.bin.normal.out").step);
}

// Based on impl of ObjCopy step.
const SplToolStep = struct {
    step: Build.Step,
    spl_tool_exe_source: Build.FileSource,
    file_source: Build.FileSource,
    basename: []const u8,
    output_file: Build.GeneratedFile,

    pub fn create(
        owner: *Build,
        spl_tool_exe_source: Build.FileSource,
        file_source: Build.FileSource,
        basename: []const u8,
    ) *SplToolStep {
        const self = owner.allocator.create(SplToolStep) catch @panic("OOM");
        self.* = .{
            .step = Build.Step.init(.{
                .id = .custom,
                .name = owner.fmt("spl_tool {s}", .{file_source.getDisplayName()}),
                .owner = owner,
                .makeFn = make,
            }),
            .spl_tool_exe_source = spl_tool_exe_source,
            .file_source = file_source,
            .basename = basename,
            .output_file = Build.GeneratedFile{ .step = &self.step },
        };
        spl_tool_exe_source.addStepDependencies(&self.step);
        file_source.addStepDependencies(&self.step);

        return self;
    }

    pub fn getOutputSource(self: *const SplToolStep) std.Build.FileSource {
        return .{ .generated = &self.output_file };
    }

    fn make(step: *Build.Step, prog_node: *std.Progress.Node) !void {
        _ = prog_node;

        const b = step.owner;
        const self = @fieldParentPtr(SplToolStep, "step", step);

        var man = b.cache.obtain();
        defer man.deinit();

        // Random bytes to make SplToolStep unique.
        // Refresh this with new random bytes when SplToolStep implementation
        // is modified incompatibly.
        man.hash.add(@as(u32, 0xdec3c104));

        const full_src_path = self.file_source.getPath(b);
        _ = try man.addFile(full_src_path, null);
        const full_exe_path = self.spl_tool_exe_source.getPath(b);
        _ = try man.addFile(full_exe_path, null);

        const cache_hit = try step.cacheHit(&man);

        const cache_dir_path = try b.cache_root.join(b.allocator, &.{ "o", &man.final() });
        const full_dest_path = try b.cache_root.join(b.allocator, &.{ cache_dir_path, self.basename });
        std.log.info("full dest path {s}", .{full_dest_path});
        self.output_file.path = full_dest_path;

        if (cache_hit) return;

        b.cache_root.handle.makePath(cache_dir_path) catch |err| {
            return step.fail("unable to make path {s}: {s}", .{ cache_dir_path, @errorName(err) });
        };

        try step.handleChildProcUnsupported(b.build_root.path, &.{
            self.spl_tool_exe_source.getPath(b),
            "-c",
            "-f",
            self.file_source.getPath(b),
            "-o",
            full_dest_path,
        });

        try man.writeManifest();
    }
};
