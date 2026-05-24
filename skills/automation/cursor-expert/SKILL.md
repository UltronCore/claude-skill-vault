---
name: cursor-expert
description: >
  Cursor AI IDE features, rules (.cursorrules / cursor rules), composer, and custom agent workflows. Triggers on: Cursor, .cursorrules, cursor rules, @Codebase, cursor composer, Cursor agent, Cursor tab.
---

# Cursor Expert

## When to Use
Use this skill when configuring Cursor AI IDE, writing `.cursorrules` files, setting up multi-file composer workflows, using `@Codebase` / `@file` / `@doc` context, choosing between Cursor and Claude Code, or syncing rules across a team.

---

## Core Rules
- `.cursorrules` is the project-level system prompt. Make it precise, not verbose — Cursor truncates long rule files.
- Use `@Codebase` for semantic search across the repo; `@file` for pinning a specific file; `@doc` for indexed documentation.
- Composer (Cmd+I) edits multiple files at once — it's Cursor's equivalent of Claude Code's multi-file agent.
- Agent mode (Cmd+Shift+I) gives Composer tool use (terminal, file system). Use it for scaffolding and running commands.
- Cursor Tab (inline completion) is always active — `.cursorrules` biases its suggestions too.
- Rules cascade: Cursor project rules > `.cursorrules` > model defaults. Nested `.cursorrules` files apply to subtrees.

---

## .cursorrules File Structure

The `.cursorrules` file lives at the project root. It is injected as a system prompt before every request.

```
# .cursorrules — My Next.js + TypeScript Project

## Stack
- Next.js 15 (App Router), TypeScript 5.x, Tailwind CSS 4, shadcn/ui
- Postgres via Drizzle ORM, Supabase for auth and storage
- Testing: Vitest + Playwright

## Code Style
- Use `const` for all variables; `function` keyword for top-level functions
- Prefer async/await over .then() chains
- Named exports only; no default exports except for Next.js page components
- Tailwind classes: use clsx/cn helper, never inline ternaries
- Zod for all API input validation

## File Conventions
- Components: /components/<Feature>/<ComponentName>.tsx
- Server actions: /app/actions/<domain>.ts
- API routes: /app/api/<resource>/route.ts
- Utilities: /lib/<purpose>.ts

## Rules
- Always add error boundaries around async Server Components
- Never import from @/components/ui directly in server components — use wrapper
- Database calls belong in /lib/db/ files, never in components or route handlers
- All server actions must validate input with Zod before any DB call
- When creating a new component, check /components/ui for shadcn equivalents first

## Testing
- Every new util function gets a Vitest unit test
- E2E tests for all user-facing flows using Playwright page objects

## Do Not
- Do not use `any` type — use `unknown` and narrow
- Do not fetch inside useEffect — use React Query or server components
- Do not use var
- Do not use index as React key when list may reorder
```

---

## .cursorrules for Swift / iOS

```
# .cursorrules — iOS Swift Project

## Stack
- Swift 6.0, SwiftUI, iOS 18+ minimum deployment
- Swift Concurrency (async/await, actors) — no Combine, no completion handlers
- SwiftData for persistence
- No third-party dependencies without explicit approval

## Architecture
- MVVM: Views observe @Observable ViewModels, ViewModels call Service layer
- Services are actors for thread safety
- Never put business logic in SwiftUI View bodies

## Conventions
- All async code in @MainActor unless explicitly marked for background
- Preview-safe: all Views must have working #Preview macros
- Errors: typed throws (Swift 6 style), never fatalError in production paths

## Do Not
- Do not use DispatchQueue — use Task and actors
- Do not use UIKit unless bridging a specific requirement
- Do not add Combine Publishers
```

---

## Effective Rule Patterns

### Be specific about what NOT to do
```
# Bad (too vague)
Write clean code.

# Good (actionable)
Do not use `useEffect` for data fetching. Use React Query's useQuery instead.
Do not create barrel files (index.ts re-exports) unless the directory has 5+ files.
```

### Encode your architecture constraints
```
## Architecture Guard Rails
- API calls belong only in: /lib/api/*.ts and /app/actions/*.ts
- Components must receive data via props, not fetch directly
- Shared state: Zustand store in /store/<domain>.ts — never useState for cross-component state
```

### Provide concrete examples inline
```
## Error Handling Pattern
Always wrap async server actions like this:
\`\`\`typescript
export async function myAction(input: z.infer<typeof schema>) {
  const parsed = schema.safeParse(input);
  if (!parsed.success) return { error: parsed.error.flatten() };
  try {
    const result = await db.query...
    return { data: result };
  } catch (e) {
    console.error(e);
    return { error: "Internal error" };
  }
}
\`\`\`
```

---

## @Context References

| Symbol | What it does | When to use |
|--------|-------------|-------------|
| `@Codebase` | Semantic search across entire repo | "Find all places that use X" |
| `@file path/to/file.ts` | Pin a specific file into context | When editing related files |
| `@folder /src/components` | Include all files in folder | Refactoring a whole feature |
| `@doc https://...` | Indexed external documentation | Using an API/library you've indexed |
| `@web` | Live web search | Latest API changes, unknown packages |
| `@Git` | Recent git changes/diff | "What changed since last commit?" |
| `@Definitions` | Jump-to-definition context | Understanding a type/function |

### Example Composer prompts with context
```
@file src/lib/auth.ts @file src/app/api/login/route.ts
Refactor the login route to use the new signInWithPassword method from auth.ts.
Add proper error handling and return typed responses.

---

@Codebase
Find all components that directly call fetch() and refactor them to use React Query's
useQuery hook. Maintain the same types and error states.

---

@doc https://orm.drizzle.team/docs/rqb
Using the relational query builder docs, rewrite this raw SQL query as a Drizzle
relational query: SELECT * FROM users JOIN posts ON posts.user_id = users.id WHERE...
```

---

## Composer (Cmd+I) — Multi-File Edits

Composer is for changes that span multiple files. Use it when:
- Adding a new feature end-to-end (component + server action + DB schema + test)
- Renaming/moving a module across all its imports
- Applying a consistent pattern change across many files

### Effective Composer workflow
1. Open Composer (Cmd+I)
2. Write a detailed spec — include file paths, types, expected behavior
3. Review each file diff before accepting — Composer can overshoot
4. Use "Restore" per-file if a specific change is wrong
5. After accepting, run tests immediately

```
# Good Composer prompt
Create a UserAvatar component:
- File: /components/user/UserAvatar.tsx
- Props: { userId: string; size?: "sm" | "md" | "lg"; className?: string }
- Fetches user from /lib/api/users.ts (see @file src/lib/api/users.ts for shape)
- Uses next/image for the avatar image with fallback to initials
- Add a Skeleton loading state using shadcn Skeleton component
- Export as named export

Also add a Vitest test at /components/user/UserAvatar.test.tsx covering:
- Renders with valid userId
- Shows skeleton during loading
- Shows initials fallback on image error
```

---

## Agent Mode (Cmd+Shift+I)

Agent mode gives Composer the ability to:
- Run terminal commands
- Read/write files directly
- Install packages
- Run tests and see output

### When to use Agent vs Composer

| Scenario | Use |
|----------|-----|
| Multi-file code edit (no commands) | Composer (Cmd+I) |
| Scaffold + install + test | Agent (Cmd+Shift+I) |
| Add a new npm package + wire it up | Agent |
| Refactor existing code | Composer |
| Debug a failing test | Agent (it can run the test) |

### Safe Agent prompts
```
Agent: Set up Vitest for this Next.js project.
1. Install vitest, @vitejs/plugin-react, @testing-library/react, @testing-library/jest-dom
2. Create vitest.config.ts with the correct Next.js setup
3. Add test script to package.json
4. Create a sample test at /src/__tests__/example.test.ts
5. Run the test to confirm it passes — show me the output
```

---

## Cursor Tab (Inline Completion)

Cursor Tab is the always-on autocomplete. It's aware of:
- Currently open files
- Recent edits (edit trajectory)
- `.cursorrules` content

### Tips to get better Tab completions
- Type a comment describing what you want before the code: `// fetch user by id, return null if not found`
- Name variables semantically — `userRepository` gets better completions than `repo`
- Start typing the function signature; Tab completes the body
- Accept partial suggestions: Tab accepts word-by-word with Ctrl+→ on some setups

### Disable Tab for a section
```typescript
// cursor:disable-tab
// ... manually written sensitive logic ...
// cursor:enable-tab
```

---

## Cursor Rules for Frameworks (Concise Templates)

### React + TypeScript
```
Use function components with hooks. Named exports only. 
Prefer composition over prop drilling. Use React.memo only with profiler evidence.
State: useState for local, Zustand for shared. No Context for frequently-updating values.
```

### Python / FastAPI
```
Type hints on all function signatures. Pydantic v2 models for all request/response bodies.
Async route handlers. Dependency injection via Depends(). 
Tests with pytest + httpx AsyncClient. One module per router domain.
```

### Swift / SwiftUI
```
Swift 6 strict concurrency. @Observable ViewModels. SwiftData for persistence.
All Views must compile with #Preview. No force-unwrap in production code.
Error handling: typed throws, no try? that silently swallows errors.
```

---

## Syncing Rules with a Team

### Approach 1: Commit `.cursorrules` to git (simplest)
```bash
# .cursorrules is already at project root — commit it
git add .cursorrules
git commit -m "Add Cursor rules for project conventions"
```

### Approach 2: Nested rules for monorepo subprojects
```
/apps/web/.cursorrules       # Next.js frontend rules
/apps/api/.cursorrules       # FastAPI backend rules
/packages/shared/.cursorrules # Shared library rules
/.cursorrules                # Root-level cross-cutting rules
```

### Approach 3: Cursor Project Rules (UI-based, per-team-member)
Cursor Settings → Rules → Project Rules: add rules that apply only to specific file globs.
```
# Example: rules that apply only to test files
glob: **/*.test.{ts,tsx}
rules: |
  Use describe/it blocks (not test()). 
  Each test should have exactly one assertion.
  Use vi.fn() for mocks, not jest.fn().
```

---

## Cursor vs Claude Code — When to Choose Which

| Situation | Use Cursor | Use Claude Code |
|-----------|-----------|----------------|
| Inline edits in files you're actively browsing | ✓ | |
| Multi-file feature with lots of context | ✓ (Composer) | ✓ (both good) |
| Terminal-heavy workflows (deploys, DB migrations) | | ✓ (Bash tool) |
| Repo-wide analysis / search | | ✓ (grep/find) |
| Real-time pair programming feel | ✓ | |
| CI/CD, automated scripts | | ✓ |
| You want to review diffs file-by-file | ✓ | |
| Long autonomous task (30+ min) | | ✓ |

**Rule of thumb:** Cursor for editor-centric workflows. Claude Code for terminal-centric or long autonomous tasks.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `.cursorrules` not applying | Check file is at root, restart Cursor |
| Composer ignoring rules | Be explicit in the prompt; rules are hints not hard constraints |
| `@Codebase` missing files | Check `.cursorignore` — similar to `.gitignore` |
| Tab completions are off | Close unused tabs; too many open files dilutes context |
| Agent running wrong commands | Add "ask before running any terminal command" to rules |
| Rules file too long | Keep under ~2,000 tokens; cut anything that hasn't helped in a week |

## Related Skills
- `claude-api-skill` — Claude API in Cursor
- `git-guardrails-claude-code` — safe git practices
- `codebase-onboarding` — codebase exploration

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/cursor-expert/.gitnexus
Last indexed: 2026-05-23
