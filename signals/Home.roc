import pf.Engine exposing [Elem, In, Root, Row, RowRef, State]
import pf.PortJson
import Files
import Ports
import SiteBar

## kai.blu.cx: Kai's home page and guided tour, over Thomas Cole's "The
## Arcadian or Pastoral State". Ported from `src/Main.elm`.
##
## The page is a column of workspaces, one screen tall each, like a tiling
## window manager's. The first is the painting with the wordmark; each tour
## step after it is a glass window with its Markdown text and, if the step
## has them, a Kaifile pane and a terminal pane tiled beside it.
##
## The steps live in `public/tour/`: `tour.json` lists them in order and
## names each step's files, which are fetched when the page loads, so
## editing the tour needs no rebuild.
##
## Keys: ↓ / j / PageDown / Space next, ↑ / k / PageUp previous, Home / g the
## first, End / G the last, Tab the other tab of a step's window. Scrolling
## works too and snaps to a workspace. The number keys belong to the site
## bar (`site-keys.js`): 0 is back to the top here.
Home := [].{

	Pane : [KaifilePane, TerminalPane, NixPane, GuixPane]

	## A tour step, numbered from 1 (workspace 0 is the painting). A file
	## the step doesn't have is "".
	Step : {
		n : U64,
		total : U64,
		id : Str,
		title : Str,
		markdown : Str,
		kaifile : Str,
		terminal : Str,
		# The same project in plain Nix and Guix, for comparison: tabs in a
		# window above the Kaifile.
		nix : Str,
		guix : Str,
		# A picture of the step's point, in a window of its own; until there
		# is artwork, a text sketch.
		figure : Str,
		# The tab shown first when the step has both (default: the Kaifile).
		open : Home.Pane,
	}

	Tour : [Loading, Failed(Str), Loaded(List(Home.Step))]

	Model : {
		tour : Home.Tour,
		current : U64,
		start : U64,
		instant : Bool,
		# The workspace a key or click is scrolling to, and that jump's number.
		# Until it arrives, scroll events don't change `current`, so the bar
		# and the hint don't flicker through the workspaces in between.
		moving : [Still, To(U64)],
		jump : U64,
		# Tabs the reader switched, by step id.
		tabs : List((Str, Home.Pane)),
		# Requests: scroll to a workspace, end a jump after 1.5 s, and go to
		# the URL's workspace once the steps are drawn.
		scroll : Engine.Outbox(U64),
		landing : Engine.Outbox(U64),
		later : Engine.Outbox(U64),
	}

	## The page at `#n` opens on workspace n.
	init : Str -> Home.Model
	init = |hash| {
		start = start_of(hash)
		{
			tour: Loading,
			current: 0,
			start,
			instant: start > 0,
			moving: Still,
			jump: 0,
			tabs: [],
			scroll: Engine.outbox({}),
			landing: Engine.outbox({}),
			later: Engine.outbox({}),
		}
	}

	view : State(In(Root, Home.Model), Home.Model) -> Elem(In(Root, Home.Model))
	view = |model| {
		m = model.signal()
		Engine.element(
			"div",
			[Engine.attr("id", "desktop"), Engine.class("desktop"), Engine.attr("tabindex", "0")],
			[
				SiteBar.view(Home, [Engine.on("click:prevent", model.update(|s| Home.go(s, 0)))]),
				Engine.element(
					"main",
					[Engine.attr("id", "workspaces"), Engine.class_s(m.map(|s| if s.instant "workspaces instant" else "workspaces"))],
					[hero({}), steps(model)],
				),
				rail(model),
				hint(model),
				effects(model),
			],
		)
	}

	## Scroll to workspace `n` (clamped). The CSS makes the scroll smooth.
	## `current` changes at once, and scroll events leave it alone until the
	## scroll arrives (or, if the reader scrolls away mid-jump, for at most
	## 1.5 s).
	go : Home.Model, I64 -> Home.Model
	go = |model, n| {
		target = n.max(0).to_u64_wrap().min(count(model) - 1)
		jump = model.jump + 1
		{ ..model, current: target, moving: To(target), jump, scroll: model.scroll.post(target), landing: model.landing.post(jump) }
	}

	## The workspace scrolled into view, unless a jump is under way.
	scrolled : Home.Model, Ports.Scrolled -> Home.Model
	scrolled = |model, { top, height }|
		if height <= 0 {
			model
		} else {
			match model.moving {
				# Mid-jump: wait until the jump arrives.
				To(target) =>
					if (top - target.to_f64() * height).abs() < 2 {
						{ ..model, moving: Still, current: target, instant: Bool.False }
					} else {
						model
					}
				Still => {
					at = (top / height).round_to_u64_try() ?? 0
					if at == model.current and !model.instant model else { ..model, current: at, instant: Bool.False }
				}
			}
		}

	## A jump the reader interrupted by scrolling: follow the scroll again.
	landed : Home.Model, U64 -> Home.Model
	landed = |model, jump| if jump == model.jump { ..model, moving: Still } else model

	## What a key does.
	key : Home.Model, Str -> Home.Model
	key = |model, pressed| {
		here = model.current.to_i64_wrap()
		match pressed {
			"Tab" => toggle_tab(model)
			"ArrowDown" | "j" | "PageDown" | " " => Home.go(model, here + 1)
			"ArrowUp" | "k" | "PageUp" => Home.go(model, here - 1)
			"Home" | "g" => Home.go(model, 0)
			"End" | "G" => Home.go(model, count(model).to_i64_wrap() - 1)
			_ => model
		}
	}

	## The tour, from `tour.json`; then, after the steps' workspaces are
	## drawn, the URL's workspace.
	toured : Home.Model, Engine.Result -> Home.Model
	toured = |model, result|
		match Engine.http_text(result) {
			Ok(text) =>
				match decode(text) {
					Ok(list) => {
						loaded = { ..model, tour: Loaded(list) }
						if model.start > 0 { ..loaded, later: model.later.post(model.start) } else loaded
					}
					Err(why) => { ..model, tour: Failed(why) }
				}
			Err(Status(code)) => { ..model, tour: Failed("HTTP ${code.to_str()}") }
			Err(Timeout) => { ..model, tour: Failed("timed out") }
			Err(Network(_)) => { ..model, tour: Failed("network error") }
			Err(Refused) => { ..model, tour: Failed("too many requests at once") }
		}
}

Ctx : In(Root, Home.Model)

# ---- The tour file

StepJson : {
	id : Str,
	title : Str,
	markdown : Str,
	kaifile : Try(Str, [Missing]),
	terminal : Try(Str, [Missing]),
	nix : Try(Str, [Missing]),
	guix : Try(Str, [Missing]),
	figure : Try(Str, [Missing]),
	open : Try(Str, [Missing]),
}

decode : Str -> Try(List(Home.Step), Str)
decode = |text| {
	parsed : Try({ steps : List(StepJson) }, PortJson.Error)
	parsed = PortJson.decode({ json: text, blobs: [], files: [] })
	match parsed {
		Ok({ steps: list }) => {
			total = list.len()
			Ok(
				list.map_with_index(
					|s, i| {
						n = i + 1
						{
							n,
							total,
							id: s.id,
							title: s.title,
							markdown: s.markdown,
							kaifile: s.kaifile ?? "",
							terminal: s.terminal ?? "",
							nix: s.nix ?? "",
							guix: s.guix ?? "",
							figure: s.figure ?? "",
							open: if s.open == Ok("terminal") TerminalPane else KaifilePane,
						}
					},
				),
			)
		}
		Err(why) => Err("unreadable: ${PortJson.describe(why)}")
	}
}

## `#3` is workspace 3 (index 2); anything else is the first.
start_of : Str -> U64
start_of = |hash| {
	digits = hash.drop_prefix("#").to_utf8()
	if !digits.is_empty() and digits.all(|b| b >= '0' and b <= '9') and digits.len() < 6 {
		number : U64
		number = digits.fold(0, |n, b| n * 10 + (b - '0').to_u64())
		number.max(1) - 1
	} else {
		0
	}
}

# ---- Steps and tabs

steps_of : Home.Model -> List(Home.Step)
steps_of = |model|
	match model.tour {
		Loaded(list) => list
		_ => []
	}

## The painting plus one workspace per step.
count : Home.Model -> U64
count = |model| 1 + steps_of(model).len()

## The step on screen (workspace 0 is the painting, not a step).
current_step : Home.Model -> Try(Home.Step, [NotStep])
current_step = |model|
	if model.current == 0 {
		Err(NotStep)
	} else {
		steps_of(model).get(model.current - 1).map_err(|_| NotStep)
	}

is_comparison : Home.Step -> Bool
is_comparison = |step| !step.nix.is_empty() or !step.guix.is_empty()

## The tabs of a step's tabbed window: its Nix and Guix files when it
## compares them with Kai, else its Kaifile and terminal.
tabs_of : Home.Step -> List((Home.Pane, Str))
tabs_of = |step| {
	candidates = if is_comparison(step) [(NixPane, step.nix), (GuixPane, step.guix)] else [(KaifilePane, step.kaifile), (TerminalPane, step.terminal)]
	candidates.keep_if(|(_, path)| !path.is_empty())
}

## The tab a step shows: the reader's choice, else the step's own, as long
## as the window has it; else its first.
shown : Home.Model, Home.Step -> Home.Pane
shown = |model, step| {
	wanted = match model.tabs.find_first(|(id, _)| id == step.id) {
		Ok((_, pane)) => pane
		Err(_) => step.open
	}
	panes = tabs_of(step).map(|(pane, _)| pane)
	if panes.contains(wanted) wanted else panes.first() ?? KaifilePane
}

show_tab : Home.Model, Str, Home.Pane -> Home.Model
show_tab = |model, id, pane| { ..model, tabs: model.tabs.drop_if(|(other, _)| other == id).append((id, pane)) }

## The tab after the one shown, wrapping around.
toggle_tab : Home.Model -> Home.Model
toggle_tab = |model|
	match current_step(model) {
		Ok(step) => {
			panes = tabs_of(step).map(|(pane, _)| pane)
			now = shown(model, step)
			at = panes.find_first_index(|p| p == now) ?? 0
			show_tab(model, step.id, panes.get((at + 1) % panes.len().max(1)) ?? now)
		}
		Err(_) => model
	}

## The keys the page takes: Tab only where a window has two tabs; elsewhere
## Tab moves focus.
claimed : Home.Model -> List(Str)
claimed = |model| {
	keys = ["ArrowDown", "j", "PageDown", " ", "ArrowUp", "k", "PageUp", "Home", "g", "End", "G"]
	two_tabs = match current_step(model) {
		Ok(step) => tabs_of(step).len() > 1
		Err(_) => Bool.False
	}
	if two_tabs keys.append("Tab") else keys
}

pane_name : Home.Pane -> Str
pane_name = |pane|
	match pane {
		KaifilePane => "Kaifile.roc"
		TerminalPane => "terminal"
		NixPane => "flake.nix"
		GuixPane => "manifest.scm"
	}

pane_meta : Home.Pane -> Str
pane_meta = |pane|
	match pane {
		KaifilePane => "roc"
		TerminalPane => "kai 0.0.11"
		NixPane => "nix"
		GuixPane => "guile"
	}

# ---- Effects

effects : State(Ctx, Home.Model) -> Elem(Ctx)
effects = |model| {
	m = model.signal()
	Engine.element(
		"div",
		[Engine.attr("hidden", "hidden")],
		[
			Engine.watch(Engine.const({}), |_| [Http({ method: "GET", url: "/tour/tour.json", headers: [], body: "", timeout_ms: 30000 })], model.on_result(|s, _, res| Home.toured(s, res))),
			Engine.on_post(m.map(|s| s.later), |_| [Timer(100)], model.on_result(|s, n, _| Home.go(s, n.to_i64_wrap()))),
			Engine.on_post(m.map(|s| s.scroll), |n| [Ports.scroll.send({ id: "workspaces", screen: n.to_u32_wrap() })], Engine.ignore({})),
			Engine.on_post(m.map(|s| s.landing), |_| [Timer(1500)], model.on_result(|s, jump, _| Home.landed(s, jump))),
			Engine.watch(
				Engine.const({}),
				|_| [Ports.scrolled.subscribe({ id: "workspaces" })],
				model.on_result(
					|s, _, res|
						match Ports.scrolled.message(res) {
							Ok(position) => Home.scrolled(s, position)
							Err(_) => s
						},
				),
			),
			Engine.watch_latest(
				m.map(claimed),
				|keys| [Ports.keys.subscribe({ keys: keys })],
				model.on_result(
					|s, _, res|
						match Ports.keys.message(res) {
							Ok({ key: pressed }) => Home.key(s, pressed)
							Err(_) => s
						},
				),
			),
		],
	)
}

# ---- View

## Workspace 0: the painting, the wordmark, the install command and
## Emerson on a glass card. Discord and GitHub are in the site bar.
hero : {} -> Elem(ctx)
hero = |{}|
	Engine.element(
		"section",
		[Engine.attr("id", "ws-0"), Engine.class("workspace hero")],
		[
			# ϗαί: the kai compendium (drawn, since GFS Didot has none), then αί.
			# roc-signals 0.5.0 drops `alt=""`, so `aria-hidden` keeps the
			# drawing out of the heading's name
			# (https://github.com/thebrandonlucas/roc-issues/tree/master/roc-signals/RS-006-empty-attribute-values).
			Engine.element(
				"h1",
				[Engine.class("wordmark"), Engine.attr("aria-label", "kαί")],
				[Engine.element("img", [Engine.class("wordmark-kai"), Engine.attr("src", "/images/kai-wordmark.svg"), Engine.attr("alt", ""), Engine.attr("aria-hidden", "true")], []), Engine.text("αί")],
			),
			Engine.element("p", [Engine.class("tagline")], [Engine.text("A friendly frontend for determinate computing")]),
			# One column: the install row and the quote card share both edges.
			Engine.element(
				"div",
				[Engine.class("hero-column")],
				[
					install({}),
					Engine.element(
						"blockquote",
						[Engine.class("epigraph")],
						[
							Engine.element("p", [], [Engine.text("Why should we grope among the dry bones of the past, or put the living generation into masquerade out of its faded wardrobe?")]),
							Engine.element("p", [], [Engine.text("The sun shines today also.")]),
							Engine.element("footer", [], [Engine.text("— Emerson, "), Engine.element("cite", [], [Engine.text("Nature")])]),
						],
					),
				],
			),
		],
	)

## The one-line install: the command, a copy button (site-keys.js copies a
## `data-copy` button's text) and, at the row's end, a link to the script.
## kai.blu.cx/install.sh redirects to the latest release's install.sh.
install : {} -> Elem(ctx)
install = |{}|
	Engine.element(
		"div",
		[Engine.class("install-line")],
		[
			Engine.element("span", [Engine.class("install-prompt")], [Engine.text("$")]),
			Engine.element("code", [Engine.class("install-command")], [Engine.text(install_command)]),
			Engine.element(
				"button",
				[Engine.class("install-copy"), Engine.attr("data-copy", install_command), Engine.attr("title", "Copy"), Engine.attr("aria-label", "Copy the install command")],
				[Engine.text("copy")],
			),
			Engine.element(
				"a",
				[Engine.class("install-script"), Engine.attr("href", "https://github.com/thebrandonlucas/kai/blob/master/install.sh"), Engine.attr("title", "Read the install script")],
				[Engine.text("script")],
			),
		],
	)

install_command : Str
install_command = "curl -fsSL https://kai.blu.cx/install.sh | sh"

steps : State(Ctx, Home.Model) -> Elem(Ctx)
steps = |model| {
	m = model.signal()
	Engine.switch(
		m.map(|s| match s.tour { Loading => "loading", Failed(_) => "failed", Loaded(_) => "loaded" }),
		["loading", "failed", "loaded"],
		|found| match found {
			"failed" =>
				Engine.element(
					"section",
					[Engine.attr("id", "ws-1"), Engine.class("workspace")],
					[
						Engine.element(
							"div",
							[Engine.class("window")],
							[
								titlebar(Engine.const("tour"), Engine.const("error")),
								Engine.element(
									"div",
									[Engine.class("window-body")],
									[Engine.element("p", [Engine.class("error")], [Engine.text_s(m.map(|s| match s.tour { Failed(why) => "The tour didn't load: ${why}", _ => "" }))])],
								),
							],
						),
					],
				)
			"loaded" => Engine.each(m.map(steps_of), |s| s.id, |row| step_view(model.lift_row(), row))
			_ => Engine.text("")
		},
	)
}

Layout : [Alone, Figure, Group, Comparison]

layout_of : Home.Step -> Layout
layout_of = |step|
	if !step.figure.is_empty() {
		Figure
	} else if tabs_of(step).is_empty() {
		Alone
	} else if is_comparison(step) {
		Comparison
	} else {
		Group
	}

StepCtx : Row(Ctx, Home.Step)

## A tour step: one glass window with its text, tiled beside a window
## group holding its Kaifile and terminal as tabs, if it has them. A step
## comparing Kai with plain Nix and Guix stacks those two as tabs above its
## Kaifile instead.
step_view : State(StepCtx, Home.Model), RowRef(Ctx, Home.Step) -> Elem(StepCtx)
step_view = |model, row| {
	layout = row.field(layout_of)
	Engine.element(
		"section",
		[Engine.attr_s("id", row.field(|s| "ws-${s.n.to_str()}")), Engine.class("workspace")],
		[
			Engine.element(
				"div",
				[Engine.class_s(layout.map(|l| if l == Alone "tiling" else "tiling tiling-split"))],
				[
					Engine.element(
						"div",
						[Engine.class("window window-prose")],
						[
							titlebar(row.field(|s| "~/tour/${s.id}.md"), row.field(|s| "${s.n.to_str()}/${s.total.to_str()}")),
							Engine.element("div", [Engine.class("window-body")], [Files.view(row.field(|s| "/tour/${s.markdown}"), row.field(|s| s.markdown), Files.markdown(Allow))]),
						],
					),
					Engine.switch(
						layout,
						[Alone, Figure, Group, Comparison],
						|found| match found {
							Alone => Engine.text("")
							Figure =>
								Engine.element(
									"div",
									[Engine.class("window window-code")],
									[
										titlebar(Engine.const("figure"), Engine.const("sketch")),
										Engine.element("div", [Engine.class("window-body")], [Files.view(row.field(|s| "/tour/${s.figure}"), row.field(|s| s.figure), Files.figure)]),
									],
								)
							Group => window_group(model, row)
							Comparison =>
								Engine.element(
									"div",
									[Engine.class("stack")],
									[
										window_group(model, row),
										Engine.when(
											row.field(|s| !s.kaifile.is_empty()),
											|| Engine.element(
												"div",
												[Engine.class("window window-code")],
												[
													titlebar(Engine.const(pane_name(KaifilePane)), Engine.const(pane_meta(KaifilePane))),
													Engine.element("div", [Engine.class("window-body")], [Files.view(row.field(|s| "/tour/${s.kaifile}"), row.field(|s| s.kaifile), Files.code)]),
												],
											),
											|| Engine.text(""),
										),
									],
								)
						},
					),
				],
			),
		],
	)
}

## A tab of a step's window, with what its click needs.
Tab : { key : Str, step : Str, pane : Home.Pane, name : Str }

## One window, several tabs; the shown one fills the window.
window_group : State(StepCtx, Home.Model), RowRef(Ctx, Home.Step) -> Elem(StepCtx)
window_group = |model, row| {
	step = row.item()
	pane = model.signal().map2(step, shown)
	tabs = step.map(|s| tabs_of(s).map(|(p, _)| { key: pane_name(p), step: s.id, pane: p, name: pane_name(p) }))
	Engine.element(
		"div",
		[Engine.class_s(pane.map(|p| if p == TerminalPane "window window-group window-term" else "window window-group window-code"))],
		[
			Engine.element(
				"div",
				[Engine.class("tabbar"), Engine.attr("role", "tablist")],
				[
					Engine.each(
						tabs,
						|t| t.key,
						|tab| {
							active = pane.lift_row().map2(tab.item(), |p, t| p == t.pane)
							Engine.element(
								"button",
								[
									Engine.class_s(active.map(|a| if a "tab tab-active" else "tab")),
									Engine.attr("role", "tab"),
									Engine.attr_s("aria-selected", active.map(|a| if a "true" else "false")),
									Engine.on("click", model.lift_row().update_by(tab.item(), |s, t| show_tab(s, t.step, t.pane))),
								],
								[Engine.text_s(tab.field(|t| t.name))],
							)
						},
					),
					Engine.element(
						"span",
						[Engine.class("tabbar-meta")],
						[
							Engine.when(tabs.map(|t| t.len() > 1), || Engine.element("kbd", [], [Engine.text("Tab")]), || Engine.text("")),
							Engine.text_s(pane.map(|p| " ${pane_meta(p)}")),
						],
					),
				],
			),
			Engine.element(
				"div",
				[Engine.class("window-body")],
				[
					Engine.switch(
						pane,
						[KaifilePane, TerminalPane, NixPane, GuixPane],
						|p| {
							path = step.map(|s| path_of(s, p))
							url = path.map(|f| "/tour/${f}")
							match p {
								KaifilePane => Files.view(url, path, Files.code)
								TerminalPane => Files.view(url, path, Files.terminal)
								_ => Files.view(url, path, Files.plain_code)
							}
						},
					),
				],
			),
		],
	)
}

path_of : Home.Step, Home.Pane -> Str
path_of = |step, pane|
	match pane {
		KaifilePane => step.kaifile
		TerminalPane => step.terminal
		NixPane => step.nix
		GuixPane => step.guix
	}

titlebar : Engine.Signal(ctx, Str), Engine.Signal(ctx, Str) -> Elem(ctx)
titlebar = |name, meta|
	Engine.element(
		"div",
		[Engine.class("titlebar")],
		[
			Engine.element("span", [Engine.class("titlebar-name")], [Engine.text_s(name)]),
			Engine.element("span", [Engine.class("titlebar-meta")], [Engine.text_s(meta)]),
		],
	)

## A workspace's dot on the rail.
Dot : { key : Str, n : U64, label : Str }

dots : Home.Model -> List(Dot)
dots = |model| ["start"].concat(steps_of(model).map(|s| s.title)).map_with_index(|label, n| { key: n.to_str(), n, label })

## Where you are in the tour: a dot per workspace down the right edge, the
## step's number and name beside the dot you point at.
rail : State(Ctx, Home.Model) -> Elem(Ctx)
rail = |model|
	Engine.element(
		"nav",
		[Engine.class("rail"), Engine.attr("aria-label", "Tour steps")],
		[
			Engine.element(
				"ol",
				[],
				[
					Engine.each(
						model.signal().map(dots),
						|d| d.key,
						|dot| {
							here = model.signal().lift_row().map2(dot.item(), |s, d| s.current == d.n)
							Engine.element(
								"li",
								[],
								[
									Engine.element(
										"button",
										[
											Engine.class_s(here.map(|h| if h "rail-dot rail-dot-active" else "rail-dot")),
											Engine.on("click", model.lift_row().update_by(dot.item(), |s, d| Home.go(s, d.n.to_i64_wrap()))),
											Engine.attr_s("aria-label", dot.field(|d| d.label)),
											Engine.attr_s("aria-current", here.map(|h| if h "step" else "false")),
										],
										[Engine.element("span", [Engine.class("rail-label")], [Engine.text_s(dot.field(|d| "${((d.n + 1) % 10).to_str()} ${d.label}"))])],
									),
								],
							)
						},
					),
				],
			),
		],
	)

## Bottom right: the keys for back and next, each also a button.
hint : State(Ctx, Home.Model) -> Elem(Ctx)
hint = |model| {
	m = model.signal()
	Engine.element(
		"footer",
		[Engine.class("hint")],
		[
			Engine.when(
				m.map(|s| s.current != 0),
				|| Engine.element(
					"button",
					[Engine.class("hint-button"), Engine.on("click", model.update(|s| Home.go(s, s.current.to_i64_wrap() - 1))), Engine.attr("aria-label", "Back")],
					[Engine.text("back "), Engine.element("kbd", [], [Engine.text("k")]), Engine.element("kbd", [], [Engine.text("↑")])],
				),
				|| Engine.text(""),
			),
			Engine.when(
				m.map(|s| s.current + 1 >= count(s)),
				|| Engine.element(
					"button",
					[Engine.class("hint-button"), Engine.on("click", model.update(|s| Home.go(s, 0))), Engine.attr("aria-label", "Back to the start")],
					[Engine.text("to the top "), Engine.element("kbd", [], [Engine.text("g")])],
				),
				|| Engine.element(
					"button",
					[Engine.class("hint-button"), Engine.on("click", model.update(|s| Home.go(s, s.current.to_i64_wrap() + 1))), Engine.attr("aria-label", "Next")],
					[Engine.text_s(m.map(|s| if s.current == 0 "take the tour " else "next ")), Engine.element("kbd", [], [Engine.text("j")]), Engine.element("kbd", [], [Engine.text("↓")])],
				),
			),
		],
	)
}

# ---- Tests

tour_json : Str
tour_json =
	\\{ "steps": [
	\\  { "id": "01-roc", "title": "roc", "markdown": "01-roc.md", "nix": "01-roc.nix", "kaifile": "03-first-kaifile.roc" },
	\\  { "id": "02-kai", "title": "kai", "markdown": "02-kai.md", "kaifile": "k.roc", "terminal": "k.term", "open": "terminal" }
	\\] }

loaded : U64 -> Home.Model
loaded = |start| {
	model = Home.init(if start == 0 "" else "#${(start + 1).to_str()}")
	{ ..model, tour: Loaded(decode(tour_json) ?? []) }
}

expect start_of("#3") == 2 and start_of("") == 0 and start_of("#x") == 0 and start_of("#0") == 0
expect decode(tour_json).map_ok(|list| list.map(|s| (s.n, s.total, s.kaifile, s.open))) == Ok([(1, 2, "03-first-kaifile.roc", KaifilePane), (2, 2, "k.roc", TerminalPane)])
expect decode("{}").is_err()
expect Home.go(loaded(0), 9).current == 2 and Home.go(loaded(0), -1).current == 0
expect Home.key(loaded(0), "j").moving == To(1) and Home.key(loaded(0), "G").current == 2

## A scroll mid-jump changes nothing until the jump arrives.
expect {
	jumping = Home.go(loaded(0), 2)
	Home.scrolled(jumping, { top: 500, height: 1000 }).current == 2 and Home.scrolled(jumping, { top: 2000, height: 1000 }).moving == Still
}

## Without a jump, the workspace nearest the top is current.
expect Home.scrolled(loaded(0), { top: 1600, height: 1000 }).current == 2

## A later jump keeps the reader's earlier interrupted one from landing it.
expect {
	twice = Home.go(Home.go(loaded(0), 1), 2)
	Home.landed(twice, 1).moving == To(2) and Home.landed(twice, 2).moving == Still
}

## Step 2 opens on its terminal; Tab switches to its Kaifile; step 1 compares.
expect {
	at_two = { ..loaded(0), current: 2 }
	step = current_step(at_two) ?? crash "no step"
	shown(at_two, step) == TerminalPane and shown(toggle_tab(at_two), step) == KaifilePane and claimed(at_two).contains("Tab")
}
expect {
	at_one = { ..loaded(0), current: 1 }
	step = current_step(at_one) ?? crash "no step"
	tabs_of(step).map(|(p, _)| p) == [NixPane] and !claimed(at_one).contains("Tab") and layout_of(step) == Comparison
}
