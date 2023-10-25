// A zig test case that exercises some glibc symbols that have uncovered
// problems in the past.  This test must be compiled against a glibc.
//
// This only tests that valid symbols are linked.  It does not test that
// symbols are not present when that is expected (e.g., that
// "reallocarray" is not present before v2.26, etc).
//
// This does cannot test if the symbols are actually dynamically linked
// (i.e., that they're not erroneously statically linked).

const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

const c_malloc = @cImport(
    @cInclude("malloc.h"), // for reallocarray
);

const c_stdlib = @cImport(
    @cInclude("stdlib.h"), // for atexit
);

// Grab the version of glibc targetted by Zig
const major = builtin.target.os.version_range.linux.glibc.major;
const minor = builtin.target.os.version_range.linux.glibc.minor;

// PR #17034 - fstat moved between libc_nonshared and libc
fn checkStat() !void {
    var cwdFd = std.fs.cwd().fd;

    var stat = std.mem.zeroes(std.c.Stat);
    var result = std.c.fstatat(cwdFd, "a_file_that_definitely_does_not_exist", &stat, 0);
    assert(result == -1);
    assert(std.c.getErrno(result) == .NOENT);

    result = std.c.stat("a_file_that_definitely_does_not_exist", &stat);
    assert(result == -1);
    assert(std.c.getErrno(result) == .NOENT);
}

// PR #17607 - reallocarray not visible in headers
inline fn checkReallocarray() !void {
    // reallocarray was introduced in v2.26
    if (major > 2 or (major == 2 and minor >= 26)) {
        return try checkReallocarray_v2_26();
    }
}

fn checkReallocarray_v2_26() !void {
    const size = 16;
    var tenX = c_malloc.reallocarray(c_malloc.NULL, 10, size);
    var elevenX = c_malloc.reallocarray(tenX, 11, size);

    // std.debug.print("reallocarray {?p} -> {?p}\n", .{ tenX, elevenX });

    assert(tenX != c_malloc.NULL);
    assert(elevenX != c_malloc.NULL);

}

// getauxval introduced in v2.16
inline fn checkGetAuxVal() !void {
    if (major > 2 or (major == 2 and minor >= 16)) {
        try checkGetAuxVal_v2_16();
    }
}

fn checkGetAuxVal_v2_16() !void {
    var base = std.c.getauxval(std.elf.AT_BASE);
    var pgsz = std.c.getauxval(std.elf.AT_PAGESZ);

    //std.debug.print("auxval [BASE]={x} [PAGESZ]={x}\n", .{base, pgsz});

    assert(base != 0);
    assert(pgsz != 0);
}

// atexit is part of libc_nonshared, so ensure its linked in correctly
fn noopExitCallback() callconv(.C) void {
    return;
}

fn checkAtExit() !void {
    // Can't really test this works ...
    const result = c_stdlib.atexit(noopExitCallback);
    assert(result == 0);
}


pub fn main() !u8 {
    //std.debug.print("compiled against glibc v{}\n", .{ builtin.target.os.version_range.linux.glibc });

    try checkStat();
    try checkReallocarray();

    try checkGetAuxVal();
    try checkAtExit();

    std.c.exit(0);
}
