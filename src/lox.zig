const std = @import("std");
const builtin = @import("builtin");

const Scanner = @import("Scanner.zig");
const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;

var had_error = false;

pub fn run(arena: *ArenaAllocator, source: []u8) !void {
    const ally = arena.allocator();
    var scanner = Scanner.init(ally, source);
    defer scanner.deinit();
    try scanner.scanTokens();
}

pub fn generateError(line: u16, message: []const u8) !void {
    try report(line, "", message);
}

pub fn report(line: u16, error_description: []const u8, message: []const u8) !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("[Line {d}] Error {s} : {s}", .{ line, error_description, message });
    had_error = true;
}

pub fn runPrompt(arena: *ArenaAllocator) !void {
    const ally = arena.allocator();
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    while (true) {
        const arena_state = arena.state; // Begin temporary mem
        defer arena.state = arena_state; // Reclaim on break (not that it really matters)

        try stdout.writeAll("> ");
        var line: []u8 = undefined;
        if (builtin.target.os.tag == .windows) {
            line = (try stdin.readUntilDelimiterOrEofAlloc(ally, '\r', 1024 * 4)) orelse unreachable;
            try stdin.skipBytes(1, .{}); // Eat newline
        } else if (builtin.target.os.tag == .linux) {
            line = (try stdin.readUntilDelimiterOrEofAlloc(ally, '\n', 1024 * 4)) orelse unreachable;
        }
        if (line.len == 0) break;
        try run(arena, line);
        had_error = false;

        arena.state = arena_state; // End temporary mem
    }
}

pub fn runFile(arena: *ArenaAllocator, path: []const u8) !void {
    const arena_state = arena.state;
    defer arena.state = arena_state;
    const ally = arena.allocator();

    const source_file = try std.fs.cwd().openFile(path, .{});
    defer source_file.close();
    const bytes = try source_file.readToEndAlloc(ally, 1024 * 5);

    try run(arena, bytes);
    if (had_error) std.process.exit(65);
}
