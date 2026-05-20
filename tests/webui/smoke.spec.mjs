// Playwright smoke tests for the teslausb-ng web UI.
//
// Goal: catch regressions in the vanilla-JS layer without needing the full
// nginx + fcgiwrap stack. The harness in test-harness.html loads
// filebrowser.js in isolation; these tests poke at the FileBrowser class.

import { test, expect } from "@playwright/test";
import { fileURLToPath } from "url";
import path from "path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const HARNESS_URL = "file://" + path.resolve(__dirname, "test-harness.html");

test("harness loads without page errors", async ({ page }) => {
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto(HARNESS_URL);
  await page.waitForLoadState("domcontentloaded");
  expect(errors).toEqual([]);
});

test("FileBrowser.htmlEscape neutralizes script payload", async ({ page }) => {
  await page.goto(HARNESS_URL);
  const escaped = await page.evaluate(() => {
    // FileBrowser is declared at top level in filebrowser.js, so it lives on
    // the global object. Instantiating it just to call the helper is fine —
    // the constructor does some DOM init we don't care about here.
    const fb = new FileBrowser(document.getElementById("fb-mount"), [
      { label: "test", path: "/" },
    ]);
    return fb.htmlEscape('<img src=x onerror="alert(1)">');
  });
  expect(escaped).toBe("&lt;img src=x onerror=&quot;alert(1)&quot;&gt;");
});

test("FileBrowser.htmlEscape leaves safe characters alone", async ({ page }) => {
  await page.goto(HARNESS_URL);
  const escaped = await page.evaluate(() => {
    const fb = new FileBrowser(document.getElementById("fb-mount"), [
      { label: "test", path: "/" },
    ]);
    return fb.htmlEscape("SavedClips/2024-01-01_12-34-56");
  });
  expect(escaped).toBe("SavedClips/2024-01-01_12-34-56");
});

test("FileBrowser.htmlEscape handles null / undefined safely", async ({ page }) => {
  await page.goto(HARNESS_URL);
  const result = await page.evaluate(() => {
    const fb = new FileBrowser(document.getElementById("fb-mount"), [
      { label: "test", path: "/" },
    ]);
    return [fb.htmlEscape(null), fb.htmlEscape(undefined), fb.htmlEscape("")];
  });
  expect(result).toEqual(["", "", ""]);
});
