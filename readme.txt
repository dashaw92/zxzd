Preface: This project is born more out of a desire to make something with Zig, and less out of a need for the actual tools, though they are admittedly cool (in my opinion).

zx: zig he[x] editor
zd: zx back to [d]ecimal(-inator!)

The tools are designed to be work together, with zx providing output zd can understand; thus:
$ zx - | zd -
is a no-op.

Both tools accept a filename or - for stdin as the first argument.

Note: Both tools require matching compiled BUF_SIZE constants.
BUF_SIZE can be changed via the -Dbytes flag for zig build:
$ zig build -Doptimize=ReleaseFast -Dbytes=8 --summary all
yields binaries that work off chunks of 8 bytes. The default is 16 bytes.

The output format of zx is crafted with zd in mind, so care must be taken when modifying this. The comments detail requirements and assumptions zd makes.

License: since this project is mainly just busy-work, the MIT license applies here! :D Go nuts
