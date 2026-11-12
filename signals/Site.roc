import pf.Engine exposing [Elem, Root]
import Changelog
import Docs
import Home
import Ports

## The pages of the site that are an app, chosen by the path the page was
## loaded at: `/docs/` the guides, `/changelog/` the changelog, anything
## else the home page. One module serves all three, so the site builds one
## `app.wasm`.
Site := [].{

	program : Engine.Program
	program = Engine.program_boot({ storage_keys: [], max_inflight: 32 }, page).with_ports(Ports.registrations)

	Route : [HomePage, DocsPage, ChangelogPage]

	route : Str -> Site.Route
	route = |url| {
		path = path_of(url)
		if path.starts_with("/docs") {
			DocsPage
		} else if path.starts_with("/changelog") {
			ChangelogPage
		} else {
			HomePage
		}
	}
}

page : Engine.Boot -> Elem(Root)
page = |boot|
	match Site.route(boot.url) {
		DocsPage => Engine.state(Docs.init(fragment_of(boot.url)), Docs.view)
		ChangelogPage => Engine.state(Loading, Changelog.view)
		HomePage => Engine.state(Home.init(fragment_of(boot.url)), Home.view)
	}

## The URL's path: what is after its origin, before any query or fragment.
path_of : Str -> Str
path_of = |url| {
	after_scheme = match url.split_first("://") {
		Ok(parts) => parts.after
		Err(_) => url
	}
	rest = match after_scheme.split_first("/") {
		Ok(parts) => "/${parts.after}"
		Err(_) => "/"
	}
	before = |text, mark| match text.split_first(mark) {
		Ok(parts) => parts.before
		Err(_) => text
	}
	before(before(rest, "#"), "?")
}

## The URL's fragment, with its `#` ("" when it has none).
fragment_of : Str -> Str
fragment_of = |url|
	match url.split_first("#") {
		Ok(parts) => "#${parts.after}"
		Err(_) => ""
	}

expect Site.route("https://kai.blu.cx/docs/#install") == DocsPage
expect Site.route("http://127.0.0.1:8000/changelog/") == ChangelogPage
expect Site.route("https://kai.blu.cx/#3") == HomePage and Site.route("https://kai.blu.cx") == HomePage
expect path_of("https://kai.blu.cx/docs/?x=1#a") == "/docs/" and fragment_of("https://kai.blu.cx/#3") == "#3"
