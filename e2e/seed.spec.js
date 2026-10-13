// Seed exemplar: role-based locators, wait for state, server-truth assertion, cleanup.
const { test, expect } = require("@playwright/test")

test.describe("shopping list", () => {
  test.afterEach(async ({ page }) => {
    // Cleanup: leave "Banan" unbought for the next run.
    const box = page.getByRole("button", { name: "Kupione: Banan" })
    if ((await box.getAttribute("aria-pressed")) === "true") {
      await box.click()
      await expect(page.getByRole("status")).toHaveText("✓ Zsynchronizowano")
    }
  })

  test("a ticked item stays bought after reload", async ({ page }) => {
    await page.goto("/shopping_cart")

    await page.getByRole("button", { name: "Kupione: Banan" }).click()
    await expect(page.getByRole("status")).toHaveText("✓ Zsynchronizowano")

    await page.reload()
    await expect(page.getByRole("button", { name: "Kupione: Banan" })).toHaveAttribute("aria-pressed", "true")
  })
})
