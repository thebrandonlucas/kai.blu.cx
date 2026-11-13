import pf.Engine
import pf.Port

## What the pages ask of the browser that roc-signals 0.5.0 does not model,
## answered by public/site-ports.mjs: scrolling an element, its scroll
## position as it changes, and keys pressed anywhere on the page. See
## https://github.com/lukewilliamboswell/roc-signals/issues/204 (closed in favour
## of #211, #213 and #214) and
## https://github.com/lukewilliamboswell/roc-signals/issues/203 (closed in favour
## of #212); roc-issues archive/RS-005-layout-measurement and
## archive/RS-004-document-key-events. Drop these ports once the site is on a
## release that has those.
Ports := [].{

	## Where to scroll: a screen (the element's height times `n`, for the
	## home page's workspaces).
	Scroll : { id : Str, screen : U32 }

	## Scroll the element `id` to a screen, smoothly (the CSS decides).
	scroll : Port.Command(Ports.Scroll)
	scroll = Port.command({ name: "kai.blu.cx/scroll" })

	## The element's scroll position and height, after each scroll.
	Scrolled : { top : F64, height : F64 }

	scrolled : Port.Subscription({ id : Str }, Ports.Scrolled)
	scrolled = Port.subscription({ name: "kai.blu.cx/scrolled", delivery: Latest })

	## Keys pressed anywhere on the page, of those in `keys`, without Ctrl,
	## ⌘ or Alt and outside text fields. The JavaScript prevents their
	## default (the browser's own scrolling), which a handler cannot do
	## for some keys and not others.
	keys : Port.Subscription({ keys : List(Str) }, { key : Str })
	keys = Port.subscription({ name: "kai.blu.cx/keys", delivery: Every(32) })

	registrations : List(Engine.PortRegistration)
	registrations = [Ports.scroll.registration(), Ports.scrolled.registration(), Ports.keys.registration()]
}
