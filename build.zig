const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //code shared between zx and zd
    const shared_lib = b.createModule(.{
        .root_source_file = b.path("src/shared.zig"),
        .target = target,
        .optimize = optimize,
    });

    //Insert zx and zd into the compile graph
    //Note: Do not factor target and optimize out into add_exe; these functions
    //are somehow impure in that calling them more than once in build.zig
    //results in a compilation error. It's annoying, but passing them
    //here is required for this.
    //TODO: Is there a way to read arguments (easily!) from zig build
    //to conditionally compile only one? Nitpicky and not needed.
    add_exe(b, target, optimize, shared_lib, "zx", "src/zx.zig");
    add_exe(b, target, optimize, shared_lib, "zd", "src/zd.zig");
}

//Helper to de-duplicate code for including multiple binaries in a single Zig project.
//b, target, optimize: boilerplate required args to hook into the build system
//shared_lib: src/shared.zig module
//exe: name of the binary
//path: source file
fn add_exe(b: *std.Build, target: anytype, optimize: anytype, shared_lib: anytype, exe: []const u8, path: []const u8) void {
    const mod = b.createModule(.{
        .root_source_file = b.path(path),
        .target = target,
        .optimize = optimize,
    });

    //Attach the shared lib module to this binary
    mod.addImport("shared", shared_lib);

    //boilerplate
    const b_exe = b.addExecutable(.{
        .name = exe,
        .root_module = mod,
    });

    b.installArtifact(b_exe);
    const run_cmd = b.addRunArtifact(b_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step(exe, path);
    run_step.dependOn(&run_cmd.step);
}
