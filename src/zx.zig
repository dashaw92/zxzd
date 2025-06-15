const std = @import("std");
const shared = @import("shared");
const BUF_SIZE = @import("build_options").buf_size;

pub fn main() !u8 {
    const path = shared.getArg() catch {
        std.log.err("Usage: zx [ - | path ]", .{});
        return 1;
    };

    dump(path) catch |err| {
        std.log.err("zx: {}", .{err});
        return 1;
    };
    return 0;
}

//Dumps a hex-editor-esque view of the provided file (or stdin).
//The format is designed for use with the companion utility zd, so please
//maintain the format if you wish to re-assemble the bytes again.
//Specifically, this means ensuring that:
// [1] A pair of spaces ("  ") exists at the beginning of the line
// [2] All bytes are two hex characters (0xAB, etc)
// [3] Total number of bytes per line == BUF_SIZE (-Dbytes)
// [4] All bytes are separated by a single space " "
// [5] All lines are terminated with '\n'
// [6] To pad lines to match BUF_SIZE bytes, offsets beyond the file's EOF are '**'.
//
//Example output (parenthesis = not printed):
// (Offset)  (Bytes)                                          (ASCII without non-printables)
// 00000000  68 65 6C 6C 6F 20 77 6F 72 6C 64 0A ** ** ** **  hello.world.....(\n)
//         ^   ^                           ^^    ^^                            ^
//       [1]   [4]                         [2]   [6]                           [5]
// [3] Total number of bytes printed on this line = 16; BUF_SIZE defaults to 16. Therefore, this line is valid.
fn dump(path: [:0]const u8) !void {
    const file = try shared.getFileOrStdin(path);
    defer file.close();

    //Implements the chunked view of the provided file, with each
    //chunk printed on a line, representing a total of BUF_SIZE bytes
    //per chunk.
    var buf: [BUF_SIZE]u8 = [_]u8{0} ** BUF_SIZE;
    //Maintain the current offset into the file
    var idx: u32 = 0;
    const out = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(out);
    const w = bw.writer();
    defer bw.flush() catch {};

    while (true) : (idx += BUF_SIZE) {
        const count = try file.read(&buf);
        if (count == 0) break;
        //zd doesn't use the index at all, it's just for convenience, so it's ok if
        //the index overflows the width provided here.
        try std.fmt.format(w, "{X:0>8}  ", .{idx});

        //Print each individual byte, suffixing non-terminal bytes with a single space (important)
        //zd depends on the single space. Could be reworked to not need it, but the output
        //is easier to read with it, so this single space is currently required.
        for (0..BUF_SIZE) |i| {
            //To signify the end of the file, zx will pad the line to BUF_SIZE bytes
            //via `**` instead of valid hex. This allows the output to remain symmetrical
            //for byte counts that are not multiples of BUF_SIZE while retaining the ability
            //for zd to easily re-assemble the output.
            if (i >= count) {
                try std.fmt.format(w, "**{s}", .{if (i == BUF_SIZE - 1) "" else " "});
            } else {
                try std.fmt.format(w, "{X:0>2}{s}", .{ buf[i], if (i == BUF_SIZE - 1) "" else " " });
            }
        }

        //Not required, but makes the output more symmetrical. zd never considers anything except for \n
        //once the number of bytes read matches BUF_SIZE.
        _ = try w.write("  ");

        //Finish the line with the ASCII representation of the chunk, replacing non-printable
        //characters with a single '.'
        //zd doesn't care about this, and only requires a single \n at the end of the line once all
        //bytes are read from the chunk.
        for (0..BUF_SIZE) |i| {
            //Note: <= 32, not < 32 because space is 0x20 (32). While it's printable, it's
            //invisible, so it's kinda useless to even display it in the ASCII column anyways. </opinion>
            //Regarding the `**` padding for beyond EOF: As the original buf is not touched, and is further
            //reset to 0 (below) on every iteration, once the file has been fully read, the remaining bytes
            //on the line will be 0, and this will print a '.'. This could be changed to also
            //account for no further bytes, but as this column is ASCII, finding a single character
            //to represent "this isn't actually in the file" is more difficult than continuing the pattern
            //of displaying unprintable characters as '.'.
            try std.fmt.format(w, "{c}", .{if (buf[i] <= 32 or buf[i] > 126) '.' else buf[i]});

            //Clear the buf as we go so the end of the file is printed as 0 correctly.
            buf[i] = 0;
        }

        //Required for zd.
        _ = try w.write("\n");
    }
}
