# C/C++ Security Review

## Overview
Comprehensive security review of C and C++ codebases using parallel static analysis workers. Identifies memory safety issues, undefined behavior, integer overflows, format string vulnerabilities, and other common C/C++ security bugs.

## Trigger
Use this skill when asked to review C or C++ code for security vulnerabilities, memory safety issues, or to perform a security audit of a C/C++ codebase.

## Workflow

### 1. Scope the Review
- Identify entry points and trust boundaries
- Map data flows from external input to sensitive operations
- List all external dependencies and third-party libraries

### 2. Memory Safety Analysis
- Buffer overflows (stack and heap)
- Use-after-free and double-free vulnerabilities
- Null pointer dereferences
- Uninitialized memory reads
- Out-of-bounds array accesses

### 3. Integer Vulnerabilities
- Integer overflow/underflow
- Signed/unsigned conversion bugs
- Off-by-one errors in loop bounds and buffer sizing
- Truncation when converting between int sizes

### 4. Format String Vulnerabilities
- Uncontrolled format strings in printf-family functions
- Logging functions that accept user-controlled format strings

### 5. Injection and Command Execution
- Command injection via system(), popen(), exec-family
- Path traversal vulnerabilities
- SQL injection in database-connected code

### 6. Cryptographic Issues
- Weak or deprecated algorithms (MD5, SHA1, DES)
- Hardcoded keys or IVs
- Insecure random number generation
- Improper certificate validation

### 7. Concurrency Bugs
- Race conditions and TOCTOU vulnerabilities
- Deadlocks and lock ordering issues
- Signal handler safety

### 8. Static Analysis Tools
Run the following tools and aggregate results:
- `cppcheck --enable=all <path>`
- `clang --analyze <files>`
- `flawfinder <path>`
- `rats <path>` (if available)
- Address Sanitizer (ASan) for runtime detection

### 9. Report Format
For each finding:
- **Severity**: Critical / High / Medium / Low / Informational
- **CWE**: Relevant CWE identifier
- **Location**: File:line
- **Description**: What the vulnerability is
- **Exploit scenario**: How it could be exploited
- **Remediation**: Specific fix recommendation

## Output
Produce a structured security review report with an executive summary, findings table sorted by severity, and detailed per-finding writeups.
