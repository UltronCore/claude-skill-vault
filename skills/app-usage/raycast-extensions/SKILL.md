---
name: raycast-extensions
description: >
  Build Raycast extensions using the Raycast API: commands, list views, forms, and preferences. Triggers on: Raycast, @raycast/api, raycast extension, raycast command, showToast, List.Item, Action.
---

# Raycast Extensions

## When to Use

Trigger when building, debugging, or publishing Raycast extensions. Covers List, Form, and Detail commands; preferences; LocalStorage; navigation; clipboard; and the submission process.

---

## Core Rules

- Raycast extensions use React + TypeScript — always use functional components
- Every command exports a default React component
- API imports always come from `@raycast/api`
- Use `showToast` for feedback — never `console.log` in production paths
- Keep commands focused — one command, one job
- Extensions live in `~/.config/raycast/extensions/` (dev) or the store

---

## Extension Structure

```
my-extension/
├── package.json          # Extension manifest
├── src/
│   ├── index.tsx         # Main command
│   ├── second-command.tsx
│   └── utils.ts
├── assets/
│   └── extension-icon.png  # 512×512 PNG
└── tsconfig.json
```

### package.json manifest

```json
{
  "name": "my-extension",
  "title": "My Extension",
  "description": "What it does in one sentence",
  "icon": "extension-icon.png",
  "author": "example-author",
  "categories": ["Productivity"],
  "license": "MIT",
  "commands": [
    {
      "name": "index",
      "title": "My Command",
      "description": "Launch my command",
      "mode": "view"
    },
    {
      "name": "quick-action",
      "title": "Quick Action",
      "description": "No UI command",
      "mode": "no-view"
    }
  ],
  "dependencies": {
    "@raycast/api": "^1.70.0"
  },
  "devDependencies": {
    "@raycast/eslint-config": "^1.0.8",
    "typescript": "^5.4.0"
  },
  "scripts": {
    "build": "ray build -e dist",
    "dev": "ray develop",
    "lint": "ray lint"
  }
}
```

---

## List Command

The most common command type — searchable list of items.

```tsx
import {
  List,
  Action,
  ActionPanel,
  showToast,
  Toast,
  Icon,
} from "@raycast/api";
import { useState } from "react";

interface Item {
  id: string;
  title: string;
  subtitle?: string;
  url?: string;
}

export default function Command() {
  const [searchText, setSearchText] = useState("");
  const [items] = useState<Item[]>([
    { id: "1", title: "First Item", subtitle: "Subtitle", url: "https://example.com" },
    { id: "2", title: "Second Item" },
  ]);

  const filtered = items.filter((item) =>
    item.title.toLowerCase().includes(searchText.toLowerCase())
  );

  return (
    <List
      searchText={searchText}
      onSearchTextChange={setSearchText}
      searchBarPlaceholder="Search items..."
      isLoading={false}
    >
      {filtered.map((item) => (
        <List.Item
          key={item.id}
          title={item.title}
          subtitle={item.subtitle}
          icon={Icon.Star}
          accessories={[{ text: "tag" }]}
          actions={
            <ActionPanel>
              <Action.OpenInBrowser url={item.url ?? "https://raycast.com"} />
              <Action.CopyToClipboard
                title="Copy Title"
                content={item.title}
                shortcut={{ modifiers: ["cmd"], key: "c" }}
              />
              <Action
                title="Custom Action"
                icon={Icon.Bolt}
                onAction={async () => {
                  await showToast({
                    style: Toast.Style.Success,
                    title: "Done!",
                    message: `Acted on ${item.title}`,
                  });
                }}
              />
            </ActionPanel>
          }
        />
      ))}
    </List>
  );
}
```

### List with Sections

```tsx
<List>
  <List.Section title="Recent" subtitle="Last 7 days">
    {recentItems.map((item) => <List.Item key={item.id} title={item.title} />)}
  </List.Section>
  <List.Section title="All">
    {allItems.map((item) => <List.Item key={item.id} title={item.title} />)}
  </List.Section>
</List>
```

### List with Metadata (Detail side panel)

```tsx
<List isShowingDetail>
  <List.Item
    title="Product"
    detail={
      <List.Item.Detail
        markdown={`# Product\n\nDescription here.`}
        metadata={
          <List.Item.Detail.Metadata>
            <List.Item.Detail.Metadata.Label title="Price" text="$29.99" />
            <List.Item.Detail.Metadata.Separator />
            <List.Item.Detail.Metadata.TagList title="Tags">
              <List.Item.Detail.Metadata.TagList.Item text="new" color="#00ff00" />
            </List.Item.Detail.Metadata.TagList>
          </List.Item.Detail.Metadata>
        }
      />
    }
  />
</List>
```

---

## Form Command

```tsx
import { Form, ActionPanel, Action, showToast, Toast, popToRoot } from "@raycast/api";
import { useState } from "react";

interface FormValues {
  name: string;
  email: string;
  category: string;
  notify: boolean;
  date: Date;
}

export default function CreateForm() {
  const [nameError, setNameError] = useState<string | undefined>();

  async function handleSubmit(values: FormValues) {
    if (!values.name) {
      setNameError("Name is required");
      return;
    }

    await showToast({ style: Toast.Style.Animated, title: "Submitting..." });

    try {
      // Do work here
      await showToast({ style: Toast.Style.Success, title: "Created!", message: values.name });
      await popToRoot();
    } catch (err) {
      await showToast({ style: Toast.Style.Failure, title: "Error", message: String(err) });
    }
  }

  return (
    <Form
      actions={
        <ActionPanel>
          <Action.SubmitForm title="Create" onSubmit={handleSubmit} />
        </ActionPanel>
      }
    >
      <Form.TextField
        id="name"
        title="Name"
        placeholder="Enter name"
        error={nameError}
        onChange={() => setNameError(undefined)}
      />
      <Form.TextField id="email" title="Email" placeholder="you@example.com" />
      <Form.Dropdown id="category" title="Category" defaultValue="general">
        <Form.Dropdown.Item value="general" title="General" />
        <Form.Dropdown.Item value="urgent" title="Urgent" />
      </Form.Dropdown>
      <Form.Checkbox id="notify" label="Send notification" defaultValue={true} />
      <Form.DatePicker id="date" title="Due Date" type={Form.DatePicker.Type.Date} />
      <Form.Separator />
      <Form.TextArea id="notes" title="Notes" placeholder="Optional notes..." />
    </Form>
  );
}
```

---

## Detail Command

```tsx
import { Detail, ActionPanel, Action } from "@raycast/api";

export default function ShowDetail() {
  const markdown = `
# Report

**Generated:** ${new Date().toLocaleDateString()}

## Summary

Some content with **bold** and \`code\`.

\`\`\`json
{ "status": "ok" }
\`\`\`
  `;

  return (
    <Detail
      markdown={markdown}
      navigationTitle="Report"
      actions={
        <ActionPanel>
          <Action.CopyToClipboard content={markdown} />
          <Action.OpenInBrowser url="https://example.com" />
        </ActionPanel>
      }
    />
  );
}
```

---

## No-View Command

Quick actions with no UI — runs instantly and shows a toast.

```tsx
import { showToast, Toast, Clipboard } from "@raycast/api";

export default async function Command() {
  const text = await Clipboard.readText();
  if (!text) {
    await showToast({ style: Toast.Style.Failure, title: "Clipboard is empty" });
    return;
  }

  const transformed = text.toUpperCase();
  await Clipboard.copy(transformed);

  await showToast({
    style: Toast.Style.Success,
    title: "Transformed!",
    message: `${text.length} chars uppercased`,
  });
}
```

---

## Preferences API

Declare in package.json:

```json
"preferences": [
  {
    "name": "apiKey",
    "title": "API Key",
    "description": "Your API key",
    "type": "password",
    "required": true
  },
  {
    "name": "defaultFolder",
    "title": "Default Folder",
    "type": "directory",
    "required": false,
    "default": "~/Documents"
  },
  {
    "name": "theme",
    "title": "Theme",
    "type": "dropdown",
    "required": false,
    "default": "auto",
    "data": [
      { "title": "Auto", "value": "auto" },
      { "title": "Dark", "value": "dark" }
    ]
  }
]
```

Read in code:

```tsx
import { getPreferenceValues } from "@raycast/api";

interface Preferences {
  apiKey: string;
  defaultFolder: string;
  theme: "auto" | "dark";
}

const prefs = getPreferenceValues<Preferences>();
console.log(prefs.apiKey);
```

---

## LocalStorage (per-extension persistence)

```tsx
import { LocalStorage } from "@raycast/api";

// Write
await LocalStorage.setItem("last-query", "search text");
await LocalStorage.setItem("config", JSON.stringify({ count: 5 }));

// Read
const lastQuery = await LocalStorage.getItem<string>("last-query");
const config = JSON.parse((await LocalStorage.getItem<string>("config")) ?? "{}");

// Remove
await LocalStorage.removeItem("last-query");

// Clear all
await LocalStorage.clear();

// List all
const all = await LocalStorage.allItems();
```

---

## Navigation

```tsx
import { useNavigation, List, Detail, Action, ActionPanel } from "@raycast/api";

function DetailView({ title }: { title: string }) {
  const { pop } = useNavigation();
  return (
    <Detail
      markdown={`# ${title}`}
      actions={
        <ActionPanel>
          <Action title="Go Back" onAction={pop} />
        </ActionPanel>
      }
    />
  );
}

export default function RootCommand() {
  const { push } = useNavigation();
  return (
    <List>
      <List.Item
        title="Open Detail"
        actions={
          <ActionPanel>
            <Action title="Open" onAction={() => push(<DetailView title="Hello" />)} />
          </ActionPanel>
        }
      />
    </List>
  );
}
```

---

## Useful Actions

```tsx
// Open URL in browser
<Action.OpenInBrowser url="https://example.com" />

// Copy text
<Action.CopyToClipboard content="text to copy" />

// Paste into frontmost app
<Action.Paste content="text to paste" />

// Open file in default app
<Action.Open title="Open File" target="/path/to/file" />

// Run shell script
<Action
  title="Run Script"
  onAction={() => {
    import { exec } from "child_process";
    exec("open -a 'Obsidian'");
  }}
/>

// Open extension preferences
<Action.OpenExtensionPreferences />
```

---

## Environment Info

```tsx
import { environment } from "@raycast/api";

environment.extensionName;  // "my-extension"
environment.commandName;    // "index"
environment.raycastVersion; // "1.70.0"
environment.isDevelopment;  // true in `ray develop`
environment.assetsPath;     // Path to assets/ folder
environment.supportPath;    // Writable storage path
```

---

## Development Workflow

```bash
# Install Raycast CLI
npm install -g @raycast/api

# Create new extension
ray create my-extension

# Start dev mode (hot reload in Raycast)
cd my-extension && npm run dev

# Lint
npm run lint

# Build for submission
npm run build

# Publish to store (requires Raycast account)
ray publish
```

---

## Common Patterns

### Fetch data with loading state

```tsx
import { List, showToast, Toast } from "@raycast/api";
import { useEffect, useState } from "react";

export default function Command() {
  const [items, setItems] = useState<string[]>([]);
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    fetch("https://api.example.com/items")
      .then((r) => r.json())
      .then((data) => setItems(data))
      .catch(async (err) => {
        await showToast({ style: Toast.Style.Failure, title: "Failed", message: String(err) });
      })
      .finally(() => setIsLoading(false));
  }, []);

  return (
    <List isLoading={isLoading}>
      {items.map((item) => <List.Item key={item} title={item} />)}
    </List>
  );
}
```

### Open URL shortcut

```tsx
// In any command, open a URL in browser
import { open } from "@raycast/api";
await open("https://example.com");
```

## Related Skills
- `applescript-jxa` — Mac automation
- `keyboard-maestro` — workflow automation
- `shortcuts-skill` — Apple Shortcuts

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/raycast-extensions/.gitnexus
Last indexed: 2026-05-23
