// kai.blu.cx: the bar's numbers on the keyboard, on every page. Typing a
// number presses the bar item marked with it (data-key): 0 home, 1 docs,
// 2 api, 3 changelog, 4 blog, 5 Discord and 6 GitHub, in a new tab.
document.addEventListener("keydown", (event) => {
  if (event.ctrlKey || event.metaKey || event.altKey || event.defaultPrevented) return;
  const target = event.target;
  if (target && (target.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName))) return;
  const item = document.querySelector(`[data-key="${event.key}"]`);
  if (!item) return;
  event.preventDefault();
  item.click();
});

// Copy buttons: a button with data-copy puts that text on the clipboard
// and says so for a moment.
document.addEventListener("click", async (event) => {
  const button = event.target.closest("[data-copy]");
  if (!button) return;
  try {
    await navigator.clipboard.writeText(button.dataset.copy);
    const label = button.textContent;
    button.textContent = "copied";
    setTimeout(() => (button.textContent = label), 1400);
  } catch (_) {
    // No clipboard (an insecure page, or refused): the command is still there to select.
  }
});

// Reading keys, on pages that mark their scrolling area with data-scroll
// (the docs, the blog and the changelog; the tour handles its own keys and
// marks them handled): j / k or the arrows scroll, Space and PageUp/Down a
// screen, g / G the top and bottom, and h / l (or ← →) follow the page's
// data-nav="prev" / "next" links.
document.addEventListener("keydown", (event) => {
  if (event.ctrlKey || event.metaKey || event.altKey || event.defaultPrevented) return;
  const target = event.target;
  if (target && (target.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName))) return;
  const scroller = document.querySelector("[data-scroll]");
  if (!scroller) return;
  const page = scroller.clientHeight * 0.85;
  const by = {
    j: 90, ArrowDown: 90, k: -90, ArrowUp: -90,
    " ": page, PageDown: page, PageUp: -page,
  }[event.key];
  if (by !== undefined) {
    event.preventDefault();
    scroller.scrollBy({ top: by, behavior: "smooth" });
    return;
  }
  if (event.key === "g" || event.key === "Home") { event.preventDefault(); scroller.scrollTo({ top: 0, behavior: "smooth" }); return; }
  if (event.key === "G" || event.key === "End") { event.preventDefault(); scroller.scrollTo({ top: scroller.scrollHeight, behavior: "smooth" }); return; }
  const nav = { h: "prev", ArrowLeft: "prev", l: "next", ArrowRight: "next" }[event.key];
  const link = nav && document.querySelector(`[data-nav="${nav}"]`);
  if (link) { event.preventDefault(); link.click(); }
});
