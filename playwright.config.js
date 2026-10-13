// @ts-check
const { defineConfig, devices } = require("@playwright/test")

// Browser-level checks for the offline flow (service worker + outbox + session + DB).
// Runs against the dev server with a throwaway user seeded into the dev database.
//   bin/e2e            # all specs
//   bin/e2e offline    # one spec by name
module.exports = defineConfig({
  testDir: "e2e",
  fullyParallel: false,
  workers: 1, // one seeded user, one shopping list
  retries: 0,
  reporter: "list",
  globalSetup: "./e2e/global-setup.js",
  globalTeardown: "./e2e/global-teardown.js",
  use: {
    baseURL: process.env.E2E_BASE_URL || "http://localhost:3000",
    ...devices["iPhone 13"],
    defaultBrowserType: "chromium", // service workers + setOffline; WebKit runs aren't automated
    serviceWorkers: "allow",
    trace: "retain-on-failure"
  },
  projects: [
    { name: "setup", testMatch: /auth\.setup\.js/ },
    { name: "mobile", dependencies: ["setup"], use: { storageState: "e2e/.auth/user.json" } }
  ],
  webServer: {
    command: "bin/rails server -p 3000",
    url: "http://localhost:3000/up",
    reuseExistingServer: true
  }
})
