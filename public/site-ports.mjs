// kai.blu.cx: what the app (app.wasm, from signals/) asks of the page that
// roc-signals 0.5.0 does not model. The ports are declared in
// signals/Ports.roc.

// <kai-html html="…">: HTML the app made (Markdown, rendered in Roc), as the
// element's contents.
customElements.define(
  "kai-html",
  class extends HTMLElement {
    static observedAttributes = ["html"];
    attributeChangedCallback(_name, _old, html) {
      this.innerHTML = html ?? "";
    }
  },
);

const typing = (target) =>
  target && (target.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(target.tagName));

export default {
  // Scroll an element to its nth screen; its CSS makes the scroll smooth.
  "kai.blu.cx/scroll": {
    command: ({ id, screen }) => {
      const element = document.getElementById(id);
      if (element) element.scrollTop = screen * element.clientHeight;
    },
  },

  // An element's scroll position and height, after each scroll. Scroll
  // events don't bubble, so the document listens as they go down.
  "kai.blu.cx/scrolled": {
    subscribe: ({ id }, { emit }) => {
      const scrolled = ({ target }) => {
        if (target.id === id) emit({ top: target.scrollTop, height: target.clientHeight });
      };
      document.addEventListener("scroll", scrolled, { capture: true, passive: true });
      return () => document.removeEventListener("scroll", scrolled, { capture: true });
    },
  },

  // The keys the app takes, pressed anywhere on the page without Ctrl, ⌘ or
  // Alt and not into a text field; the browser's own action (scrolling, or
  // Tab's focus) is prevented.
  "kai.blu.cx/keys": {
    subscribe: ({ keys }, { emit }) => {
      const pressed = (event) => {
        if (event.ctrlKey || event.metaKey || event.altKey || event.defaultPrevented) return;
        if (typing(event.target) || !keys.includes(event.key)) return;
        event.preventDefault();
        emit({ key: event.key });
      };
      document.addEventListener("keydown", pressed);
      return () => document.removeEventListener("keydown", pressed);
    },
  },
};
