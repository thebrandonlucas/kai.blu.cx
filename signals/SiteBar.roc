import pf.Engine exposing [Attr, Elem]

## The bar on top of every page of kai.blu.cx, numbered for the keyboard:
## 0 the wordmark (home), 1 docs, 2 api, 3 changelog, 4 blog, 5 Discord and
## 6 GitHub (those two in a new tab). `site-keys.js` presses an item when its
## number is typed; reference.sh puts the same bar, as static HTML, on the
## generated API reference. Ported from `src/SiteBar.elm`.
SiteBar := [].{

	Section : [Home, Docs, Changelog, Blog]

	## The bar, with `active` marked. On the home page, `home` holds the
	## wordmark's click handler (it scrolls back to the top instead of
	## reloading).
	view : SiteBar.Section, List(Attr(ctx)) -> Elem(ctx)
	view = |active, home|
		Engine.element(
			"header",
			[Engine.class("bar site-bar")],
			[
				Engine.element(
					"nav",
					[Engine.class("bar-site"), Engine.attr("aria-label", "Site")],
					[
						Engine.element(
							"a",
							[Engine.class("bar-mark"), Engine.attr("href", "/"), Engine.attr("title", "Kai (0)"), key(0)].concat(home),
							[num(0), Engine.element("img", [Engine.class("bar-mark-img"), Engine.attr("src", "/images/kai-mark.svg"), Engine.attr("alt", "Kai")], [])],
						),
						link(1, active == Docs, "/docs/", "docs"),
						link(2, Bool.False, "/reference/std/", "api"),
						link(3, active == Changelog, "/changelog/", "changelog"),
						link(4, active == Blog, "/blog/", "blog"),
					],
				),
				Engine.element(
					"nav",
					[Engine.class("bar-social"), Engine.attr("aria-label", "Community")],
					[
						icon(5, "https://discord.gg/SrH3w5uAa3", "Discord", "/icons/discord.svg"),
						icon(6, "https://github.com/thebrandonlucas/kai", "GitHub", "/icons/github.svg"),
					],
				),
			],
		)
}

key : U64 -> Attr(ctx)
key = |n| Engine.attr("data-key", n.to_str())

num : U64 -> Elem(ctx)
num = |n| Engine.element("span", [Engine.class("bar-num")], [Engine.text(n.to_str())])

link : U64, Bool, Str, Str -> Elem(ctx)
link = |n, current, url, label|
	Engine.element(
		"a",
		[
			Engine.class(if current "bar-link bar-link-active" else "bar-link"),
			Engine.attr("aria-current", if current "page" else "false"),
			Engine.attr("href", url),
			key(n),
		],
		[num(n), Engine.text(label)],
	)

## A community link: opens in a new tab. The icon is decorative; roc-signals
## 0.5.0 drops `alt=""`, so `aria-hidden` alone keeps it out of the
## accessible name (https://github.com/thebrandonlucas/roc-issues/tree/master/roc-signals/RS-006-empty-attribute-values).
icon : U64, Str, Str, Str -> Elem(ctx)
icon = |n, url, name, path|
	Engine.element(
		"a",
		[
			Engine.class("bar-icon"),
			Engine.attr("href", url),
			Engine.attr("target", "_blank"),
			Engine.attr("rel", "noopener"),
			Engine.attr("title", "${name} (${n.to_str()})"),
			Engine.attr("aria-label", name),
			key(n),
		],
		[
			num(n),
			Engine.element("img", [Engine.attr("src", path), Engine.attr("alt", ""), Engine.attr("width", "18"), Engine.attr("height", "18"), Engine.attr("aria-hidden", "true")], []),
		],
	)
