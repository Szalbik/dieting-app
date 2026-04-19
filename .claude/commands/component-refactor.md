---
description: Refactor an existing UI component for clarity, reuse, and maintainability
allowed-tools: Read, Write, Edit, Glob, Bash(npm test:*), Bash(npx vitest:*)
argument-hint: [Path to component or brief refactor request]
---

## User Input

The user provided the component or refactor target: **$ARGUMENTS**

## Goal

Refactor the target component without changing user-visible behavior unless explicitly required.

Focus on:

- readability
- smaller logical units
- clearer props
- reduced duplication
- safer type usage
- preserving existing behavior

## 1. Understand Before Changing

First:

- locate the target component
- read related files if needed
- understand current props, state, and rendering flow
- identify the smallest safe refactor

Do not start rewriting blindly.

## 2. Preserve Behavior

Before making changes:

- identify what behavior must stay the same
- keep existing public API unless there is a clear reason to improve it
- avoid unnecessary renaming unless it improves clarity significantly

If tests already exist, use them as behavior constraints.

## 3. Add or Update Tests First

Prefer co-located tests.

If test file does not exist, create:

components/[ComponentName]/[ComponentName].test.tsx

Add 2–4 focused tests that protect current behavior.

Example:

    import { render, screen } from "@testing-library/react"
    import { describe, it, expect } from "vitest"
    import ComponentName from "./ComponentName"

    describe("ComponentName", () => {
      it("renders successfully", () => {
        render(<ComponentName />)
        expect(screen.getByTestId("component")).toBeInTheDocument()
      })

      it("preserves visible content", () => {
        render(<ComponentName />)
        expect(screen.getByText(/example/i)).toBeInTheDocument()
      })
    })

## 4. Run Tests Before Refactor

Run the smallest relevant test scope first.

    npm test components/[ComponentName]/[ComponentName].test.tsx

If broader confidence is needed, run related tests too.

## 5. Refactor Safely

Apply the minimal safe refactor.

Possible refactors:

- extract small helper functions
- simplify conditional rendering
- improve naming
- remove duplicated JSX
- split large markup into small local pieces
- clarify prop types
- remove dead code if clearly unused

Avoid:

- changing behavior unnecessarily
- broad rewrites
- style-only churn
- introducing abstractions without clear benefit

## 6. Keep File Structure Sensible

If needed, use:

components/[ComponentName]/[ComponentName].tsx  
components/[ComponentName]/[ComponentName].module.css  
components/[ComponentName]/index.ts  

Use CSS Modules and no semicolons.

If extracting a child component, prefer co-locating it in the same component folder first.

## 7. Run Tests After Refactor

Run the same focused test file again:

    npm test components/[ComponentName]/[ComponentName].test.tsx

If needed, run additional related tests to confirm integration.

## 8. Summarize Changes

At the end, provide a short summary covering:

- what was refactored
- what behavior was preserved
- any props or structure changes
- any follow-up improvements worth doing later

## Rules

- preserve behavior first
- prefer small safe refactors
- keep tests focused and minimal
- co-locate tests with component
- use relative imports where appropriate
- no semicolons
- use CSS Modules
- do not over-engineer
- only proceed when the current step is stable