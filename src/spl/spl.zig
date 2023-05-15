const std = @import("std");

const stack_size = 4 * 1024;
var stack: [stack_size]u8 linksection(".bss.uninit") = undefined;

const mtime = @intToPtr(*volatile u64, 0x200_0000 + 0xBFF8);
const mtime_freq = 4_000_000;

pub export fn _start() linksection(".start") callconv(.Naked) noreturn {
    enableAllFeatures();

    if (getHartId() == 0) {
        setStackPointer(@ptrToInt(&stack) + stack_size);
        @call(.never_inline, main, .{});
    }

    while (true) {}
}

fn main() noreturn {
    uart0_writer.print("stack pointer: 0x{x}\r\n", .{@call(.always_inline, getStackPointer, .{})}) catch unreachable;
    for (0..1_000_000) |i| {
        uart0_writer.print("  counter: {d}, mtime: {d}\r\n", .{ i, mtime.* }) catch unreachable;
        delayMs(1000);
    }

    while (true) {}
}

fn delayMs(ms: u64) void {
    const end_tick = mtime.* + (ms * mtime_freq / 1_000);
    while (mtime.* < end_tick) {}
}

fn getHartId() u32 {
    return asm volatile (
        \\csrr t0, mhartid
        \\
        : [ret] "={t0}" (-> u32),
    );
}

// This is not necessary (at least to get stack and such set up).
// TODO: What does this enable exactly?
fn enableAllFeatures() void {
    // Copied from Oreboot.
    asm volatile (
    // Clear feature disable CSR to '0' to turn on all features
        \\csrwi  0x7c1, 0
        \\csrw   mie, zero
        \\csrw   mstatus, zero
        \\csrw   mtvec, zero
    );
}

fn setStackPointer(top: usize) void {
    asm volatile (
        \\
        :
        : [top] "{sp}" (top),
    );
}

fn getStackPointer() u64 {
    return asm volatile (
        \\
        : [ret] "={sp}" (-> u64),
    );
}

pub fn panic(message: []const u8, error_return_trace: ?*std.builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = message;
    _ = error_return_trace;
    _ = ret_addr;

    while (true) {}
}

const uart0_writer = Uart0Writer.Writer{ .context = .{} };

const Uart0Writer = struct {
    pub const Error = error{};
    pub const Writer = std.io.Writer(Uart0Writer, Error, write);

    fn write(self: Uart0Writer, buffer: []const u8) Error!usize {
        _ = self;

        uart0Write(buffer);
        return buffer.len;
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
};
