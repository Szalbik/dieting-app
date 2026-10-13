// Risk (offline-first plan, Phase 5): in a shop without signal, ticks and own
// items added on the shopping list are lost or duplicated instead of landing on
// the server once the phone is back online.
// Modeled on e2e/seed.spec.js; rules in e2e/RULES.md.
const { test, expect } = require("@playwright/test")

const PRODUCT = "Pomidor"

test.describe("offline shopping list", () => {
  let ownItem

  test.beforeEach(async ({ page }) => {
    ownItem = `Chleb ${Date.now()}`
    await page.goto("/shopping_cart")
    // The service worker must control the page and hold a copy of it before the network goes away.
    await page.evaluate(() => navigator.serviceWorker.ready)
    await page.reload()
    await expect.poll(() => page.evaluate(async () => !!(await caches.match("/shopping_cart", { ignoreVary: true })))).toBe(true)
  })

  test.afterEach(async ({ page, context }) => {
    // Cleanup, online: unbuy the product, remove the own item.
    await context.setOffline(false)
    await page.goto("/shopping_cart")
    const box = page.getByRole("button", { name: `Kupione: ${PRODUCT}` })
    if ((await box.getAttribute("aria-pressed")) === "true") {
      await box.click()
      await expect(page.getByRole("status")).toHaveText("✓ Zsynchronizowano")
    }
    const remove = page.getByRole("button", { name: `Usuń: ${ownItem}` })
    if (await remove.count()) {
      await remove.click()
      await expect(remove).toHaveCount(0)
    }
  })

  test("ticks and own items made offline survive a reload and land on the server once after reconnect", async ({ page, context }) => {
    // Lose the signal
    await context.setOffline(true)

    // Tick a product and add an own item while offline: both show immediately
    await page.getByRole("button", { name: `Kupione: ${PRODUCT}` }).click()
    await expect(page.getByRole("button", { name: `Kupione: ${PRODUCT}` })).toHaveAttribute("aria-pressed", "true")
    await page.getByPlaceholder("np. ręcznik papierowy").fill(ownItem)
    await page.getByRole("button", { name: "Dodaj" }).click()
    await expect(page.getByText(ownItem)).toBeVisible()
    await expect(page.getByRole("status")).toHaveText("Offline · 2 do zsynchronizowania")

    // Reopen the list without signal: served from the phone, pending changes still shown
    await page.reload()
    await expect(page.getByRole("button", { name: `Kupione: ${PRODUCT}` })).toHaveAttribute("aria-pressed", "true")
    await expect(page.getByText(ownItem)).toBeVisible()

    // Signal is back: the queue syncs in the background
    await context.setOffline(false)
    await expect(page.getByRole("status")).toHaveText("✓ Zsynchronizowano", { timeout: 15000 })

    // Server truth (straight from the app, not the service worker): bought, and the own item exists exactly once
    const html = await (await page.request.get("/shopping_cart")).text()
    expect(html).toMatch(new RegExp(`aria-label="Kupione: ${PRODUCT}" aria-pressed="true"`))
    expect(html.split(`Usuń: ${ownItem}`).length - 1).toBe(1)
  })
})
