const std = @import("std");
const File = std.fs.File;

pub const BUF_SIZE = 16;

/// Get the first argument provided on the command line, skipping
/// the executable's entry (the actual first argument).
pub fn getArg() ![:0]const u8 {
    var args = std.process.args();
    _ = args.skip();
    if (args.next()) |path| {
        return path;
    } else {
        return error.NoArgument;
    }
}

/// Get a relative file from the CWD or stdin if `-` is provided.
pub fn getFileOrStdin(path: [:0]const u8) !File {
    // If the user provided `-` to the program, use stdin as the file
    // to read instead of a file from disk.
    if (std.mem.eql(u8, path, "-")) {
        return std.io.getStdIn();
    }

    // Try to get the file at the provided path (relative paths allowed)
    // or log and return the error.
    return std.fs.cwd().openFile(path, .{}) catch {
        return error.FileNotFound;
    };
}
