import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: ".",
  testMatch: /.*\.spec\.mjs$/,
  fullyParallel: true,
  reporter: process.env.CI ? "github" : "list",
  use: {
    headless: true,
    // file:// URLs need this to allow the harness to load filebrowser.js
    // from the parent directory.
    launchOptions: { args: ["--allow-file-access-from-files"] },
  },
  projects: [
    {
      name: "chromium",
      use: { browserName: "chromium" },
    },
  ],
});
