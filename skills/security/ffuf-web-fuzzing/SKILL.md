# ffuf Web Fuzzing

## Overview
Expert web fuzzing with ffuf (Fuzz Faster U Fool) for penetration testing. Discover hidden endpoints, parameters, subdomains, virtual hosts, and vulnerabilities through systematic fuzzing.

## Trigger
Use when asked to fuzz a web application, discover hidden paths or parameters, enumerate subdomains, or perform directory/file brute-forcing as part of a penetration test.

## Prerequisites
- `ffuf` installed: `go install github.com/ffuf/ffuf/v2@latest`
- Wordlists: SecLists (`/usr/share/seclists/` or download from github.com/danielmiessler/SecLists)
- **Written authorization** to test the target

## Core Usage

### Directory/Path Fuzzing
```bash
ffuf -w /path/to/wordlist.txt \
     -u https://target.com/FUZZ \
     -mc 200,301,302,403 \
     -o results.json -of json
```

### File Extension Fuzzing
```bash
ffuf -w /path/to/wordlist.txt \
     -u https://target.com/FUZZ.php \
     -mc 200,301
```

### Parameter Fuzzing (GET)
```bash
ffuf -w /path/to/params.txt \
     -u "https://target.com/api?FUZZ=test" \
     -mc 200 -fw 42
```

### Parameter Fuzzing (POST)
```bash
ffuf -w /path/to/params.txt \
     -u https://target.com/api/login \
     -X POST \
     -d "FUZZ=value&other=data" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -mc 200
```

### Subdomain Fuzzing
```bash
ffuf -w /path/to/subdomains.txt \
     -u https://FUZZ.target.com \
     -mc 200,301,302
```

### Virtual Host Fuzzing
```bash
ffuf -w /path/to/vhosts.txt \
     -u https://target.com \
     -H "Host: FUZZ.target.com" \
     -mc 200 -fs 4242
```

## Advanced Options

### Filtering
- `-mc` — match HTTP status codes
- `-ms` — match response size
- `-mw` — match word count
- `-ml` — match line count
- `-mr` — match regex in response
- `-fc` — filter status codes
- `-fs` — filter response size (remove baseline)
- `-fw` — filter word count
- `-fl` — filter line count

### Performance Tuning
```bash
-t 50        # threads (default 40)
-rate 1000   # requests per second limit
-timeout 10  # per-request timeout
-p 0.1       # pause between requests (seconds)
```

### Authentication
```bash
-H "Authorization: Bearer <token>"
-H "Cookie: session=<value>"
-b "session=<value>"
```

### Multi-position Fuzzing
```bash
# Fuzz multiple positions simultaneously
ffuf -w wordlist1.txt:FUZZ1 -w wordlist2.txt:FUZZ2 \
     -u https://target.com/FUZZ1/FUZZ2
```

## Workflow

### 1. Establish Baseline
- Make a normal request and note response size/word count
- Use `-fs` or `-fw` to filter out the baseline (404 pages)

### 2. Choose Wordlists (SecLists)
- Paths: `Discovery/Web-Content/common.txt`, `raft-medium-directories.txt`
- Files: `Discovery/Web-Content/raft-medium-files.txt`
- Subdomains: `Discovery/DNS/subdomains-top1million-5000.txt`
- Parameters: `Discovery/Web-Content/burp-parameter-names.txt`

### 3. Start Broad, Then Narrow
1. General directory scan with common wordlist
2. Technology-specific wordlist based on stack detected
3. Recursive fuzzing on interesting findings

### 4. Analyze Results
- Investigate all non-filtered responses
- Check 403s — may be bypassable
- Check redirect targets
- Look for API endpoints suggesting functionality

## Output
Provide:
- ffuf command(s) used with explanation
- Summary of discovered paths/parameters
- Interesting findings with follow-up recommendations
- Suggested next steps for manual investigation
