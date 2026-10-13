# E2E Testing Rules

- Use getByRole, getByLabel, getByText as primary locators.
  Fall back to getByTestId only when accessibility attributes are ambiguous.
- Never use CSS selectors, XPath, or DOM structure for locating elements.
- Each test must be independently runnable — no shared state between tests.
- Never use page.waitForTimeout(). Wait for specific conditions:
  toBeVisible(), toHaveAttribute(), waitForURL(), expect.poll().
- Assert the business outcome (server truth, what the user sees), not implementation details.
- Use unique identifiers (e.g., timestamp suffix) for test data
  to avoid collisions. Clean up in afterEach.
- Use storageState for authentication — never log in through UI
  in individual tests (`e2e/auth.setup.js`).
- Model new specs on `e2e/seed.spec.js`.
