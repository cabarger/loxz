const std = @import("std");
const token = @import("token.zig");
const lox = @import("lox.zig");

const Allocator = std.mem.Allocator;
const ArenaAllocator = std.heap.ArenaAllocator;
const ArrayList = std.ArrayList;

const Token = token.Token;
const TokenType = token.TokenType;
const Literal = token.Literal;

const Scanner = @This();

const hashString = std.hash_map.hashString;

ally: Allocator,
tokens: ArrayList(Token),
source: []const u8,
keywords: std.AutoHashMap(u64, TokenType),
start: u16,
current: u16,
line: u16,

pub fn init(ally: Allocator, source: []const u8) Scanner {
    var keywords = std.AutoHashMap(u64, TokenType).init(ally);
    keywords.put(hashString("and"), .@"and") catch unreachable;
    keywords.put(hashString("class"), .class) catch unreachable;
    keywords.put(hashString("else"), .@"else") catch unreachable;
    keywords.put(hashString("false"), .false) catch unreachable;
    keywords.put(hashString("fun"), .fun) catch unreachable;
    keywords.put(hashString("for"), .@"for") catch unreachable;
    keywords.put(hashString("if"), .@"if") catch unreachable;
    keywords.put(hashString("nil"), .nil) catch unreachable;
    keywords.put(hashString("or"), .@"or") catch unreachable;
    keywords.put(hashString("print"), .print) catch unreachable;
    keywords.put(hashString("return"), .@"return") catch unreachable;
    keywords.put(hashString("super"), .super) catch unreachable;
    keywords.put(hashString("this"), .this) catch unreachable;
    keywords.put(hashString("true"), .true) catch unreachable;
    keywords.put(hashString("var"), .@"var") catch unreachable;
    keywords.put(hashString("while"), .@"while") catch unreachable;

    return Scanner{
        .ally = ally,
        .tokens = ArrayList(Token).init(ally),
        .source = source,
        .keywords = keywords,
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

fn addTokenWithLiteral(self: *Scanner, token_type: TokenType, literal: Literal) !void {
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

fn peekNext(self: *Scanner) u8 {
    if (self.current + 1 >= self.source.len)
        return 0;
    return self.source[self.current + 1];
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
        Literal{ .string = try self.ally.dupe(u8, self.source[self.start + 1 .. self.current - 1]) },
    );
}

fn identifier(self: *Scanner) !void {
    while (std.ascii.isAlphanumeric(self.peek()) or self.peek() == '_') _ = self.advance();

    var token_type = self.keywords.get(hashString(self.source[self.start..self.current]));
    if (token_type == null) token_type = .identifier;
    try self.addToken(token_type.?);
}

fn number(self: *Scanner) !void {
    while (std.ascii.isDigit(self.peek()))
        _ = self.advance();

    if (self.peek() == '.' and std.ascii.isDigit(self.peekNext())) {
        _ = self.advance(); // Consume '.'

        while (std.ascii.isDigit(self.peek()))
            _ = self.advance();
    }

    try self.addTokenWithLiteral(.number, Literal{
        .number = try std.fmt.parseFloat(f64, self.source[self.start..self.current]),
    });
}

fn scanToken(self: *Scanner) !void {
    const c = self.advance();
    switch (c) {
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

        '"' => try self.string(),
        '0'...'9' => try self.number(),
        'A'...'Z', 'a'...'z', '_' => try self.identifier(),

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
