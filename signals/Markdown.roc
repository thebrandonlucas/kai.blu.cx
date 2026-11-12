## Markdown as HTML, for the tour's steps, the guides and the changelog: the
## Markdown that `elm-explorations/markdown` rendered for the Elm site, with
## GitHub's tables and SmartyPants' quotes and dashes.
##
## Blocks: ATX headings, paragraphs, block quotes, fenced code, bullet and
## ordered lists (nested by indentation, tight or loose), thematic breaks,
## tables and, when HTML is allowed, HTML blocks. Inline: code spans,
## emphasis and strong emphasis, links, images, autolinks (`<url>` and bare
## `https://` links), backslash escapes, entities, hard line breaks and,
## when HTML is allowed, inline tags such as `<kbd>`.
##
## The result is HTML text, which `<kai-html>` (public/site-ports.mjs) puts
## on the page: roc-signals 0.5.0 draws a tree from data only to a depth
## fixed in the code, since a template inside a template has a context of
## its own type (see
## https://github.com/thebrandonlucas/roc-issues/tree/master/roc-signals/RS-013-data-depth-trees).
Markdown := [].{

	## Raw HTML in the source: passed through (the site's own pages), or
	## shown as text (the changelog, which comes from elsewhere).
	Html : [Allow, Escape]

	to_html : Str, Markdown.Html -> Str
	to_html = |source, html| render(lines_of(source), html, Bool.False)
}

## The source's lines, with tabs as four spaces.
lines_of : Str -> List(Str)
lines_of = |source| source.replace_each("\r\n", "\n").replace_each("\r", "\n").replace_each("\t", "    ").split_on("\n")

## Blocks. In a tight list item (`tight`), a paragraph is its text alone.
render : List(Str), Markdown.Html, Bool -> Str
render = |lines, html, tight| {
	var $out = ""
	var $i = 0
	while $i < lines.len() {
		block = next_block(lines, $i, html, tight)
		$out = $out.concat(block.out)
		$i = block.next
	}
	$out
}

Block : { out : Str, next : U64 }

next_block : List(Str), U64, Markdown.Html, Bool -> Block
next_block = |lines, i, html, tight| {
	line = lines.get(i) ?? ""
	if is_blank(line) {
		{ out: "", next: i + 1 }
	} else if indent_of(line) >= 4 {
		indented_code(lines, i)
	} else {
		match fence_of(line) {
			Ok(fence) => fenced_code(lines, i, fence)
			Err(_) =>
				match heading_of(line) {
					Ok({ level, text }) => {
						tag = "h${level.to_str()}"
						{ out: "<${tag}>${inline(text, html)}</${tag}>\n", next: i + 1 }
					}
					Err(_) =>
						if is_rule(line) {
							{ out: "<hr>\n", next: i + 1 }
						} else if quote_of(line).is_ok() {
							quote(lines, i, html)
						} else {
							match marker_of(line) {
								Ok(marker) => list(lines, i, marker, html)
								Err(_) =>
									if html == Allow and is_html_block(line) {
										html_block(lines, i)
									} else if is_table_start(lines, i) {
										table(lines, i, html)
									} else {
										paragraph(lines, i, html, tight)
									}
							}
						}
				}
		}
	}
}

# ---- Lines

is_blank : Str -> Bool
is_blank = |line| line.trim().is_empty()

indent_of : Str -> U64
indent_of = |line| {
	bytes = line.to_utf8()
	var $n = 0
	while $n < bytes.len() and (bytes.get($n) ?? 0) == ' ' {
		$n = $n + 1
	}
	$n
}

## `line` without up to `n` leading spaces.
dedent : Str, U64 -> Str
dedent = |line, n| {
	bytes = line.to_utf8()
	cut = indent_of(line).min(n)
	Str.from_utf8_lossy(bytes.drop_first(cut))
}

## A line that starts another block, so it ends a paragraph.
interrupts : Str, Markdown.Html -> Bool
interrupts = |line, html|
	is_blank(line)
	or fence_of(line).is_ok()
	or heading_of(line).is_ok()
	or is_rule(line)
	or quote_of(line).is_ok()
	or (html == Allow and is_html_block(line))
	or (
		match marker_of(line) {
			Ok(marker) => !is_blank(marker.rest) and (!marker.ordered or marker.start == 1)
			Err(_) => Bool.False
		}
	)

# ---- Headings and breaks

heading_of : Str -> Try({ level : U64, text : Str }, [NotHeading])
heading_of = |line|
	if indent_of(line) > 3 {
		Err(NotHeading)
	} else {
		trimmed = line.trim_start()
		bytes = trimmed.to_utf8()
		level = run_of(bytes, 0, '#')
		after = bytes.get(level) ?? ' '
		if level >= 1 and level <= 6 and (after == ' ' or level == bytes.len()) {
			text = Str.from_utf8_lossy(bytes.drop_first(level)).trim()
			# A closing run of #s, after a space, is not part of the text.
			Ok({ level, text: without_closing_hashes(text) })
		} else {
			Err(NotHeading)
		}
	}

## A heading's text without its closing run of `#`s.
without_closing_hashes : Str -> Str
without_closing_hashes = |text| {
	bytes = drop_trailing(text.to_utf8(), |b| b == '#')
	if bytes.is_empty() or (bytes.last() ?? 0) == ' ' Str.from_utf8_lossy(bytes).trim_end() else text
}

## How many `c`s there are in a row from `at`.
run_of : List(U8), U64, U8 -> U64
run_of = |bytes, at, c| {
	var $n = 0
	while (bytes.get(at + $n) ?? 0) == c {
		$n = $n + 1
	}
	$n
}

is_rule : Str -> Bool
is_rule = |line|
	if indent_of(line) > 3 {
		Bool.False
	} else {
		bytes = line.to_utf8().drop_if(|b| b == ' ')
		match bytes.first() {
			Ok(c) => (c == '-' or c == '*' or c == '_') and bytes.len() >= 3 and bytes.all(|b| b == c)
			Err(_) => Bool.False
		}
	}

# ---- Code

Fence : { char : U8, len : U64, indent : U64, info : Str }

fence_of : Str -> Try(Fence, [NotFence])
fence_of = |line| {
	indent = indent_of(line)
	bytes = line.to_utf8().drop_first(indent)
	char = bytes.first() ?? 0
	len = run_of(bytes, 0, char)
	info = Str.from_utf8_lossy(bytes.drop_first(len)).trim()
	if indent <= 3 and (char == '`' or char == '~') and len >= 3 and !(char == '`' and info.contains("`")) {
		Ok({ char, len, indent, info })
	} else {
		Err(NotFence)
	}
}

fenced_code : List(Str), U64, Fence -> Block
fenced_code = |lines, i, fence| {
	var $j = i + 1
	var $body = []
	var $open = Bool.True
	while $open and $j < lines.len() {
		line = lines.get($j) ?? ""
		closing = match fence_of(line) {
			Ok(other) => other.char == fence.char and other.len >= fence.len and other.info.is_empty()
			Err(_) => Bool.False
		}
		if closing {
			$open = Bool.False
		} else {
			$body = $body.append(dedent(line, fence.indent))
		}
		$j = $j + 1
	}
	language = match fence.info.split_on(" ").first() {
		Ok(word) if !word.is_empty() => " class=\"lang-${escape(word)}\""
		_ => ""
	}
	{ out: "<pre><code${language}>${escape(code_text($body))}</code></pre>\n", next: $j }
}

indented_code : List(Str), U64 -> Block
indented_code = |lines, i| {
	var $j = i
	var $body = []
	var $more = Bool.True
	while $more and $j < lines.len() {
		line = lines.get($j) ?? ""
		if indent_of(line) >= 4 or is_blank(line) {
			$body = $body.append(dedent(line, 4))
			$j = $j + 1
		} else {
			$more = Bool.False
		}
	}
	{ out: "<pre><code>${escape(code_text(trim_blank_end($body)))}</code></pre>\n", next: $j }
}

code_text : List(Str) -> Str
code_text = |lines| if lines.is_empty() "" else Str.join_with(lines, "\n").concat("\n")

trim_blank_end : List(Str) -> List(Str)
trim_blank_end = |lines| match lines.last() {
	Ok(last) if is_blank(last) => trim_blank_end(lines.drop_last(1))
	_ => lines
}

# ---- Quotes

quote_of : Str -> Try(Str, [NotQuote])
quote_of = |line|
	if indent_of(line) > 3 {
		Err(NotQuote)
	} else {
		trimmed = line.trim_start()
		if trimmed.starts_with("> ") {
			Ok(trimmed.drop_prefix("> "))
		} else if trimmed.starts_with(">") {
			Ok(trimmed.drop_prefix(">"))
		} else {
			Err(NotQuote)
		}
	}

quote : List(Str), U64, Markdown.Html -> Block
quote = |lines, i, html| {
	var $j = i
	var $inner = []
	var $more = Bool.True
	while $more and $j < lines.len() {
		line = lines.get($j) ?? ""
		match quote_of(line) {
			Ok(rest) => {
				$inner = $inner.append(rest)
				$j = $j + 1
			}
			Err(_) =>
				# A lazy continuation of the quote's last paragraph.
				if !interrupts(line, html) and !is_blank($inner.last() ?? "") {
					$inner = $inner.append(line)
					$j = $j + 1
				} else {
					$more = Bool.False
				}
		}
	}
	{ out: "<blockquote>\n${render($inner, html, Bool.False)}</blockquote>\n", next: $j }
}

# ---- Lists

## A list item's marker: `indent` spaces, the bullet or number, and the
## spaces after it, `width` in all; `rest` is the line after them.
Marker : { ordered : Bool, bullet : U8, start : U64, indent : U64, width : U64, rest : Str }

marker_of : Str -> Try(Marker, [NotMarker])
marker_of = |line| {
	indent = indent_of(line)
	bytes = line.to_utf8().drop_first(indent)
	first = bytes.first() ?? 0
	digits = digits_of(bytes)
	found =
		if first == '-' or first == '*' or first == '+' {
			Ok({ ordered: Bool.False, bullet: first, start: 1, len: 1 })
		} else if digits >= 1 and digits <= 9 and ((bytes.get(digits) ?? 0) == '.' or (bytes.get(digits) ?? 0) == ')') {
			number = bytes.take_first(digits).fold(0, |n, b| n * 10 + (b - '0').to_u64())
			Ok({ ordered: Bool.True, bullet: bytes.get(digits) ?? '.', start: number, len: digits + 1 })
		} else {
			Err(NotMarker)
		}
	match found {
		Ok(m) => {
			after = bytes.drop_first(m.len)
			spaces = run_of(after, 0, ' ')
			if indent > 3 {
				Err(NotMarker)
			} else if after.is_empty() {
				Ok({ ordered: m.ordered, bullet: m.bullet, start: m.start, indent, width: indent + m.len + 1, rest: "" })
			} else if spaces == 0 {
				Err(NotMarker)
			} else {
				# More than four spaces start indented code inside the item.
				gap = if spaces > 4 1 else spaces
				Ok({ ordered: m.ordered, bullet: m.bullet, start: m.start, indent, width: indent + m.len + gap, rest: Str.from_utf8_lossy(after.drop_first(gap)) })
			}
		}
		Err(e) => Err(e)
	}
}

digits_of : List(U8) -> U64
digits_of = |bytes| {
	var $n = 0
	while is_digit(bytes.get($n) ?? 0) {
		$n = $n + 1
	}
	$n
}

## Whether `next` continues the list `first` began.
same_list : Marker, Marker -> Bool
same_list = |first, next| next.ordered == first.ordered and next.bullet == first.bullet and next.indent < first.width

list : List(Str), U64, Marker, Markdown.Html -> Block
list = |lines, i, first, html| {
	var $j = i
	var $items = []
	var $loose = Bool.False
	var $more = Bool.True
	while $more {
		marker = marker_of(lines.get($j) ?? "") ?? first
		item = list_item(lines, $j, marker, html)
		$items = $items.append(item.lines)
		$loose = $loose or item.loose
		$j = item.next
		next = marker_of(lines.get($j) ?? "")
		$more = match next {
			Ok(other) if same_list(first, other) => Bool.True
			_ => Bool.False
		}
		# A blank line between two items makes the list loose.
		if $more and item.blank_after {
			$loose = Bool.True
		} else {
			{}
		}
	}
	tag = if first.ordered "ol" else "ul"
	start = if first.ordered and first.start != 1 " start=\"${first.start.to_str()}\"" else ""
	body = $items.fold("", |acc, item_lines| acc.concat("<li>${render_item(item_lines, html, !$loose)}</li>\n"))
	{ out: "<${tag}${start}>\n${body}</${tag}>\n", next: $j }
}

## A tight item is its text, then its other blocks on lines of their own.
render_item : List(Str), Markdown.Html, Bool -> Str
render_item = |lines, html, tight| {
	inner = render(lines, html, tight)
	if tight inner.drop_suffix("\n") else "\n${inner}"
}

Item : { lines : List(Str), next : U64, loose : Bool, blank_after : Bool }

list_item : List(Str), U64, Marker, Markdown.Html -> Item
list_item = |lines, i, marker, html| {
	var $body = [marker.rest]
	var $j = i + 1
	var $blank = Bool.False
	var $loose = Bool.False
	var $more = Bool.True
	while $more and $j < lines.len() {
		line = lines.get($j) ?? ""
		if is_blank(line) {
			$blank = Bool.True
			$body = $body.append("")
			$j = $j + 1
		} else if indent_of(line) >= marker.width {
			# A blank line between two of the item's own blocks makes it loose.
			if $blank and !is_blank(Str.join_with(trim_blank_end($body), "")) {
				$loose = $loose or !in_nested_list($body)
			} else {
				{}
			}
			$blank = Bool.False
			$body = $body.append(dedent(line, marker.width))
			$j = $j + 1
		} else if !$blank and !interrupts(line, html) and !is_rule(line) {
			# A lazy continuation of the item's paragraph.
			$body = $body.append(line.trim_start())
			$j = $j + 1
		} else {
			$more = Bool.False
		}
	}
	{ lines: trim_blank_end($body), next: $j, loose: $loose, blank_after: $blank }
}

## Whether the item's last block so far is a nested list, whose own blank
## lines make it loose and not the item.
in_nested_list : List(Str) -> Bool
in_nested_list = |body| match trim_blank_end(body).last() {
	Ok(last) => marker_of(last).is_ok() or indent_of(last) > 0
	Err(_) => Bool.False
}

# ---- Tables

is_table_start : List(Str), U64 -> Bool
is_table_start = |lines, i| {
	head = lines.get(i) ?? ""
	match aligns_of(lines.get(i + 1) ?? "") {
		Ok(aligns) => head.contains("|") and cells_of(head).len() == aligns.len()
		Err(_) => Bool.False
	}
}

Align : [Default, Left, Center, Right]

aligns_of : Str -> Try(List(Align), [NotDelimiter])
aligns_of = |line| {
	cells = cells_of(line)
	valid = !cells.is_empty() and line.contains("-") and cells.all(
		|cell| {
			core = cell.drop_prefix(":").drop_suffix(":")
			!core.is_empty() and core.to_utf8().all(|b| b == '-')
		},
	)
	if valid {
		Ok(
			cells.map(
				|cell|
					match (cell.starts_with(":"), cell.ends_with(":")) {
						(Bool.True, Bool.True) => Center
						(Bool.True, Bool.False) => Left
						(Bool.False, Bool.True) => Right
						(Bool.False, Bool.False) => Default
					},
			),
		)
	} else {
		Err(NotDelimiter)
	}
}

## A row's cells: split on `|`s that are not escaped or in code, without the
## outer pipes.
cells_of : Str -> List(Str)
cells_of = |line| {
	trimmed = line.trim()
	inner = trimmed.drop_prefix("|")
	bytes = (if inner.ends_with("\\|") inner else inner.drop_suffix("|")).to_utf8()
	var $cells = []
	var $cell = []
	var $code = Bool.False
	var $i = 0
	while $i < bytes.len() {
		b = bytes.get($i) ?? 0
		if b == '\\' and (bytes.get($i + 1) ?? 0) == '|' {
			$cell = $cell.append('|')
			$i = $i + 2
		} else {
			if b == '`' {
				$code = !$code
			} else {
				{}
			}
			if b == '|' and !$code {
				$cells = $cells.append(Str.from_utf8_lossy($cell).trim())
				$cell = []
			} else {
				$cell = $cell.append(b)
			}
			$i = $i + 1
		}
	}
	$cells.append(Str.from_utf8_lossy($cell).trim())
}

table : List(Str), U64, Markdown.Html -> Block
table = |lines, i, html| {
	aligns = aligns_of(lines.get(i + 1) ?? "") ?? []
	head = row("th", cells_of(lines.get(i) ?? ""), aligns, html)
	var $j = i + 2
	var $rows = ""
	while $j < lines.len() and !is_blank(lines.get($j) ?? "") and (lines.get($j) ?? "").contains("|") {
		$rows = $rows.concat(row("td", cells_of(lines.get($j) ?? ""), aligns, html))
		$j = $j + 1
	}
	body = if $rows.is_empty() "" else "<tbody>\n${$rows}</tbody>\n"
	{ out: "<table>\n<thead>\n${head}</thead>\n${body}</table>\n", next: $j }
}

row : Str, List(Str), List(Align), Markdown.Html -> Str
row = |tag, cells, aligns, html| {
	out = aligns.map_with_index(
		|align, n| {
			style = match align {
				Default => ""
				Left => " style=\"text-align:left\""
				Center => " style=\"text-align:center\""
				Right => " style=\"text-align:right\""
			}
			"<${tag}${style}>${inline(cells.get(n) ?? "", html)}</${tag}>"
		},
	)
	"<tr>\n${Str.join_with(out, "\n")}\n</tr>\n"
}

# ---- HTML blocks and paragraphs

## A line that opens an HTML block: a comment, or a block-level tag.
is_html_block : Str -> Bool
is_html_block = |line| {
	trimmed = line.trim_start()
	if indent_of(line) > 3 or !trimmed.starts_with("<") {
		Bool.False
	} else if trimmed.starts_with("<!--") {
		Bool.True
	} else {
		name = tag_name(trimmed.drop_prefix("<").drop_prefix("/"))
		block_tags.contains(name.with_ascii_lowercased())
	}
}

tag_name : Str -> Str
tag_name = |text| Str.from_utf8_lossy(take_while(text.to_utf8(), |b| is_alnum(b)))

block_tags : List(Str)
block_tags = ["address", "article", "aside", "blockquote", "details", "div", "dl", "figcaption", "figure", "footer", "h1", "h2", "h3", "h4", "h5", "h6", "header", "hr", "iframe", "img", "li", "main", "nav", "ol", "p", "picture", "pre", "section", "summary", "table", "ul", "video"]

html_block : List(Str), U64 -> Block
html_block = |lines, i| {
	var $j = i
	var $out = ""
	while $j < lines.len() and !is_blank(lines.get($j) ?? "") {
		$out = $out.concat(lines.get($j) ?? "").concat("\n")
		$j = $j + 1
	}
	{ out: $out, next: $j }
}

paragraph : List(Str), U64, Markdown.Html, Bool -> Block
paragraph = |lines, i, html, tight| {
	var $j = i + 1
	var $text = [(lines.get(i) ?? "").trim_start()]
	while $j < lines.len() and !interrupts(lines.get($j) ?? "", html) {
		$text = $text.append((lines.get($j) ?? "").trim_start())
		$j = $j + 1
	}
	content = inline(Str.join_with($text, "\n").trim_end(), html)
	{ out: if tight "${content}\n" else "<p>${content}</p>\n", next: $j }
}

# ---- Inline

inline : Str, Markdown.Html -> Str
inline = |text, html| Str.from_utf8_lossy(inline_bytes(text.to_utf8(), html))

## The HTML of a run of inline Markdown.
inline_bytes : List(U8), Markdown.Html -> List(U8)
inline_bytes = |bytes, html| {
	var $out = List.with_capacity(bytes.len() + bytes.len() // 4)
	var $i = 0
	while $i < bytes.len() {
		found = span_at(bytes, $i, html)
		$out = $out.concat(found.out)
		$i = found.next
	}
	$out
}

Span : { out : List(U8), next : U64 }

## The span that starts at `i`: a construct, or one character.
span_at : List(U8), U64, Markdown.Html -> Span
span_at = |bytes, i, html| {
	c = bytes.get(i) ?? 0
	prev = if i == 0 ' ' else bytes.get(i - 1) ?? ' '
	plain = { out: escape_byte(c), next: i + 1 }
	when_none = |attempt| attempt ?? plain
	if c == '\\' {
		next = bytes.get(i + 1) ?? 0
		if next == '\n' {
			{ out: "<br>\n".to_utf8(), next: i + 2 }
		} else if is_punct(next) {
			{ out: escape_byte(next), next: i + 2 }
		} else {
			plain
		}
	} else if c == '`' {
		code_span(bytes, i)
	} else if c == '*' or c == '_' {
		when_none(emphasis(bytes, i, html))
	} else if c == '!' and (bytes.get(i + 1) ?? 0) == '[' {
		when_none(link(bytes, i + 1, html, Image))
	} else if c == '[' {
		when_none(link(bytes, i, html, Link))
	} else if c == '<' {
		when_none(angle(bytes, i, html))
	} else if c == '&' {
		when_none(entity(bytes, i))
	} else if c == 'h' and !is_alnum(prev) {
		when_none(bare_url(bytes, i))
	} else if c == ' ' {
		spaces = run_of(bytes, i, ' ')
		if spaces >= 2 and (bytes.get(i + spaces) ?? 0) == '\n' {
			{ out: "<br>\n".to_utf8(), next: i + spaces + 1 }
		} else if (bytes.get(i + spaces) ?? 0) == '\n' {
			{ out: [], next: i + spaces }
		} else {
			plain
		}
	} else if c == '-' and (bytes.get(i + 1) ?? 0) == '-' {
		if (bytes.get(i + 2) ?? 0) == '-' {
			{ out: "—".to_utf8(), next: i + 3 }
		} else {
			{ out: "–".to_utf8(), next: i + 2 }
		}
	} else if c == '.' and (bytes.get(i + 1) ?? 0) == '.' and (bytes.get(i + 2) ?? 0) == '.' {
		{ out: "…".to_utf8(), next: i + 3 }
	} else if c == '"' {
		{ out: (if opens(prev) "“" else "”").to_utf8(), next: i + 1 }
	} else if c == '\'' {
		{ out: (if opens(prev) "‘" else "’").to_utf8(), next: i + 1 }
	} else {
		plain
	}
}

## Whether a quote after `prev` opens (SmartyPants' rule).
opens : U8 -> Bool
opens = |prev| prev == ' ' or prev == '\n' or prev == '(' or prev == '[' or prev == '{' or prev == '-' or prev == '>'

code_span : List(U8), U64 -> Span
code_span = |bytes, i| {
	len = run_of(bytes, i, '`')
	start = i + len
	match closing_ticks(bytes, start, len) {
		Ok(end) => {
			raw = Str.from_utf8_lossy(bytes.sublist({ start, len: end - start })).replace_each("\n", " ")
			trimmed = if raw.starts_with(" ") and raw.ends_with(" ") and !raw.trim().is_empty() raw.drop_prefix(" ").drop_suffix(" ") else raw
			{ out: "<code>${escape(trimmed)}</code>".to_utf8(), next: end + len }
		}
		Err(_) => { out: bytes.sublist({ start: i, len }), next: start }
	}
}

## Where a run of exactly `len` backticks starts, from `from` on.
closing_ticks : List(U8), U64, U64 -> Try(U64, [NotFound])
closing_ticks = |bytes, from, len| {
	var $at = from
	var $found = Bool.False
	while !$found and $at < bytes.len() {
		if (bytes.get($at) ?? 0) == '`' {
			run = run_of(bytes, $at, '`')
			if run == len {
				$found = Bool.True
			} else {
				$at = $at + run
			}
		} else {
			$at = $at + 1
		}
	}
	if $found Ok($at) else Err(NotFound)
}

## `*em*`, `**strong**` and `***both***`, or with `_`. An underscore inside a
## word is a character, not emphasis.
emphasis : List(U8), U64, Markdown.Html -> Try(Span, [NotEmphasis])
emphasis = |bytes, i, html| {
	c = bytes.get(i) ?? 0
	prev = if i == 0 ' ' else bytes.get(i - 1) ?? ' '
	run = run_of(bytes, i, c)
	after = bytes.get(i + run) ?? ' '
	if is_space(after) or (c == '_' and is_alnum(prev)) {
		Err(NotEmphasis)
	} else {
		tries = if run >= 3 [3, 2, 1] else if run == 2 [2, 1] else [1]
		tries.fold_until(
			Err(NotEmphasis),
			|_, n|
				match closing_delimiter(bytes, i + n, c, n) {
					Ok(end) => {
						inner = inline_bytes(bytes.sublist({ start: i + n, len: end - i - n }), html)
						open = match n {
							3 => "<strong><em>"
							2 => "<strong>"
							_ => "<em>"
						}
						close = match n {
							3 => "</em></strong>"
							2 => "</strong>"
							_ => "</em>"
						}
						Break(Ok({ out: open.to_utf8().concat(inner).concat(close.to_utf8()), next: end + n }))
					}
					Err(_) => Continue(Err(NotEmphasis))
				},
		)
	}
}

## Where the delimiter run of `n` `c`s that closes one opened before `from`
## starts. Code spans and longer runs are stepped over.
closing_delimiter : List(U8), U64, U8, U64 -> Try(U64, [NotFound])
closing_delimiter = |bytes, from, c, n| {
	var $at = from
	var $found = Bool.False
	var $end = 0
	while !$found and $at < bytes.len() {
		b = bytes.get($at) ?? 0
		if b == '`' {
			len = run_of(bytes, $at, '`')
			$at = match closing_ticks(bytes, $at + len, len) {
				Ok(end) => end + len
				Err(_) => $at + len
			}
		} else if b == '\\' {
			$at = $at + 2
		} else if b == c {
			run = run_of(bytes, $at, c)
			before = bytes.get($at - 1) ?? ' '
			after = bytes.get($at + run) ?? ' '
			closes = $at > from and !is_space(before) and !(c == '_' and is_alnum(after))
			if closes and (run == n or (n == 1 and run == 3) or (n == 2 and run == 3)) {
				$found = Bool.True
				$end = if run > n $at + run - n else $at
			} else {
				{}
			}
			$at = $at + run
		} else {
			$at = $at + 1
		}
	}
	if $found Ok($end) else Err(NotFound)
}

## `[text](url "title")`, or `![alt](src)` from the `[`.
link : List(U8), U64, Markdown.Html, [Link, Image] -> Try(Span, [NotLink])
link = |bytes, i, html, kind| {
	match matching(bytes, i, '[', ']') {
		Ok(close) if (bytes.get(close + 1) ?? 0) == '(' =>
			match matching(bytes, close + 1, '(', ')') {
				Ok(end) => {
					label = bytes.sublist({ start: i + 1, len: close - i - 1 })
					target = Str.from_utf8_lossy(bytes.sublist({ start: close + 2, len: end - close - 2 })).trim()
					{ url, title } = destination(target)
					title_attr = if title.is_empty() "" else " title=\"${escape(title)}\""
					out = match kind {
						Link => "<a href=\"${escape(url)}\"${title_attr}>${Str.from_utf8_lossy(inline_bytes(label, html))}</a>"
						Image => "<img src=\"${escape(url)}\" alt=\"${escape(Str.from_utf8_lossy(label))}\"${title_attr}>"
					}
					Ok({ out: out.to_utf8(), next: end + 1 })
				}
				Err(_) => Err(NotLink)
			}
		_ => Err(NotLink)
	}
}

## A link's destination and its optional title.
destination : Str -> { url : Str, title : Str }
destination = |target| {
	unwrapped = |url| if url.starts_with("<") and url.ends_with(">") url.drop_prefix("<").drop_suffix(">") else url
	match target.split_first(" ") {
		Ok({ before, after }) => {
			title = after.trim()
			quoted = (title.starts_with("\"") and title.ends_with("\"")) or (title.starts_with("'") and title.ends_with("'"))
			if quoted and title.count_utf8_bytes() >= 2 {
				{ url: unwrapped(before), title: Str.from_utf8_lossy(title.to_utf8().drop_first(1).drop_last(1)) }
			} else {
				{ url: unwrapped(target), title: "" }
			}
		}
		Err(_) => { url: unwrapped(target), title: "" }
	}
}

## The index of the bracket that closes the one at `i`.
matching : List(U8), U64, U8, U8 -> Try(U64, [NotFound])
matching = |bytes, i, open, close| {
	var $depth = 0
	var $at = i
	var $found = Bool.False
	while !$found and $at < bytes.len() {
		b = bytes.get($at) ?? 0
		if b == '\\' {
			$at = $at + 2
		} else if b == open {
			$depth = $depth + 1
			$at = $at + 1
		} else if b == close and $depth == 1 {
			$found = Bool.True
		} else if b == close {
			$depth = $depth - 1
			$at = $at + 1
		} else {
			$at = $at + 1
		}
	}
	if $found Ok($at) else Err(NotFound)
}

## `<https://...>` and, when HTML is allowed, an inline tag or comment.
angle : List(U8), U64, Markdown.Html -> Try(Span, [NotAngle])
angle = |bytes, i, html|
	match bytes.drop_first(i + 1).find_first_index(|b| b == '>') {
		Ok(len) => {
			inside = Str.from_utf8_lossy(bytes.sublist({ start: i + 1, len }))
			next = i + len + 2
			if (inside.starts_with("http://") or inside.starts_with("https://") or inside.starts_with("mailto:")) and !inside.contains(" ") {
				shown = inside.drop_prefix("mailto:")
				Ok({ out: "<a href=\"${escape(inside)}\">${escape(shown)}</a>".to_utf8(), next })
			} else {
				first = inside.to_utf8().first() ?? 0
				tag = is_alpha(first) or (first == '/' and is_alpha(inside.to_utf8().get(1) ?? 0)) or inside.starts_with("!--")
				if html == Allow and tag {
					Ok({ out: bytes.sublist({ start: i, len: len + 2 }), next })
				} else {
					Err(NotAngle)
				}
			}
		}
		Err(_) => Err(NotAngle)
	}

## `&amp;`, `&#8212;`, `&#x2014;`: passed through as they are.
entity : List(U8), U64 -> Try(Span, [NotEntity])
entity = |bytes, i| {
	name = take_while(bytes.drop_first(i + 1), |b| is_alnum(b) or b == '#')
	if !name.is_empty() and (bytes.get(i + 1 + name.len()) ?? 0) == ';' {
		Ok({ out: bytes.sublist({ start: i, len: name.len() + 2 }), next: i + name.len() + 2 })
	} else {
		Err(NotEntity)
	}
}

## A bare `https://` or `http://` link, without the punctuation that ends a
## sentence.
bare_url : List(U8), U64 -> Try(Span, [NotUrl])
bare_url = |bytes, i| {
	rest = bytes.drop_first(i)
	if rest.starts_with("https://".to_utf8()) or rest.starts_with("http://".to_utf8()) {
		whole = take_while(rest, |b| !is_space(b) and b != '<')
		url = Str.from_utf8_lossy(drop_trailing(whole, |b| b == '.' or b == ',' or b == ':' or b == ';' or b == ')' or b == '"' or b == '\'' or b == '!' or b == '?'))
		Ok({ out: "<a href=\"${escape(url)}\">${escape(url)}</a>".to_utf8(), next: i + url.count_utf8_bytes() })
	} else {
		Err(NotUrl)
	}
}

# ---- Bytes

escape : Str -> Str
escape = |text| Str.from_utf8_lossy(text.to_utf8().fold([], |acc, b| acc.concat(escape_byte(b))))

escape_byte : U8 -> List(U8)
escape_byte = |b|
	match b {
		'&' => "&amp;".to_utf8()
		'<' => "&lt;".to_utf8()
		'>' => "&gt;".to_utf8()
		'"' => "&quot;".to_utf8()
		_ => [b]
	}

take_while : List(U8), (U8 -> Bool) -> List(U8)
take_while = |bytes, keep| bytes.take_first(bytes.find_first_index(|b| !keep(b)) ?? bytes.len())

drop_trailing : List(U8), (U8 -> Bool) -> List(U8)
drop_trailing = |bytes, drop| match bytes.last() {
	Ok(b) if drop(b) => drop_trailing(bytes.drop_last(1), drop)
	_ => bytes
}

is_space : U8 -> Bool
is_space = |b| b == ' ' or b == '\n'

is_digit : U8 -> Bool
is_digit = |b| b >= '0' and b <= '9'

is_alpha : U8 -> Bool
is_alpha = |b| (b >= 'a' and b <= 'z') or (b >= 'A' and b <= 'Z')

## Letters and digits, and every byte of a non-ASCII character.
is_alnum : U8 -> Bool
is_alnum = |b| is_alpha(b) or is_digit(b) or b >= 128

is_punct : U8 -> Bool
is_punct = |b| (b >= '!' and b <= '/') or (b >= ':' and b <= '@') or (b >= '[' and b <= '`') or (b >= '{' and b <= '~')

expect Markdown.to_html("# Upon This Roc", Allow) == "<h1>Upon This Roc</h1>\n"
expect Markdown.to_html("a *b* **c** `d`", Allow) == "<p>a <em>b</em> <strong>c</strong> <code>d</code></p>\n"
expect Markdown.to_html("snake_case_name", Allow) == "<p>snake_case_name</p>\n"
expect Markdown.to_html("[Roc](https://www.roc-lang.org) and \"Kai's\"", Allow) == "<p><a href=\"https://www.roc-lang.org\">Roc</a> and “Kai’s”</p>\n"
expect Markdown.to_html("- a\n- b\n  - c", Allow) == "<ul>\n<li>a</li>\n<li>b\n<ul>\n<li>c</li>\n</ul></li>\n</ul>\n"
expect Markdown.to_html("1. a\n\n2. b", Allow) == "<ol>\n<li>\n<p>a</p>\n</li>\n<li>\n<p>b</p>\n</li>\n</ol>\n"
expect Markdown.to_html("> *Power!*\n>\n> [Join.](x)", Allow) == "<blockquote>\n<p><em>Power!</em></p>\n<p><a href=\"x\">Join.</a></p>\n</blockquote>\n"
expect Markdown.to_html("```sh\nnix run\n```", Allow) == "<pre><code class=\"lang-sh\">nix run\n</code></pre>\n"
expect Markdown.to_html("| a | b |\n|---|:-:|\n| 1 | `x|y` |", Allow) == "<table>\n<thead>\n<tr>\n<th>a</th>\n<th style=\"text-align:center\">b</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>1</td>\n<td style=\"text-align:center\"><code>x|y</code></td>\n</tr>\n</tbody>\n</table>\n"
expect Markdown.to_html("press <kbd>j</kbd>", Allow) == "<p>press <kbd>j</kbd></p>\n"
expect Markdown.to_html("press <kbd>j</kbd>", Escape) == "<p>press &lt;kbd&gt;j&lt;/kbd&gt;</p>\n"
expect Markdown.to_html("one -- two --- three...", Allow) == "<p>one – two — three…</p>\n"
expect Markdown.to_html("see https://kai.blu.cx.", Allow) == "<p>see <a href=\"https://kai.blu.cx\">https://kai.blu.cx</a>.</p>\n"
expect Markdown.to_html("a\n\n---\n\nb", Allow) == "<p>a</p>\n<hr>\n<p>b</p>\n"
