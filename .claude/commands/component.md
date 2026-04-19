---
description: Create a UI component using TDD (test-driven development)
allowed-tools: Read, Write, Edit, Glob, Bash(npm test:*), Bash(npx vitest:*)
argument-hint: [Brief description]
---

## User Input

The user has provided information about the component to make: **$ARGUMENTS**

## Do This First

From the component information above, determine a PascalCase component name  
(e.g., "a card showing user stats" → UserStatsCard)

## 1. Write Tests First (co-located)

Create:

components/[ComponentName]/[ComponentName].test.tsx

Example:

    import { render, screen } from "@testing-library/react"
    import { describe, it, expect } from "vitest"
    import ComponentName from "./ComponentName"

    describe("ComponentName", () => {
      it("renders successfully", () => {
        render(<ComponentName />)
        expect(screen.getByTestId("component")).toBeInTheDocument()
      })

      it("displays expected text", () => {
        render(<ComponentName />)
        expect(screen.getByText(/example/i)).toBeInTheDocument()
      })
    })

## 2. Run Tests (expect failure)

    npm test components/[ComponentName]/[ComponentName].test.tsx

## 3. Create Component

Create:

components/[ComponentName]/[ComponentName].tsx  
components/[ComponentName]/[ComponentName].module.css  
components/[ComponentName]/index.ts  

Example component:

    import styles from "./ComponentName.module.css"

    export default function ComponentName() {
      return (
        <div data-testid="component" className={styles.wrapper}>
          example
        </div>
      )
    }

index.ts:

    export { default } from "./ComponentName"

## 4. Run Tests (expect pass)

    npm test components/[ComponentName]/[ComponentName].test.tsx

## 5. Add to Preview Page

Update:

app/(public)/preview/page.tsx

Add a labeled section rendering the component.

## Rules

- Keep tests minimal (2–3 max)
- Co-locate tests with component
- Use relative imports (./ComponentName)
- No semicolons
- Use CSS Modules
- Only proceed when current step passes