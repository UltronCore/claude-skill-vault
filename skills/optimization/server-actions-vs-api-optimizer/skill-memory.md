# Skill Memory: Server Actions vs API Routes Optimizer

## Purpose
Analyzes Next.js App Router codebases to recommend correct usage of Server Actions vs API route handlers. Applies a decision matrix covering form submissions (prefer Server Actions), external API proxying (prefer API routes), webhooks (API routes), data mutations with revalidatePath (Server Actions), and authentication patterns. Generates migration plans with before/after code examples and complexity ratings. Includes automated route scanning via scripts/analyze_routes.py.

## Category notes
Belongs in optimization because choosing the wrong pattern introduces unnecessary round-trips, loses built-in CSRF protection, increases maintenance complexity, and can degrade performance — the skill eliminates these inefficiencies through architectural analysis.

## Relationships
- Output of form-generator-rhf-zod includes Server Actions that this skill would validate as correctly patterned
- claude-usage-orchestrator can route route analysis tasks to the appropriate reasoning lane
- Performance improvements from correct routing can affect metrics tracked by performance-budget-enforcer

## Maintenance notes
Decision matrix is in references/decision_matrix.md. Analysis script is scripts/analyze_routes.py. Recommendations are based on Next.js App Router conventions — update if Next.js introduces breaking changes to Server Actions or route handler APIs.
