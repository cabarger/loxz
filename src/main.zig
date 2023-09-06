const std = @import("std");

const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;

const Token = struct {};

const Scanner = struct {
    ally: std.mem.Allocator,

    pub fn init(ally: std.mem.Allocator) Scanner {
        return Scanner{
            .ally = ally,
        };
    }

    pub fn scanTokens(self: *Scanner, source: []u8) ArrayList(Token) {
        _ = source;
        return ArrayList(Token).init(self.ally);
    }
};

fn run(arena: *ArenaAllocator, source: []u8) !void {
    var scanner = Scanner.init(arena.allocator());
    const tokens = scanner.scanTokens(source);
    _ = tokens;
}

fn runPrompt(arena: *ArenaAllocator) !void {
    const ally = arena.allocator();
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    while (true) {
        const arena_state = arena.state; // Begin temporary mem
        defer arena.state = arena_state; // Reclaim on break (not that it really matters)

        try stdout.writeAll("> ");
        var line = (try stdin.readUntilDelimiterOrEofAlloc(ally, '\r', 1024 * 4)) orelse unreachable;
        try stdin.skipBytes(1, .{}); // Eat newline
        if (line.len == 0) break;
        try run(arena, line);

        arena.state = arena_state; // End temporary mem
    }
}

fn runFile(arena: *ArenaAllocator, path: []const u8) !void {
    const arena_state = arena.state;
    defer arena.state = arena_state;
    const ally = arena.allocator();

    const source_file = try std.fs.cwd().openFile(path, .{});
    defer source_file.close();
    const bytes = try source_file.readToEndAlloc(ally, 1024 * 5);

    try run(arena, bytes);
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const args = try std.process.argsAlloc(arena.allocator());
    for (args) |asdf| std.debug.print("{s}\n", .{asdf});
    if (args.len > 2) {
        try stdout.writeAll("Usage: loxz [script]\n");
        std.process.exit(1);
    } else if (args.len == 2) {
        try runFile(&arena, args[0]);
    } else {
        try runPrompt(&arena);
    }
}
