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
