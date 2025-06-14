Preface: This project is born more out of a desire to make something with Zig, and less out of a need for the actual tools, though they are admittedly cool (in my opinion).

zx: zig he[x] editor
zd: zx back to [d]ecimal(-inator!)

The tools are designed to be work together, with zx providing output zd can understand; thus:
$ zx - | zd -
is a no-op.

Both tools accept a filename or - for stdin as the first argument.

Note: The 16 bytes-per-line format is hardcoded only in shared.zig via BUF_SIZE; both tools are coded around this constant, and consequently require both tools to have matching compiled constants.
i.e.: a zx compiled with BUF_SIZE = 8 will not work with a zd compiled with BUF_SIZE = 16.

The output format of zx is crafted with zd in mind, so care must be taken when modifying this. The comments detail requirements and assumptions zd makes.

License: since this project is mainly just busy-work, the MIT license applies here! :D Go nuts
