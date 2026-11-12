import pf.Engine exposing [Elem, In, Root, State]
import pf.PortJson
import Files
import SiteBar

## kai.blu.cx/changelog: Kai's CHANGELOG.md as of its latest release, read
## from GitHub when the page loads, so a release updates this page with no
## deploy. A release without the file (before it existed) shows that
## release's notes instead. Ported from `src/Changelog.elm`.
Changelog := [].{

	Release : { tag : Str, notes : Str, url : Str }

	Model : [Loading, Failed, Shown(Changelog.Release, [Waiting, Got(Str)])]

	view : State(In(Root, Changelog.Model), Changelog.Model) -> Elem(In(Root, Changelog.Model))
	view = |model|
		Engine.element(
			"div",
			[Engine.class("desktop")],
			[
				SiteBar.view(Changelog, []),
				# The whole page, no window; data-scroll gives it site-keys.js's
				# reading keys. roc-signals 0.5.0 drops an attribute whose value
				# is "", so it has one
				# (https://github.com/thebrandonlucas/roc-issues/tree/master/roc-signals/RS-006-empty-attribute-values).
				Engine.element(
					"main",
					[Engine.class("page-full"), Engine.attr("data-scroll", "page")],
					[
						Engine.element(
							"p",
							[Engine.class("page-keys")],
							[Engine.text("j k scroll · "), Engine.element("a", [Engine.attr("href", "https://github.com/${repo}/releases.atom")], [Engine.text("feed")])],
						),
						body(model),
					],
				),
				effects(model),
			],
		)

	## The latest release, from GitHub's API.
	released : Changelog.Model, Engine.Result -> Changelog.Model
	released = |_, result| {
		decoded : Try({ tag_name : Str, body : Try(Str, [Missing]), html_url : Str }, PortJson.Error)
		decoded = match Engine.http_text(result) {
			Ok(text) => PortJson.decode({ json: text, blobs: [], files: [] })
			Err(_) => Err(Syntax(0))
		}
		match decoded {
			Ok(release) => Shown({ tag: release.tag_name, notes: release.body ?? "", url: release.html_url }, Waiting)
			Err(_) => Failed
		}
	}

	## The release's CHANGELOG.md, or its notes when it has none.
	read : Changelog.Model, Engine.Result -> Changelog.Model
	read = |model, result|
		match model {
			Shown(release, _) =>
				match Engine.http_text(result) {
					Ok(text) => Shown(release, Got(text))
					Err(_) => Shown(release, Got("# Changelog\n\n## ${release.tag}\n\n${release.notes}"))
				}
			_ => model
		}
}

Ctx : In(Root, Changelog.Model)

repo : Str
repo = "thebrandonlucas/kai"

tag_of : Changelog.Model -> Str
tag_of = |model|
	match model {
		Shown(release, _) => release.tag
		_ => ""
	}

effects : State(Ctx, Changelog.Model) -> Elem(Ctx)
effects = |model|
	Engine.element(
		"div",
		[Engine.attr("hidden", "hidden")],
		[
			Engine.watch(
				Engine.const({}),
				|_| [Http({ method: "GET", url: "https://api.github.com/repos/${repo}/releases/latest", headers: [], body: "", timeout_ms: 30000 })],
				model.on_result(|s, _, res| Changelog.released(s, res)),
			),
			Engine.watch(
				model.signal().map(tag_of),
				|tag| if tag.is_empty() [] else [Http({ method: "GET", url: "https://raw.githubusercontent.com/${repo}/${tag}/CHANGELOG.md", headers: [], body: "", timeout_ms: 30000 })],
				model.on_result(|s, _, res| Changelog.read(s, res)),
			),
		],
	)

body : State(Ctx, Changelog.Model) -> Elem(Ctx)
body = |model| {
	m = model.signal()
	Engine.switch(
		m.map(|s| match s { Loading => "loading", Failed => "failed", Shown(_, _) => "shown" }),
		["loading", "failed", "shown"],
		|found| match found {
			"failed" =>
				Engine.element(
					"p",
					[Engine.class("error")],
					[
						Engine.text("GitHub didn't answer. The changelog is also on "),
						Engine.element("a", [Engine.attr("href", "https://github.com/${repo}/releases")], [Engine.text("GitHub releases")]),
						Engine.text("."),
					],
				)
			"shown" =>
				Engine.element(
					"div",
					[],
					[
						Engine.when(
							m.map(|s| match s { Shown(_, Got(_)) => Bool.True, _ => Bool.False }),
							|| Files.markdown(Escape)(m.map(|s| match s { Shown(_, Got(text)) => text, _ => "" })),
							|| Engine.element("p", [Engine.class("loading")], [Engine.text("…")]),
						),
						Engine.element(
							"div",
							[Engine.class("pager")],
							[
								Engine.element(
									"a",
									[Engine.class("pager-link"), Engine.attr_s("href", m.map(|s| match s { Shown(release, _) => release.url, _ => "" }))],
									[Engine.text_s(m.map(|s| "Kai ${tag_of(s)} on GitHub"))],
								),
								Engine.element("a", [Engine.class("pager-link"), Engine.attr("href", "https://github.com/${repo}/releases")], [Engine.text("all releases →")]),
							],
						),
					],
				)
			_ => Engine.element("p", [Engine.class("loading")], [Engine.text("…")])
		},
	)
}
