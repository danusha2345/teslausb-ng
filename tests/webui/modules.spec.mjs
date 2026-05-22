// Playwright unit tests for the pure-function modules extracted from
// index.html during the v1.1.2 ES-module split (utils.js, formatters.js).
//
// These lock in the refactor: if a future slice accidentally changes the
// behavior of a moved helper, CI catches it here instead of a user noticing
// a mangled "Disk usage" string. The harness loads the modules in isolation;
// each test calls the global function via page.evaluate.

import { test, expect } from "@playwright/test";
import { fileURLToPath } from "url";
import path from "path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const HARNESS_URL = "file://" + path.resolve(__dirname, "modules-harness.html");

test("modules harness loads without page errors", async ({ page }) => {
  const errors = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto(HARNESS_URL);
  await page.waitForLoadState("domcontentloaded");
  expect(errors).toEqual([]);
});

test("formatters.js exposes its helpers as globals", async ({ page }) => {
  await page.goto(HARNESS_URL);
  const types = await page.evaluate(() =>
    [
      "byteRate",
      "bitRate",
      "uptimeString",
      "spaceString",
      "timeString",
      "dateFromSeconds",
      "dayNameFromDateString",
      "stringtoseconds",
      "secondstostring",
    ].map((name) => typeof window[name])
  );
  expect(types.every((t) => t === "function")).toBe(true);
});

test("byteRate switches unit at the 500 KB/s threshold", async ({ page }) => {
  await page.goto(HARNESS_URL);
  const out = await page.evaluate(() => [
    byteRate(1048576), // 1 MiB/s, above threshold
    byteRate(10240), // 10 KiB/s, below threshold
  ]);
  expect(out).toEqual(["1.0 MB/s", "10.0 KB/s"]);
});

test("bitRate decimals depend on the 2.5 MB/s cutoff", async ({ page }) => {
  await page.goto(HARNESS_URL);
  const out = await page.evaluate(() => [
    bitRate(1000000), // 8 Mbit, one decimal (under 20 Mbit)
    bitRate(5000000), // 40 Mbit, no decimal
  ]);
  expect(out).toEqual(["8.0 Mbit/s", "40 Mbit/s"]);
});

test("uptimeString formats days + HH:MM:SS", async ({ page }) => {
  await page.goto(HARNESS_URL);
  const out = await page.evaluate(() => [
    uptimeString(90061), // 1 day, 01:01:01
    uptimeString(3661), // 01:01:01, no day prefix
    uptimeString(172800), // exactly 2 days
  ]);
  expect(out).toEqual(["1 day, 01:01:01", "01:01:01", "2 days, 00:00:00"]);
});

test("spaceString picks G/M units sensibly", async ({ page }) => {
  await page.goto(HARNESS_URL);
  const out = await page.evaluate(() => [
    spaceString(2 * 1024 * 1024 * 1024), // 2G
    spaceString(50 * 1024 * 1024), // 50M
  ]);
  expect(out).toEqual(["2G", "50M"]);
});

test("timeString omits the hour when zero", async ({ page }) => {
  await page.goto(HARNESS_URL);
  const out = await page.evaluate(() => [
    timeString(3661000), // 1:01:01
    timeString(61000), // 01:01
  ]);
  expect(out).toEqual(["1:01:01", "01:01"]);
});

test("stringtoseconds / secondstostring round-trip the scrubber format", async ({ page }) => {
  await page.goto(HARNESS_URL);
  const out = await page.evaluate(() => [
    stringtoseconds("01:01:01"), // 3661
    secondstostring(3661), // "01:01" (seconds intentionally dropped)
  ]);
  expect(out).toEqual([3661, "01:01"]);
});

test("utils.js exposes its helpers as globals", async ({ page }) => {
  await page.goto(HARNESS_URL);
  const types = await page.evaluate(() =>
    ["localStorageGet", "localStorageSet", "log", "download", "cachebustingurl", "isElementVisible"].map(
      (name) => typeof window[name]
    )
  );
  expect(types.every((t) => t === "function")).toBe(true);
});

test("cachebustingurl appends a query string", async ({ page }) => {
  await page.goto(HARNESS_URL);
  const out = await page.evaluate(() => {
    const u = cachebustingurl("cgi-bin/status.sh");
    return u.startsWith("cgi-bin/status.sh?") && u.length > "cgi-bin/status.sh?".length;
  });
  expect(out).toBe(true);
});
