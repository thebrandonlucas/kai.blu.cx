import pf.Engine exposing [Elem, In, Signal, State]
import Markdown
import RocHighlight

## A file the page shows, fetched by the window that shows it, and the ways
## it is shown: Markdown, a Roc file highlighted, any other file with line
## numbers, a terminal session, a text sketch. Ported from `fileView` and
## the views after it in `src/Main.elm`.
Files := [].{

	Loaded : [Loading, Loaded(Str), Failed(Str)]

	## The file at `url` (fetched again when it changes), drawn by `render`
	## once it is here; `name` names it in an error.
	view : Signal(ctx, Str), Signal(ctx, Str), (Signal(In(ctx, Files.Loaded), Str) -> Elem(In(ctx, Files.Loaded))) -> Elem(ctx)
	view = |url, name, render|
		Engine.state(
			Loading,
			|file| {
				loaded = file.signal()
				Engine.element(
					"div",
					[Engine.class("file")],
					[
						Engine.watch(url.lift(), |at| [Http({ method: "GET", url: at, headers: [], body: "", timeout_ms: 30000 })], file.on_result(arrived)),
						Engine.switch(
							loaded.map(stage),
							["loading", "loaded", "failed"],
							|found| match found {
								"loaded" => render(loaded.map(|l| match l { Loaded(text) => text, _ => "" }))
								"failed" => Engine.element("p", [Engine.class("error")], [Engine.text_s(name.lift().map2(loaded, |n, l| match l { Failed(why) => "${n}: ${why}", _ => "" }))])
								_ => Engine.element("p", [Engine.class("loading")], [Engine.text("…")])
							},
						),
					],
				)
			},
		)

	## Markdown, as the Elm site's `Markdown.toHtmlWith` drew it.
	markdown : Markdown.Html -> (Signal(ctx, Str) -> Elem(ctx))
	markdown = |html| |source| Files.html(source.map(|text| Markdown.to_html(text, html)), "md")

	## HTML made by the app, in an element of class `class`: `<kai-html>`
	## (public/site-ports.mjs) sets it as its contents.
	html : Signal(ctx, Str), Str -> Elem(ctx)
	html = |content, class| Engine.element("kai-html", [Engine.class(class), Engine.attr_s("html", content)], [])

	## A Roc file with line numbers and syntax highlighting. The app header's
	## package URLs are long and the same in every Kaifile, so the header is
	## folded to one line (hover for the URLs); the numbers stay the file's.
	code : Signal(ctx, Str) -> Elem(ctx)
	code = |source| lines_view(source.map(|text| roc_lines(1, text.trim_end().split_on("\n"))))

	## Any other file, with line numbers and no highlighting.
	plain_code : Signal(ctx, Str) -> Elem(ctx)
	plain_code = |source| lines_view(source.map(|text| text.trim_end().split_on("\n").map_with_index(|l, i| plain_line(i + 1, l))))

	## A text sketch standing in for a picture: as written, no line numbers.
	figure : Signal(ctx, Str) -> Elem(ctx)
	figure = |source| Engine.element("pre", [Engine.class("code figure")], [Engine.text_s(source.map(|text| text.trim_end()))])

	## A recorded session: lines starting with `$ ` are commands, shown after
	## a gold prompt; everything else is output.
	terminal : Signal(ctx, Str) -> Elem(ctx)
	terminal = |source|
		Engine.element(
			"pre",
			[Engine.class("term")],
			[
				Engine.each(
					source.map(|text| text.trim_end().split_on("\n").map_with_index(|l, i| { key: i.to_str(), command: l.starts_with("$ "), text: l.drop_prefix("$ ") })),
					|l| l.key,
					# A row is one element, so output is a span of no class.
					|row|
						Engine.element(
							"span",
							[Engine.class_s(row.field(|l| if l.command "term-cmd" else ""))],
							[
								Engine.when(row.field(|l| l.command), || Engine.element("span", [Engine.class("term-prompt")], [Engine.text("❯ ")]), || Engine.text("")),
								Engine.text_s(row.field(|l| "${l.text}\n")),
							],
						),
				),
			],
		)
}

stage : Files.Loaded -> Str
stage = |loaded|
	match loaded {
		Loading => "loading"
		Loaded(_) => "loaded"
		Failed(_) => "failed"
	}

arrived : Files.Loaded, Str, Engine.Result -> Files.Loaded
arrived = |_, _, result|
	match Engine.http_text(result) {
		Ok(text) => Loaded(text)
		Err(Status(code)) => Failed("HTTP ${code.to_str()}")
		Err(Timeout) => Failed("timed out")
		Err(Network(_)) => Failed("network error")
		Err(Refused) => Failed("too many requests at once")
	}

## A line of a file: its number, its tokens and, for a folded app header,
## the lines it hides.
Line : { key : Str, number : Str, tokens : List(Token), fold : Str }

Token : { key : Str, class : Str, text : Str }

keyed : List(RocHighlight.Token) -> List(Token)
keyed = |tokens| tokens.map_with_index(|t, i| { key: i.to_str(), class: t.class, text: t.text })

plain_line : U64, Str -> Line
plain_line = |n, text| { key: n.to_str(), number: n.to_str(), tokens: [{ key: "0", class: "", text }], fold: "" }

roc_lines : U64, List(Str) -> List(Line)
roc_lines = |n, lines|
	match lines {
		[] => []
		[first, .. as rest] =>
			if first.starts_with("app [") and first.ends_with("{") {
				body = rest.take_first(rest.find_first_index(|l| l.trim() == "}") ?? rest.len())
				after = rest.drop_first(body.len() + 1)
				folded = Str.join_with(body.map(|l| l.trim()), "\n")
				line = { key: n.to_str(), number: n.to_str(), tokens: keyed(RocHighlight.line(first.drop_suffix("{"))), fold: folded }
				[line].concat(roc_lines(n + body.len() + 2, after))
			} else {
				[{ key: n.to_str(), number: n.to_str(), tokens: keyed(RocHighlight.line(first)), fold: "" }].concat(roc_lines(n + 1, rest))
			}
	}

lines_view : Signal(ctx, List(Line)) -> Elem(ctx)
lines_view = |lines|
	Engine.element(
		"pre",
		[Engine.class("code")],
		[
			Engine.each(
				lines,
				|l| l.key,
				|row|
					Engine.element(
						"span",
						[Engine.class("code-line")],
						[
							Engine.element("span", [Engine.class("ln")], [Engine.text_s(row.field(|l| l.number))]),
							Engine.each(row.field(|l| l.tokens), |t| t.key, |token| Engine.element("span", [Engine.class_s(token.field(|t| t.class))], [Engine.text_s(token.field(|t| t.text))])),
							Engine.when(
								row.field(|l| !l.fold.is_empty()),
								|| Engine.element("span", [], [Engine.text("{ "), Engine.element("span", [Engine.class("fold"), Engine.attr_s("title", row.field(|l| l.fold))], [Engine.text("⋯")]), Engine.text(" }")]),
								|| Engine.text(""),
							),
							Engine.text("\n"),
						],
					),
			),
		],
	)

expect roc_lines(1, ["app [main] {", "  pf: platform \"x\",", "}", "", "x = 1"]).map(|l| (l.number, l.fold)) == [("1", "pf: platform \"x\","), ("4", ""), ("5", "")]
