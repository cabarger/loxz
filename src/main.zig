const std = @import("std");
const lox = @import("lox.zig");

const ArenaAllocator = std.heap.ArenaAllocator;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const args = try std.process.argsAlloc(arena.allocator());
    if (args.len > 2) {
        try stdout.writeAll("Usage: loxz [script]\n");
        std.process.exit(64);
    } else if (args.len == 2) {
        try lox.runFile(&arena, args[0]);
    } else {
        try lox.runPrompt(&arena);
    }
}
