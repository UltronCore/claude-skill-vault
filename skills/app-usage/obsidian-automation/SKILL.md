---
name: obsidian-automation
description: >
  Automate Obsidian vault operations: Templater, Dataview queries, QuickAdd, plugin APIs, and shell-based vault management. Triggers on: Obsidian, templater, dataview, QuickAdd, obsidian vault, obsidian plugin, .md frontmatter YAML.
---

# Obsidian Automation

## When to Use

Trigger this skill whenever the user mentions Obsidian, Templater, Dataview, QuickAdd, frontmatter YAML, or vault file management. Use it for template creation, query writing, plugin configuration, daily note automation, and shell-based vault operations.

---

## Core Rules

- Vault root is `~/obsidian-vault/` (the user's setup — confirm if working in a different vault)
- Obsidian MCP runs on port 27123
- Plugin data lives in `.obsidian/plugins/<plugin-name>/data.json`
- Never modify `.obsidian/workspace.json` programmatically — it will corrupt the UI state
- Always use `---` fenced frontmatter with valid YAML

---

## Frontmatter Conventions

```yaml
---
title: Note Title
date: 2026-05-10
tags: [project, reference]
status: active          # active | paused | done | archived
type: note              # note | project | daily | template | MOC
aliases: [short-name]
---
```

Standard tag taxonomy:
- `#project/` — project notes
- `#daily/` — daily notes
- `#ref/` — reference material
- `#log/` — event/decision logs

---

## Templater Basics

Templater runs templates with `<%* ... %>` (script) and `<% ... %>` (expression) tags.

### Common Variables

```javascript
// Date/time
<% tp.date.now("YYYY-MM-DD") %>
<% tp.date.now("ddd, MMM D") %>
<% tp.date.tomorrow("YYYY-MM-DD") %>
<% tp.date.weekday("YYYY-MM-DD", 1) %>  // next Monday

// File info
<% tp.file.title %>
<% tp.file.folder() %>
<% tp.file.path() %>
<% tp.file.creation_date("YYYY-MM-DD") %>

// User prompts
<% await tp.system.prompt("Note title?") %>
<% await tp.system.suggester(["Option A", "Option B"], ["a", "b"]) %>
```

### Daily Note Template

```markdown
---
date: <% tp.date.now("YYYY-MM-DD") %>
day: <% tp.date.now("dddd") %>
tags: [daily]
type: daily
---

# <% tp.date.now("ddd, MMMM D, YYYY") %>

## Focus
- 

## Tasks
- [ ] 

## Notes


## Log

---
**Yesterday:** [[<% tp.date.yesterday("YYYY-MM-DD") %>]]  |  **Tomorrow:** [[<% tp.date.tomorrow("YYYY-MM-DD") %>]]
```

### Project Note Template

```markdown
---
title: <% await tp.system.prompt("Project name?") %>
date: <% tp.date.now("YYYY-MM-DD") %>
status: active
type: project
tags: [project]
---

# <% tp.file.title %>

## Goal


## Context


## Tasks
- [ ] 

## Log

| Date | Update |
|------|--------|
| <% tp.date.now("YYYY-MM-DD") %> | Created |
```

### Templater Script Block

```javascript
<%*
// Run arbitrary JS during template insertion
const title = await tp.system.prompt("Title?");
const slug = title.toLowerCase().replace(/\s+/g, "-");
await tp.file.rename(slug);
tR += `# ${title}`;
%>
```

---

## Dataview Queries

### TABLE — Structured list

```dataview
TABLE date, status, tags
FROM #project
WHERE status = "active"
SORT date DESC
```

### LIST — Simple list

```dataview
LIST
FROM "Projects"
WHERE file.mtime >= date(today) - dur(7 days)
```

### TASK — All tasks

```dataview
TASK
FROM #daily
WHERE !completed
GROUP BY file.link
```

### Inline DQL

```markdown
Today is `= date(today)`.
This note was modified `= this.file.mtime`.
Project count: `= length(filter(dv.pages("#project"), (p) => p.status = "active"))`.
```

### Calendar Query (requires Calendar plugin)

```dataview
TABLE WITHOUT ID file.link AS "Note", date
FROM #daily
WHERE date >= date(today) - dur(30 days)
SORT date DESC
```

### Dataview JS (dvjs)

````javascript
```dataviewjs
const pages = dv.pages("#project").where(p => p.status === "active");
dv.table(["Project", "Status", "Date"], 
  pages.map(p => [p.file.link, p.status, p.date])
);
```
````

---

## QuickAdd Macros

QuickAdd macros are configured in `.obsidian/plugins/quickadd/data.json`. Common patterns:

### Capture to Daily Note

```json
{
  "name": "Quick Capture",
  "type": "Capture",
  "format": "- {{VALUE}} ^{{DATE:YYYYMMDDHHmmss}}",
  "appendToBottom": true,
  "insertAfter": "## Notes",
  "openFile": false
}
```

### Create from Template

```json
{
  "name": "New Project Note",
  "type": "Template",
  "templatePath": "Templates/Project.md",
  "folder": "Projects",
  "fileNameFormat": "{{VALUE}}"
}
```

### QuickAdd via URI (trigger from CLI/Alfred/Raycast)

```bash
open "obsidian://quickadd?name=Quick%20Capture&value=My%20quick%20note"
```

---

## Vault File Management via Shell

```bash
# Find all notes tagged #project
grep -rl "tags:.*project" ~/obsidian-vault/ --include="*.md"

# Find notes modified in last 7 days
fd --changed-within 7d . ~/obsidian-vault/ --extension md

# Bulk update frontmatter status field
fd . ~/obsidian-vault/Projects/ --extension md -x sed -i '' 's/status: paused/status: archived/' {}

# Count notes by tag
grep -rh "^tags:" ~/obsidian-vault/ | sort | uniq -c | sort -rn

# Extract all unique tags
grep -roh '#[a-zA-Z0-9/_-]*' ~/obsidian-vault/ | sort | uniq

# Find broken wikilinks (links to non-existent files)
grep -roh '\[\[.*\]\]' ~/obsidian-vault/ | sed 's/\[\[//;s/\]\]//' | while read link; do
  [ ! -f ~/obsidian-vault/${link}.md ] && echo "BROKEN: $link"
done

# Rename a file and update all references
OLD="Old Note Name"; NEW="New Note Name"
mv ~/obsidian-vault/"${OLD}.md" ~/obsidian-vault/"${NEW}.md"
grep -rl "\[\[${OLD}\]\]" ~/obsidian-vault/ | xargs sed -i '' "s/\[\[${OLD}\]\]/\[\[${NEW}\]\]/g"
```

---

## Obsidian URI Scheme

```bash
# Open a specific note
open "obsidian://open?vault=obsidian-vault&file=Projects/My%20Project"

# Create a new note
open "obsidian://new?vault=obsidian-vault&name=Quick%20Note&content=Hello"

# Search vault
open "obsidian://search?vault=obsidian-vault&query=tag%3Aproject"

# Open daily note
open "obsidian://daily?vault=obsidian-vault"
```

---

## Obsidian MCP Integration (port 27123)

the user's vault has the Obsidian MCP running. Use REST API calls:

```bash
# List files in vault
curl -s http://localhost:27123/vault/ | jq '.files[]'

# Read a file
curl -s "http://localhost:27123/vault/Projects/My%20Project.md"

# Create/update a file
curl -s -X PUT "http://localhost:27123/vault/Quick%20Note.md" \
  -H "Content-Type: text/markdown" \
  --data-binary "# Quick Note\n\nContent here."

# Search vault
curl -s "http://localhost:27123/search/simple/?query=project&contextLength=100" | jq '.[]'

# Append to a file
curl -s -X POST "http://localhost:27123/vault/Daily/2026-05-10.md" \
  -H "Content-Type: text/markdown" \
  --data-binary "\n- New item appended"

# Execute command by ID
curl -s -X POST "http://localhost:27123/commands/daily-notes:goto-today"
```

---

## Daily Note Automation Script

```bash
#!/bin/zsh
# ~/bin/daily-note.sh — open or create today's daily note

DATE=$(date +%Y-%m-%d)
NOTE_PATH="$HOME/obsidian-vault/Daily/${DATE}.md"

if [ ! -f "$NOTE_PATH" ]; then
  # Create from template via MCP
  TEMPLATE=$(cat "$HOME/obsidian-vault/Templates/Daily.md")
  curl -s -X PUT "http://localhost:27123/vault/Daily/${DATE}.md" \
    -H "Content-Type: text/markdown" \
    --data-binary "$TEMPLATE"
fi

open "obsidian://open?vault=obsidian-vault&file=Daily%2F${DATE}"
```

---

## Plugin Data Access

```bash
# Read QuickAdd config
cat ~/.obsidian-vault/.obsidian/plugins/quickadd/data.json | jq '.choices[]'

# Read Templater config
cat ~/obsidian-vault/.obsidian/plugins/templater-obsidian/data.json | jq '.templates_pairs'

# Read Dataview config
cat ~/obsidian-vault/.obsidian/plugins/dataview/data.json | jq '.inlineQueryPrefix'
```

---

## Common Patterns

### MOC (Map of Content) Auto-Generator

````javascript
```dataviewjs
// Auto-list all notes in a folder
const folder = dv.current().file.folder;
const notes = dv.pages(`"${folder}"`).where(p => p.file.name !== dv.current().file.name);
dv.list(notes.map(n => n.file.link));
```
````

### Weekly Review Template

```markdown
---
date: <% tp.date.now("YYYY-MM-DD") %>
week: <% tp.date.now("WW") %>
type: weekly
tags: [weekly]
---

# Week <% tp.date.now("WW") %> Review

## Completed This Week
```dataview
TASK FROM #daily
WHERE completed AND file.mtime >= date(today) - dur(7 days)
```

## Projects Status
```dataview
TABLE status, date FROM #project WHERE status = "active" SORT date ASC
```
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/app-usage/obsidian-automation/.gitnexus
Last indexed: 2026-05-23
