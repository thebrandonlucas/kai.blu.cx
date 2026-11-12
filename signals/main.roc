app [main] {
	pf: platform "https://github.com/lukewilliamboswell/roc-signals/releases/download/0.5.0/2SYUPo9uKFPJDvTyXiwsLEqHvmq7UMgaY4hdgMiSsSEF.tar.zst",
}

import pf.Engine
import Site

## kai.blu.cx on roc-signals 0.5.0, ported from the Elm site (src/): the home
## page, the guides and the changelog, chosen by the page's path.
## `roc build --target=wasm32` gives the browser module (build.sh) and
## `roc build --target=x64musl` its native spec runner.
main : Engine.Program
main = Site.program
