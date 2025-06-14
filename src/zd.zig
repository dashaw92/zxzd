const std = @import("std");
const shared = @import("shared");

pub fn main() !u8 {
    const path = shared.getArg() catch {
        std.log.err("Usage: zd [ - | path ]", .{});
        return 1;
    };

    assemble(path) catch |err| {
        std.log.err("zd: {}", .{err});
        return 1;
    };
    return 0;
}

//Re-assembles hex output from zx back into raw bytes.
//This code assumes that shared.BUF_SIZE is the same in both zx and zd.
//The assembler reads a single character from the input file (or stdin) at a time,
//maintaining a state machine that keeps a mental model of where in the input we are.
//zx output looks like:                                    vvvvvvvvvvvvvvvvvvv skipped
//00000000  68 65 6C 6C 6F 20 77 6F 72 6C 64 0A 00 00 00 00  hello.world.....\n
//^ skip  ^^~~ ~~ ~~ ~~ ~~ ~~ ~~ ~~ ~~ ~~ ~~ ~~ ~~ ~~ ~~ ~~> bytes to read and output
//        marker used to flag the beginning of bytes
//The program terminates once the first full 0x00 byte is read from the bytes in the input
fn assemble(path: [:0]const u8) !void {
    const file = try shared.getFileOrStdin(path);
    defer file.close();

    //Stores a single byte that is accumulated over two iterations before being written to stdout (the high and low bits are read separately).
    var buf: [1]u8 = [_]u8{0};
    var singleRead: [1]u8 = [_]u8{0};
    const out = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(out);
    const w = bw.writer();
    defer bw.flush() catch {};

    //Number of bytes, this will mark completion of the line (aka skip until next '\n')
    //when == to BUF_SIZE
    var readBytesOnLine: u8 = 0;
    //Last char read
    var last: u8 = undefined;
    //Are we reading the high bits of the hex value (the first hex char)?
    var highBits = true;
    //Remains false until the two " " (spaces) are encountered.
    var readyToReadBytes = false;
    //Flag to skip the very next read, resetting it to non-skipping immediately. All bytes have a single space between them.
    var skipNext = false;
    while (try file.read(&singleRead) != 0) {
        defer {
            last = singleRead[0];
            singleRead[0] = 0;
        }

        //Skip a single character. This is used to bypass the spaces
        //between bytes.
        if (skipNext) {
            skipNext = false;
            continue;
        }

        //Upon encountering the first set of double spaces, set the flag
        //enabling bytes to be read.
        if (readBytesOnLine == 0 and !readyToReadBytes and last == ' ' and singleRead[0] == ' ') {
            readyToReadBytes = true;
            continue;
        }

        //At the end of the line, reset all flags and continue to the next line of input.
        if (singleRead[0] == '\n') {
            readBytesOnLine = 0;
            last = undefined;
            highBits = true;
            readyToReadBytes = false;
            continue;
        }

        //Since we're not ready to read bytes, everything is skippable.
        if (!readyToReadBytes) continue;

        //Convert from ASCII to number
        const byte = hexCharToInt(singleRead[0]);

        if (highBits) {
            //hexToDec = 0xAB => A * 16^1 + B * 16^0
            buf[0] = byte * 16;
            //The next char read is the low bits of the byte
            highBits = false;
        } else {
            //Accumulate the low bits into the existing high bits
            buf[0] += byte;

            //If the finished byte is 0 (NULL/EOF), the file is finished.
            if (buf[0] == 0) break;

            //Finished reading this byte. Reset flags to begin next byte.
            skipNext = true;
            highBits = true;
            readBytesOnLine += 1;

            //If we've read the total available number of bytes, skip
            //until the next line begins.
            if (readBytesOnLine == shared.BUF_SIZE) {
                readyToReadBytes = false;
            }

            //Print the single byte out
            _ = try w.write(&buf);
        }
    }
}

fn hexCharToInt(hex: u8) u8 {
    return switch (hex) {
        //Numbers in ASCII are 0x30 through 0x39 inclusive.
        0x30...0x39 => hex - 0x30,
        //A through F. Add 0xA (10) to offset to the correct value
        0x41...0x46 => hex - 0x41 + 0xA,
        //If my state machine above is correct, this branch will never be hit.
        else => unreachable,
    };
}
