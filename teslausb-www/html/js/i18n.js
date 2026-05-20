// teslausb-ng — minimal client-side i18n loader.
//
// Language selection order:
//   1. ?lang=xx in the URL  (wins over everything; also persists)
//   2. localStorage.lang    (set by step 1 on a previous visit)
//   3. navigator.language   (browser preference; first 2 chars)
//   4. "en"                  (fallback)
//
// Strings live in i18n/<code>.json. Elements opt in with data-i18n="key";
// the loader sets textContent (safer than innerHTML — Tesla can dictate
// filenames but we control the keys here).
//
// To add a language:
//   * cp i18n/en.json i18n/<code>.json, translate the values
//   * add the matching entry to LANGS below
//
// To add a string:
//   * add the key to every json under i18n/
//   * tag the matching DOM element with data-i18n="<key>"

(function () {
  const LANGS = ["en", "ru"];

  function pickLang() {
    const url = new URL(window.location.href);
    const fromUrl = url.searchParams.get("lang");
    if (fromUrl && LANGS.includes(fromUrl)) {
      try {
        localStorage.setItem("lang", fromUrl);
      } catch (_) {}
      return fromUrl;
    }
    try {
      const stored = localStorage.getItem("lang");
      if (stored && LANGS.includes(stored)) {
        return stored;
      }
    } catch (_) {}
    const nav = (navigator.language || "en").slice(0, 2);
    return LANGS.includes(nav) ? nav : "en";
  }

  async function loadStrings(lang) {
    try {
      const res = await fetch(`i18n/${lang}.json`, { cache: "no-cache" });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return await res.json();
    } catch (e) {
      // Fall back to English if the requested locale is missing.
      if (lang !== "en") return loadStrings("en");
      // Last resort: empty dict; elements stay as-authored in HTML.
      return {};
    }
  }

  function apply(strings) {
    for (const el of document.querySelectorAll("[data-i18n]")) {
      const key = el.dataset.i18n;
      if (Object.prototype.hasOwnProperty.call(strings, key)) {
        el.textContent = strings[key];
      }
    }
    document.documentElement.setAttribute("lang", strings.$meta?.code || "en");
  }

  (async function init() {
    const lang = pickLang();
    const strings = await loadStrings(lang);
    apply(strings);
  })();
})();
