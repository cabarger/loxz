const std = @import("std");
const token = @import("token.zig");
const lox = @import("lox.zig");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;

const Token = token.Token;
const TokenType = token.TokenType;

const Scanner = @This();

ally: Allocator,
tokens: ArrayList(Token),
source: []const u8,
start: u16,
current: u16,
line: u16,

pub fn init(ally: Allocator, source: []const u8) Scanner {
    return Scanner{
        .ally = ally,
        .tokens = ArrayList(Token).init(ally),
        .source = source,
        .start = 0,
        .current = 0,
        .line = 1,
    };
}

pub fn deinit(self: *Scanner) void {
    self.tokens.deinit();
}

fn advance(self: *Scanner) u8 {
    const result = self.source[self.current];
    self.current += 1;
    return result;
}

fn isAtEnd(self: *Scanner) bool {
    return self.current >= self.source.len;
}

fn addToken(self: *Scanner, token_type: TokenType) !void {
    try self.tokens.append(Token{
        .type = token_type,
        .lexeme = try self.ally.dupe(u8, self.source[self.start..self.current]),
        .literal = null,
        .line = self.line,
    });
}

fn addTokenWithLiteral(self: *Scanner, token_type: TokenType, literal: []const u8) !void {
    try self.tokens.append(Token{
        .type = token_type,
        .lexeme = try self.ally.dupe(u8, self.source[self.start..self.current]),
        .literal = literal,
        .line = self.line,
    });
}

fn match(self: *Scanner, expected: u8) bool {
    if (self.isAtEnd()) return false;
    if (self.source[self.current] != expected) return false;

    self.current += 1;
    return true;
}

fn peek(self: *Scanner) u8 {
    if (self.isAtEnd())
        return 0;
    return self.source[self.current];
}

fn string(self: *Scanner) !void {
    while (self.peek() != '"' and !self.isAtEnd()) {
        if (self.peek() == '\n')
            self.line += 1;
        _ = self.advance();
    }

    if (self.isAtEnd()) {
        try lox.generateError(self.line, "Unterminated string.");
        return;
    }

    _ = self.advance(); // Closing '"'

    try self.addTokenWithLiteral(
        .string,
        try self.ally.dupe(
            u8,
            self.source[self.start + 1 .. self.current - 1],
        ),
    );
}

fn scanToken(self: *Scanner) !void {
    switch (self.advance()) {
        // Single-character tokens.
        '(' => try self.addToken(.left_paren),
        ')' => try self.addToken(.right_paren),
        '{' => try self.addToken(.left_brace),
        '}' => try self.addToken(.right_brace),
        ',' => try self.addToken(.comma),
        '.' => try self.addToken(.dot),
        '-' => try self.addToken(.minus),
        '+' => try self.addToken(.plus),
        ';' => try self.addToken(.semicolon),
        '*' => try self.addToken(.star),
        '/' => {
            if (self.match('/')) {
                while (self.peek() != '\n' and !self.isAtEnd())
                    _ = self.advance();
            } else {
                try self.addToken(.slash);
            }
        },
        ' ', '\r', '\t' => {},
        '\n' => self.line += 1,

        // One or two character tokens.
        '!' => try self.addToken(if (self.match('=')) .bang_equal else .bang),
        '=' => try self.addToken(if (self.match('=')) .equal_equal else .equal),
        '>' => try self.addToken(if (self.match('=')) .greater_equal else .greater),
        '<' => try self.addToken(if (self.match('=')) .less_equal else .less),

        // Strings
        '"' => try self.string(),

        else => try lox.generateError(self.line, "Unexpected character."),
    }
}

pub fn scanTokens(self: *Scanner) !void {
    while (!self.isAtEnd()) {
        self.start = self.current;
        try self.scanToken();
    }
    // EOF token
    try self.tokens.append(Token{ .type = .eof, .lexeme = "", .literal = null, .line = self.line });
}
