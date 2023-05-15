const std = @import("std");

pub export fn _start() linksection(".start") callconv(.Naked) noreturn {
    if (getHartId() == 1) @call(.never_inline, main, .{});

    while (true) {}
}

fn getHartId() u32 {
    return asm volatile (
        \\csrr t0, mhartid
        \\
        : [ret] "={t0}" (-> u32),
    );
}

fn main() void {
    uart0Write("Hello, world and friends!\r\n");
}

pub fn panic(message: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = message;
    _ = error_return_trace;
    _ = ret_addr;

    while (true) {}
}

const uart0_base = 0x1000_0000;
const uart0_THR = @intToPtr(*volatile u32, uart0_base + 0x0000);
const uart0_LSR = @intToPtr(*volatile u32, uart0_base + 0x0014);

fn uart0Write(string: []const u8) void {
    for (string) |byte| {
        uart0WriteByte(byte);
    }
}

fn uart0WriteByte(byte: u8) void {
    while ((uart0_LSR.* & 0x20) == 0) {}
    uart0_THR.* = byte;
}
