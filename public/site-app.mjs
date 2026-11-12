// kai.blu.cx: mounts the app (app.wasm, built from signals/ by build.sh) on
// the page's #app. It shows the home page, the guides or the changelog,
// by the page's path.
import { mountRocEngineApp } from "/runtime.mjs?v=19";
import ports from "/site-ports.mjs?v=19";

await mountRocEngineApp({
  wasmUrl: "/app.wasm?v=19",
  root: document.getElementById("app"),
  ports,
  onFault: (fault) => console.error("kai.blu.cx stopped:", fault),
});
