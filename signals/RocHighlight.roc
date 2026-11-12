## Syntax highlighting for Roc, one line at a time: comments, strings (with
## `${...}` interpolation), keywords, tags and types, function calls, numbers
## and punctuation. Good enough for Kaifiles; it doesn't parse Roc. Ported
## from `src/RocHighlight.elm`.
RocHighlight := [].{

	## A run of a line and its class (`""` for plain text).
	Token : { class : Str, text : Str }

	## One line of Roc as highlighted tokens.
	line : Str -> List(RocHighlight.Token)
	line = |source| tokens(source.to_utf8())
}

Kind : [Comment, Text, Interp, Keyword, Tag, Call, Number, Punct, Plain]

class_of : Kind -> Str
class_of = |kind|
	match kind {
		Comment => "tok-comment"
		Text => "tok-string"
		Interp => "tok-interp"
		Keyword => "tok-keyword"
		Tag => "tok-tag"
		Call => "tok-call"
		Number => "tok-number"
		Punct => "tok-punct"
		Plain => ""
	}

keywords : List(Str)
keywords = ["app", "platform", "package", "module", "import", "exposing", "as", "if", "else", "match", "when", "is", "expect", "dbg", "crash", "var", "for", "in", "return", "and", "or", "not", "requires", "provides", "packages", "exposes", "targets"]

token : Kind, List(U8) -> RocHighlight.Token
token = |kind, bytes| { class: class_of(kind), text: Str.from_utf8_lossy(bytes) }

tokens : List(U8) -> List(RocHighlight.Token)
tokens = |bytes| {
	var $out = []
	var $i = 0
	while $i < bytes.len() {
		c = bytes.get($i) ?? 0
		rest = bytes.drop_first($i)
		if c == '#' {
			$out = $out.append(token(Comment, rest))
			$i = bytes.len()
		} else if c == '"' {
			body = string_body(rest.drop_first(1))
			$out = $out.append(token(Text, ['"'])).concat(body.parts)
			$i = $i + 1 + body.len
			if body.closed {
				$out = $out.append(token(Text, ['"']))
				$i = $i + 1
			} else {
				{}
			}
		} else if is_digit(c) {
			digits = take_while(rest, |d| is_alnum(d) or d == '.' or d == '_')
			$out = $out.append(token(Number, digits))
			$i = $i + digits.len()
		} else if is_alpha(c) or c == '_' or c == '$' {
			word = take_while(rest, |d| is_alnum(d) or d == '_' or d == '!' or d == '$')
			$out = $out.append(token(word_kind(word, bytes.get($i + word.len()) ?? 0), word))
			$i = $i + word.len()
		} else if c == ' ' or c == '\t' {
			spaces = take_while(rest, |d| d == ' ' or d == '\t')
			$out = $out.append(token(Plain, spaces))
			$i = $i + spaces.len()
		} else {
			# One character, whole: a byte of a longer UTF-8 character would not be text.
			len = if c < 128 1 else take_while(rest.drop_first(1), |d| d >= 128 and d < 192).len() + 1
			$out = $out.append(token(Punct, rest.take_first(len)))
			$i = $i + len
		}
	}
	$out
}

word_kind : List(U8), U8 -> Kind
word_kind = |word, after| {
	first = word.first() ?? 0
	if keywords.contains(Str.from_utf8_lossy(word)) {
		Keyword
	} else if first >= 'A' and first <= 'Z' {
		Tag
	} else if after == '(' {
		Call
	} else {
		Plain
	}
}

## A string's body up to its closing quote: plain runs and `${...}`
## interpolations, as tokens in order, how many bytes they took (the closing
## quote not counted) and whether there was one.
string_body : List(U8) -> { parts : List(RocHighlight.Token), len : U64, closed : Bool }
string_body = |bytes| {
	var $parts = []
	var $run = []
	var $i = 0
	var $closed = Bool.False
	while !$closed and $i < bytes.len() {
		c = bytes.get($i) ?? 0
		if c == '\\' and $i + 1 < bytes.len() {
			$run = $run.append(c).append(bytes.get($i + 1) ?? 0)
			$i = $i + 2
		} else if c == '"' {
			$closed = Bool.True
		} else if c == '$' and (bytes.get($i + 1) ?? 0) == '{' {
			inner = take_while(bytes.drop_first($i + 2), |d| d != '}')
			$parts = flush($parts, $run).append(token(Interp, ['$', '{'].concat(inner).append('}')))
			$run = []
			$i = $i + 3 + inner.len()
		} else {
			$run = $run.append(c)
			$i = $i + 1
		}
	}
	{ parts: flush($parts, $run), len: $i.min(bytes.len()), closed: $closed }
}

flush : List(RocHighlight.Token), List(U8) -> List(RocHighlight.Token)
flush = |parts, run| if run.is_empty() parts else parts.append(token(Text, run))

take_while : List(U8), (U8 -> Bool) -> List(U8)
take_while = |bytes, keep| bytes.take_first(bytes.find_first_index(|b| !keep(b)) ?? bytes.len())

is_digit : U8 -> Bool
is_digit = |b| b >= '0' and b <= '9'

is_alpha : U8 -> Bool
is_alpha = |b| (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z')

is_alnum : U8 -> Bool
is_alnum = |b| is_alpha(b) or is_digit(b)

expect RocHighlight.line("Task(\"build\", [Run([\"roc\"])]) # go") == [
	{ class: "tok-tag", text: "Task" },
	{ class: "tok-punct", text: "(" },
	{ class: "tok-string", text: "\"" },
	{ class: "tok-string", text: "build" },
	{ class: "tok-string", text: "\"" },
	{ class: "tok-punct", text: "," },
	{ class: "", text: " " },
	{ class: "tok-punct", text: "[" },
	{ class: "tok-tag", text: "Run" },
	{ class: "tok-punct", text: "(" },
	{ class: "tok-punct", text: "[" },
	{ class: "tok-string", text: "\"" },
	{ class: "tok-string", text: "roc" },
	{ class: "tok-string", text: "\"" },
	{ class: "tok-punct", text: "]" },
	{ class: "tok-punct", text: ")" },
	{ class: "tok-punct", text: "]" },
	{ class: "tok-punct", text: ")" },
	{ class: "", text: " " },
	{ class: "tok-comment", text: "# go" },
]
expect RocHighlight.line("x = \"\${a}!\"") == [
	{ class: "", text: "x" },
	{ class: "", text: " " },
	{ class: "tok-punct", text: "=" },
	{ class: "", text: " " },
	{ class: "tok-string", text: "\"" },
	{ class: "tok-interp", text: "\${a}" },
	{ class: "tok-string", text: "!" },
	{ class: "tok-string", text: "\"" },
]
expect RocHighlight.line("import main! 42") == [
	{ class: "tok-keyword", text: "import" },
	{ class: "", text: " " },
	{ class: "", text: "main!" },
	{ class: "", text: " " },
	{ class: "tok-number", text: "42" },
]
