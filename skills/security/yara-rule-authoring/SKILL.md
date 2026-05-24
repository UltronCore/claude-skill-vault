---
name: yara-rule-authoring
description: Develop YARA rules for malware detection, threat hunting, and file classification across malware families and attack tools.
---

# YARA Rule Authoring

## Overview
Develop YARA rules for malware detection, threat hunting, and file classification. Create rules that accurately identify malicious files, malware families, attack tools, and suspicious patterns across file samples.

## Trigger
Use when asked to write YARA rules, detect malware patterns, build threat hunting signatures, classify files by family, or create detection logic for security tools.

## YARA Rule Structure

```yara
rule RuleName : tag1 tag2
{
    meta:
        author = "Author Name"
        description = "What this rule detects"
        date = "2026-05-08"
        reference = "https://source.example.com"
        hash = "sha256ofSample"
        severity = "high"
        tlp = "white"

    strings:
        $s1 = "string literal"
        $s2 = { 4D 5A 90 00 }  // hex bytes
        $s3 = /regex[0-9]+/    // regex
        $wide1 = "Wide string" wide
        $ascii_wide = "both" ascii wide nocase

    condition:
        uint16(0) == 0x5A4D and  // MZ header
        filesize < 1MB and
        any of ($s*)
}
```

## String Types

### Text Strings
```yara
$s = "exact match"
$s = "case insensitive" nocase
$s = "wide char" wide          // UTF-16LE
$s = "both encodings" ascii wide
$s = "no special" fullword     // must be delimited
```

### Hex Patterns
```yara
$hex = { 4D 5A ?? 00 }         // ?? = wildcard byte
$hex = { 4D [2-4] 5A }         // [n-m] = variable skip
$hex = { (4D | 5A) 90 }        // (a|b) = alternatives
```

### Regular Expressions
```yara
$re = /http[s]?:\/\/[a-z0-9]{8,16}\.onion/
$re = /[A-Za-z0-9+\/]{40,}={0,2}/ nocase  // Base64
```

## Condition Operators

### File Property Checks
```yara
filesize < 500KB
filesize > 1MB and filesize < 10MB
uint16(0) == 0x5A4D    // PE file (MZ magic)
uint32(0) == 0x464C457F // ELF file
uint32(0) == 0xFEEDFACE // Mach-O
```

### String Match Conditions
```yara
$s1                        // $s1 matches anywhere
$s1 at 0                   // matches at offset 0
$s1 in (0..1024)           // matches in first 1KB
all of them                // all strings must match
any of ($s*)               // any string with prefix $s
2 of ($key*)               // at least 2 of $key* strings
```

### PE Module
```yara
import "pe"

condition:
    pe.is_pe and
    pe.number_of_sections > 6 and
    pe.imphash() == "deadbeef..." and
    for any i in (0..pe.number_of_sections-1):
        (pe.sections[i].name == ".enigma")
```

## Workflow

### 1. Gather Samples
Collect 3-10 samples of the malware/pattern to detect. Ensure diversity within the family.

### 2. Identify Unique Strings
- Run `strings` on samples
- Use hex editor to find unique byte sequences
- Look for: C2 domains, mutex names, registry keys, file paths, error messages, PDB paths

### 3. Find Common Patterns
Use tools like `yaraGen`, `BASS`, or manual diff:
```bash
# Extract strings common across samples but rare in benign files
python3 yarGen.py -m /samples/ -o generated.yar
```

### 4. Write Minimal Condition
Start specific, add flexibility only as needed:
- Prefer unique strings over generic ones
- Combine multiple weak indicators with `and`
- Use file type checks as gates

### 5. Test and Tune
```bash
# Test against samples
yara rule.yar /samples/

# Test against clean files
yara rule.yar /benign/ 2>/dev/null
```

Target: 0 false positives, >90% true positive rate on known samples.

### 6. Performance Optimization
- Put cheap checks first (filesize, magic bytes)
- Avoid wide regex on large files
- Use `at` offsets when pattern location is known
- Minimize use of `nocase` on long strings

## Output
Deliver:
- Ready-to-use `.yar` file with complete metadata
- Test command to validate against samples
- Notes on expected false positive rate and tuning tips
- References to samples or threat reports used

## Related Skills
- `security-pen-testing` — penetration testing
- `static-code-analysis` — code analysis
- `semgrep-rule-creator` — alternative rule format

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/yara-rule-authoring/.gitnexus
Last indexed: 2026-05-23
