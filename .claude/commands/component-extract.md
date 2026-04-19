---
description: Extract a reusable UI component from existing code using TDD
allowed-tools: Read, Write, Edit, Glob, Bash(npm test:*), Bash(npx vitest:*)
argument-hint: [Path to file or description of fragment to extract]
---

## User Input

The user provided the code or file to extract from: **$ARGUMENTS**

## Do This First

1. Analyze the provided file or snippet
2. Identify a logical, reusable UI fragment
3. Determine a PascalCase component name (e.g., "user avatar with name" → UserAvatar)

## 1. Extract Component API

Before writing code, define:

- Props (keep minimal)
- Types (TypeScript)
- What stays in parent vs what moves

Keep API simple and reusable.

## 2. Write Tests First (co-located)

Create:

components/[ComponentName]/[ComponentName].test.tsx

Example:

    import { render, screen } from "@testing-library/react"
    import { describe, it, expect } from "vitest"
    import ComponentName from "./ComponentName"

    describe("ComponentName", () => {
      it("renders with required props", () => {
        render(<ComponentName />)
        expect(screen.getByTestId("component")).toBeInTheDocument()
      })

      it("renders dynamic content correctly", () => {
        render(<ComponentName />)
        expect(screen.getByText(/example/i)).toBeInTheDocument()
      })
    })

## 3. Run Tests (expect failure)

    npm test components/[ComponentName]/[ComponentName].test.tsx

## 4. Create Component

Create:

components/[ComponentName]/[ComponentName].tsx  
components/[ComponentName]/[ComponentName].module.css  
components/[ComponentName]/index.ts  

Example:

    import styles from "./ComponentName.module.css"

    type Props = {}

    export default function ComponentName(props: Props) {
      return (
        <div data-testid="component" className={styles.wrapper}>
          example
        </div>
      )
    }

index.ts:

    export { default } from "./ComponentName"

## 5. Replace Original Code

- Replace extracted fragment with new component
- Pass props from parent
- Remove duplicated markup
- Keep logic in the highest reasonable level

## 6. Run Tests (expect pass)

    npm test components/[ComponentName]/[ComponentName].test.tsx

## 7. Verify Integration

- Ensure original page/component still works
- Fix broken props if needed
- Avoid over-engineering

## Rules

- Keep extracted component small and focused
- Do not extract too early (avoid over-abstraction)
- Props should be minimal and explicit
- Keep logic close to where it's used unless reusable
- Co-locate tests with component
- No semicolons
- Use CSS Modules
- Only proceed when current step passes
