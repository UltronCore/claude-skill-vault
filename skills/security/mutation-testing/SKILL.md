---
name: mutation-testing
description: Configure and run mutation testing to evaluate test suite quality, revealing gaps in coverage and security-critical logic verification.
---

# Mutation Testing

## Overview
Configure and run mutation testing to evaluate test suite quality and code robustness. Mutation testing introduces small code changes (mutations) and verifies that existing tests catch them, revealing gaps in test coverage and security-critical logic.

## Trigger
Use when asked to configure mutation testing, evaluate test quality, improve test robustness, check if tests catch security-relevant edge cases, or set up mutation testing in CI.

## Supported Tools by Language

| Language | Tool | Install |
|----------|------|---------|
| JavaScript/TypeScript | Stryker | `npm install --save-dev @stryker-mutator/core` |
| Python | mutmut | `pip install mutmut` |
| Java | PIT (Pitest) | Maven/Gradle plugin |
| Go | go-mutesting | `go get github.com/zimmski/go-mutesting` |
| Rust | cargo-mutants | `cargo install cargo-mutants` |
| C/C++ | mull | Build from source or use Docker image |

## Mutation Operators (What Gets Changed)

Common mutations applied to source code:
- **Arithmetic**: `+` → `-`, `*` → `/`
- **Relational**: `>` → `>=`, `==` → `!=`
- **Logical**: `&&` → `||`, `!` removed
- **Statement deletion**: Remove a line entirely
- **Return value**: Return `null`, `0`, `true`, `false` instead of computed value
- **Boundary**: `<` → `<=`, off-by-one changes

## Workflow

### 1. JavaScript/TypeScript with Stryker

```bash
# Initialize
npx stryker init

# stryker.config.json
{
  "mutate": ["src/**/*.ts", "!src/**/*.spec.ts"],
  "testRunner": "jest",
  "reporters": ["html", "json", "progress"],
  "coverageAnalysis": "perTest",
  "thresholds": { "high": 80, "low": 60, "break": 50 }
}

# Run
npx stryker run
```

### 2. Python with mutmut

```bash
# Run mutation testing
mutmut run --paths-to-mutate=src/

# Check results
mutmut results
mutmut show <id>  # see specific survivor

# HTML report
mutmut html
```

### 3. Java with PIT (Maven)

```xml
<!-- pom.xml -->
<plugin>
  <groupId>org.pitest</groupId>
  <artifactId>pitest-maven</artifactId>
  <version>1.15.0</version>
  <configuration>
    <targetClasses>
      <param>com.example.*</param>
    </targetClasses>
    <targetTests>
      <param>com.example.*Test</param>
    </targetTests>
    <mutators>STRONGER</mutators>
    <outputFormats><value>HTML</value><value>JSON</value></outputFormats>
  </configuration>
</plugin>
```
```bash
mvn org.pitest:pitest-maven:mutationCoverage
```

### 4. Rust with cargo-mutants

```bash
# Run all mutations
cargo mutants

# Target specific files
cargo mutants --file src/auth.rs

# Show survivors
cargo mutants --output json | jq '.survivors[]'
```

## Interpreting Results

### Mutation Score
```
Mutation Score = (Killed Mutations / Total Mutations) × 100
```
- **>80%**: Strong test suite
- **60-80%**: Acceptable, focus on critical modules
- **<60%**: Significant gaps, tests are mostly checking happy paths

### Surviving Mutations (Failures)
A surviving mutation = a test gap. For each survivor:
1. Understand what the mutation changed
2. Determine if that path matters for correctness/security
3. Write a new test that kills the mutant

### Security-Focused Analysis
Pay extra attention to survivors in:
- Authentication and authorization logic
- Input validation routines
- Boundary conditions in buffer/size checks
- Cryptographic operations
- Error handling paths

## CI Integration
```yaml
# GitHub Actions example
- name: Run mutation tests
  run: npx stryker run
  
- name: Check mutation score threshold
  run: |
    SCORE=$(cat reports/mutation/json/mutation-report.json | jq '.mutationScore')
    if (( $(echo "$SCORE < 70" | bc -l) )); then
      echo "Mutation score $SCORE below threshold 70"
      exit 1
    fi
```

## Output
Produce:
- Mutation score summary per module
- List of surviving mutations (test gaps) sorted by security relevance
- Specific test cases to write for critical survivors
- CI configuration snippet for ongoing monitoring

## Related Skills
- `test-driven-development` — TDD foundation
- `static-code-analysis` — code quality
- `find-bugs` — bug detection

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/mutation-testing/.gitnexus
Last indexed: 2026-05-23
