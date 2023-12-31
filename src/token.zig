pub const TokenType = enum {
    // Single-character tokens.
    left_paren,
    right_paren,
    left_brace,
    right_brace,
    comma,
    dot,
    minus,
    plus,
    semicolon,
    slash,
    star,

    // One or two character tokens.
    bang,
    bang_equal,
    equal,
    equal_equal,
    greater,
    greater_equal,
    less,
    less_equal,

    // Literals.
    identifier,
    string,
    number,

    // keywords.
    @"and",
    class,
    @"else",
    false,
    fun,
    @"for",
    @"if",
    nil,
    @"or",
    print,
    @"return",
    super,
    this,
    true,
    @"var",
    @"while",

    eof,
};

pub const LiteralType = enum {
    string,
    number,
};

pub const Literal = union(LiteralType) {
    string: []const u8,
    number: f64,
};

pub const Token = struct {
    type: TokenType,
    lexeme: []const u8,
    literal: ?Literal,
    line: u16,
};
