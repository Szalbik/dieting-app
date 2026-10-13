const { test: setup, expect } = require("@playwright/test")

// Sign in over HTTP (no UI) and store the session cookie for every spec.
setup("authenticate the e2e user", async ({ request }) => {
  const form = await (await request.get("/session/new")).text()
  const token = form.match(/name="authenticity_token" value="([^"]+)"/)[1]
  const response = await request.post("/session", {
    form: { authenticity_token: token, email_address: "offline-e2e@example.com", password: "offline-e2e-123" },
    maxRedirects: 0
  })
  expect(response.status()).toBe(302)
  expect(response.headers().location).not.toContain("/session")
  await request.storageState({ path: "e2e/.auth/user.json" })
})
