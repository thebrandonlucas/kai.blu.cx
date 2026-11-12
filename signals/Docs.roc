import pf.Engine exposing [Elem, In, Root, State]
import pf.PortJson
import Files
import SiteBar

## kai.blu.cx/docs: the guides, in the tour's look but for reading: a
## file-tree window of the pages beside a reading window that scrolls.
## Ported from `src/Docs.elm`.
##
## The pages live in `docs/pages/`: `docs.json` lists the sections and their
## pages, and each page is `<slug>.md`. The URL fragment names the page
## (`/docs/#settings`), so pages link to each other with `#slug`.
##
## Keys: j / k scroll the page, h / l (or ← →) the previous and next page,
## g / G its top and bottom. `site-keys.js` gives them, as it does the blog
## and the changelog: the reading window is marked `data-scroll` and the
## pager's links `data-nav`.
Docs := [].{

	Page : { slug : Str, title : Str }

	Section : { title : Str, pages : List(Docs.Page) }

	Model : {
		sections : [Loading, Failed(Str), Loaded(List(Docs.Section))],
		# The URL's fragment without its `#`: the page to show ("" or a
		# page that isn't there is the first).
		slug : Str,
		# The pages the reader opened, for the browser's history.
		nav : Engine.Outbox(Str),
	}

	init : Str -> Docs.Model
	init = |fragment| { sections: Loading, slug: fragment.drop_prefix("#"), nav: Engine.outbox({}) }

	view : State(In(Root, Docs.Model), Docs.Model) -> Elem(In(Root, Docs.Model))
	view = |model|
		Engine.element(
			"div",
			[Engine.attr("id", "desktop"), Engine.class("desktop")],
			[
				SiteBar.view(Docs, []),
				Engine.element("div", [Engine.class("docs-tiling")], [tree(model), reading(model)]),
				effects(model),
			],
		)

	## The list of pages, from `docs.json`.
	listed : Docs.Model, Engine.Result -> Docs.Model
	listed = |model, result| {
		decoded : Try({ sections : List(Docs.Section) }, PortJson.Error)
		decoded = match Engine.http_text(result) {
			Ok(text) => PortJson.decode({ json: text, blobs: [], files: [] })
			Err(_) => Err(Syntax(0))
		}
		match decoded {
			Ok({ sections }) => { ..model, sections: Loaded(sections) }
			Err(_) => { ..model, sections: Failed("The list of pages didn't load.") }
		}
	}

	## Open a page, as a new entry in the browser's history.
	open : Docs.Model, Str -> Docs.Model
	open = |model, slug| { ..model, slug, nav: model.nav.post("#${slug}") }

	## The page the URL names, else the first.
	current : Docs.Model -> Try(Docs.Page, [NoPages])
	current = |model| {
		pages = all_pages(model)
		match pages.find_first(|p| p.slug == model.slug) {
			Ok(page) => Ok(page)
			Err(_) => pages.first().map_err(|_| NoPages)
		}
	}

	## The pages before and after the current one.
	neighbours : Docs.Model -> { previous : Try(Docs.Page, [None]), next : Try(Docs.Page, [None]) }
	neighbours = |model| {
		pages = all_pages(model)
		here = Docs.current(model).map_ok(|p| p.slug) ?? ""
		match pages.find_first_index(|p| p.slug == here) {
			Ok(at) => {
				previous = if at == 0 Err(None) else pages.get(at - 1).map_err(|_| None)
				{ previous, next: pages.get(at + 1).map_err(|_| None) }
			}
			Err(_) => { previous: Err(None), next: Err(None) }
		}
	}
}

Ctx : In(Root, Docs.Model)

all_pages : Docs.Model -> List(Docs.Page)
all_pages = |model|
	match model.sections {
		Loaded(sections) => sections.fold([], |acc, s| acc.concat(s.pages))
		_ => []
	}

## The page's slug, "" before the list arrives.
slug_of : Docs.Model -> Str
slug_of = |model| Docs.current(model).map_ok(|p| p.slug) ?? ""

title_of : Docs.Model -> Str
title_of = |model|
	match Docs.current(model) {
		Ok(page) => "${page.title} · Kai docs"
		Err(_) => "Kai docs"
	}

## The fragment of a URL the browser went back or forward to.
fragment_of : Str -> Str
fragment_of = |url|
	match url.split_first("#") {
		Ok(parts) => parts.after
		Err(_) => ""
	}

effects : State(Ctx, Docs.Model) -> Elem(Ctx)
effects = |model| {
	m = model.signal()
	Engine.element(
		"div",
		[Engine.attr("hidden", "hidden")],
		[
			Engine.watch(Engine.const({}), |_| [Http({ method: "GET", url: "/docs/pages/docs.json", headers: [], body: "", timeout_ms: 30000 })], model.on_result(|s, _, res| Docs.listed(s, res))),
			Engine.on_post(m.map(|s| s.nav), |url| [Push(url)], Engine.ignore({})),
			# Back and forward, and a link in a page to another (`#slug`), which
			# the browser follows itself.
			Engine.watch(
				Engine.const({}),
				|_| [Popstate],
				model.on_result(
					|s, _, res|
						match res {
							Location(url) => { ..s, slug: fragment_of(url) }
							_ => s
						},
				),
			),
			Engine.watch(m.map(title_of), |title| [Title(title)], Engine.ignore({})),
		],
	)
}

## The file-tree window: every page, by section, then the reference.
tree : State(Ctx, Docs.Model) -> Elem(Ctx)
tree = |model| {
	m = model.signal()
	Engine.element(
		"nav",
		[Engine.class("window window-tree"), Engine.attr("aria-label", "Pages")],
		[
			Engine.element("div", [Engine.class("titlebar")], [Engine.element("span", [Engine.class("titlebar-name")], [Engine.text("~/docs")])]),
			Engine.element(
				"div",
				[Engine.class("window-body")],
				[
					Engine.switch(
						m.map(|s| match s.sections { Loading => "loading", Failed(_) => "failed", Loaded(_) => "loaded" }),
						["loading", "failed", "loaded"],
						|found| match found {
							"failed" => Engine.element("p", [Engine.class("error")], [Engine.text_s(m.map(|s| match s.sections { Failed(why) => why, _ => "" }))])
							"loaded" =>
								Engine.element(
									"div",
									[],
									[
										Engine.each(
											m.map(|s| match s.sections { Loaded(sections) => sections, _ => [] }),
											|sec| sec.title,
											|sec|
												Engine.element(
													"section",
													[Engine.class("tree-section")],
													[
														Engine.element("h2", [], [Engine.text_s(sec.field(|s| "${s.title.with_ascii_lowercased()}/"))]),
														Engine.element(
															"ul",
															[],
															[
																Engine.each(
																	sec.field(|s| s.pages),
																	|p| p.slug,
																	|page| {
																		here = m.lift_row().lift_row().map2(page.item(), |s, p| slug_of(s) == p.slug)
																		Engine.element(
																			"li",
																			[],
																			[
																				Engine.element(
																					"a",
																					[
																						Engine.class_s(here.map(|h| if h "tree-page tree-page-active" else "tree-page")),
																						Engine.attr_s("href", page.field(|p| "#${p.slug}")),
																						Engine.on("click:prevent", model.lift_row().lift_row().update_by(page.item(), |s, p| Docs.open(s, p.slug))),
																					],
																					[Engine.text_s(page.field(|p| p.title))],
																				),
																			],
																		)
																	},
																),
															],
														),
													],
												),
										),
										Engine.element(
											"section",
											[Engine.class("tree-section")],
											[
												Engine.element("h2", [], [Engine.text("reference/")]),
												Engine.element(
													"ul",
													[],
													[
														Engine.element("li", [], [Engine.element("a", [Engine.class("tree-page"), Engine.attr("href", "/reference/std/")], [Engine.text("std")])]),
														Engine.element("li", [], [Engine.element("a", [Engine.class("tree-page"), Engine.attr("href", "/reference/platform/")], [Engine.text("platform")])]),
													],
												),
											],
										),
									],
								)
							_ => Engine.element("p", [Engine.class("loading")], [Engine.text("…")])
						},
					),
				],
			),
		],
	)
}

## The reading window: the page, then links to the pages around it. Each
## page is a new scrolling area, so it opens at its top.
reading : State(Ctx, Docs.Model) -> Elem(Ctx)
reading = |model| {
	m = model.signal()
	slug = m.map(slug_of)
	Engine.element(
		"div",
		[Engine.class("window window-reading")],
		[
			Engine.element(
				"div",
				[Engine.class("titlebar")],
				[
					Engine.element("span", [Engine.class("titlebar-name")], [Engine.text_s(slug.map(|s| "~/docs/${s}.md"))]),
					Engine.element("span", [Engine.class("titlebar-meta")], [Engine.text("j k scroll · h l page")]),
				],
			),
			Engine.remount_on(
				slug,
				|| Engine.element(
					# roc-signals 0.5.0 drops an attribute whose value is "", so
					# `data-scroll` has one
					# (https://github.com/thebrandonlucas/roc-issues/tree/master/roc-signals/RS-006-empty-attribute-values).
					"div",
					[Engine.attr("id", "reading"), Engine.class("window-body"), Engine.attr("data-scroll", "reading")],
					[
						Engine.when(
							slug.map(|s| s.is_empty()),
							|| Engine.element("p", [Engine.class("loading")], [Engine.text("…")]),
							|| Files.view(slug.map(|s| "/docs/pages/${s}.md"), Engine.const("This page"), Files.markdown(Allow)),
						),
						Engine.element(
							"div",
							[Engine.class("pager")],
							[
								pager_link(model, m.map(|s| Docs.neighbours(s).previous), "prev", |title| "← ${title}"),
								pager_link(model, m.map(|s| Docs.neighbours(s).next), "next", |title| "${title} →"),
							],
						),
					],
				),
			),
		],
	)
}

pager_link : State(Ctx, Docs.Model), Engine.Signal(Ctx, Try(Docs.Page, [None])), Str, (Str -> Str) -> Elem(Ctx)
pager_link = |model, page, nav, label|
	Engine.when(
		page.map(|p| p.is_ok()),
		|| Engine.element(
			"a",
			[
				Engine.class("pager-link"),
				Engine.attr("data-nav", nav),
				Engine.attr_s("href", page.map(|p| "#${p.map_ok(|found| found.slug) ?? ""}")),
				Engine.on("click:prevent", model.update_by(page, |s, p| match p { Ok(found) => Docs.open(s, found.slug), Err(_) => s })),
			],
			[Engine.text_s(page.map(|p| label(p.map_ok(|found| found.title) ?? "")))],
		),
		|| Engine.element("span", [], []),
	)

docs_json : Str
docs_json =
	\\{ "sections": [
	\\  { "title": "Getting started", "pages": [
	\\    { "slug": "introduction", "title": "What is Kai" },
	\\    { "slug": "install", "title": "Install" }
	\\  ] }
	\\] }

with_pages : Str -> Docs.Model
with_pages = |fragment| {
	model = Docs.init(fragment)
	decoded : Try({ sections : List(Docs.Section) }, PortJson.Error)
	decoded = PortJson.decode({ json: docs_json, blobs: [], files: [] })
	{ ..model, sections: Loaded(decoded.map_ok(|d| d.sections) ?? []) }
}

expect slug_of(with_pages("")) == "introduction" and slug_of(with_pages("#install")) == "install" and slug_of(with_pages("#gone")) == "introduction"
expect title_of(with_pages("#install")) == "Install · Kai docs" and title_of(Docs.init("")) == "Kai docs"
expect {
	around = Docs.neighbours(with_pages("#install"))
	around.previous.map_ok(|p| p.slug) == Ok("introduction") and around.next.is_err()
}
expect Docs.open(with_pages(""), "install").nav.last() == Posted("#install")
