---
name: realtime-collaboration
description: Build real-time collaborative editing features using CRDTs (Yjs, Automerge), WebSocket broadcasting, and conflict-free merging. Covers document co-editing, cursor presence, offline sync, and integrations with Tiptap and the Hocuspocus server.
version: 1.0.0
tags: [realtime, collaboration, crdt, yjs, automerge, websocket, tiptap, presence, offline-sync]
---

# Real-Time Collaboration

## Overview

Real-time collaboration requires solving the distributed concurrency problem: when two users edit simultaneously, their changes must merge without data loss. CRDTs (Conflict-free Replicated Data Types) solve this mathematically — Yjs and Automerge implement CRDTs that always converge regardless of operation order or network delays. Yjs has official bindings for major rich-text editors (Tiptap, ProseMirror, CodeMirror, Quill) and the Hocuspocus server handles the WebSocket layer with authentication and database persistence built in.

## When to Use

- Building document editors with simultaneous multi-user editing (Google Docs style)
- Code editors needing real-time collaboration (pair programming, code review)
- Collaborative whiteboards, design tools, or spreadsheets
- Applications requiring offline editing that syncs when reconnected
- Any feature showing live cursors, presence indicators, or who-is-editing awareness
- Multi-user forms where multiple fields can be edited concurrently

## Step-by-Step Workflow

### 1. Yjs + Tiptap Rich Text Editor

```bash
npm install yjs @hocuspocus/provider @tiptap/react @tiptap/extension-collaboration \
    @tiptap/extension-collaboration-cursor @tiptap/starter-kit
```

```typescript
// src/editor/CollaborativeEditor.tsx
import { useEffect, useState } from "react";
import { useEditor, EditorContent } from "@tiptap/react";
import StarterKit from "@tiptap/starter-kit";
import Collaboration from "@tiptap/extension-collaboration";
import CollaborationCursor from "@tiptap/extension-collaboration-cursor";
import * as Y from "yjs";
import { HocuspocusProvider } from "@hocuspocus/provider";

export function CollaborativeEditor({ documentId, currentUser }: {
  documentId: string;
  currentUser: { name: string; color: string };
}) {
  const [ydoc] = useState(() => new Y.Doc());
  const [provider, setProvider] = useState<HocuspocusProvider | null>(null);

  useEffect(() => {
    const p = new HocuspocusProvider({
      url: "wss://collaboration.yourapp.com",
      name: documentId,
      document: ydoc,
      token: getAuthToken(),
      onSynced: () => console.log("Synced with server"),
      onDisconnect: () => console.log("Offline — editing locally"),
    });
    setProvider(p);
    return () => p.destroy();
  }, [documentId, ydoc]);

  const editor = useEditor({
    extensions: [
      StarterKit.configure({ history: false }),  // Yjs handles undo/redo
      Collaboration.configure({ document: ydoc }),
      CollaborationCursor.configure({
        provider,
        user: currentUser,
      }),
    ],
  });

  const onlineUsers = editor?.storage.collaborationCursor?.users ?? [];

  return (
    <div>
      <div className="presence-bar">
        {onlineUsers.map((u: any) => (
          <span key={u.name} style={{ color: u.color }}>{u.name}</span>
        ))}
      </div>
      <EditorContent editor={editor} />
    </div>
  );
}
```

### 2. Hocuspocus Server

```typescript
// server/collab.ts
import { Server } from "@hocuspocus/server";
import { Database } from "@hocuspocus/extension-database";
import { Logger } from "@hocuspocus/extension-logger";
import { TiptapTransformer } from "@hocuspocus/transformer";
import db from "./db";

const server = Server.configure({
  port: 1234,
  extensions: [
    new Logger(),
    new Database({
      // Load document from DB when first client connects
      fetch: async ({ documentName }) => {
        const row = await db.documents.findByName(documentName);
        return row?.yjsState ?? null;  // Binary Uint8Array
      },
      // Save after changes settle (debounced by Hocuspocus)
      store: async ({ documentName, state }) => {
        await db.documents.upsert({
          name: documentName,
          yjsState: state,            // Always store binary state
          htmlSnapshot: TiptapTransformer.fromYdoc(state, "default"),
          updatedAt: new Date(),
        });
      },
    }),
  ],

  async onAuthenticate({ token }) {
    const user = await verifyJWT(token);
    if (!user) throw new Error("Unauthorized");
    return { user };
  },
});

server.listen();
```

### 3. Shared CRDT Types for Structured Data

```typescript
// Collaborative kanban board using Y.Map (CRDT)
import * as Y from "yjs";
import { WebsocketProvider } from "y-websocket";

function createCollaborativeBoard(boardId: string) {
  const ydoc = new Y.Doc();
  const provider = new WebsocketProvider(
    "wss://collab.yourapp.com", boardId, ydoc
  );

  const cards = ydoc.getMap<{
    title: string; columnId: string; order: number;
  }>("cards");

  // All changes (local or remote) trigger this callback
  cards.observe((event) => {
    event.changes.keys.forEach((change, key) => {
      if (change.action === "add") renderCard(key, cards.get(key)!);
      else if (change.action === "update") updateCard(key, cards.get(key)!);
      else if (change.action === "delete") removeCard(key);
    });
  });

  return {
    addCard: (id: string, title: string, columnId: string) => {
      // transact batches operations into one atomic change
      ydoc.transact(() => {
        cards.set(id, { title, columnId, order: Date.now() });
      });
    },
    moveCard: (id: string, newColumn: string) => {
      const card = cards.get(id);
      if (card) cards.set(id, { ...card, columnId: newColumn });
    },
    undo: () => {
      const undoManager = new Y.UndoManager(cards);
      undoManager.undo();
    },
  };
}
```

### 4. Presence and Live Cursors

```typescript
// src/hooks/usePresence.ts — show who else is on this page
import { useEffect, useState } from "react";
import * as Y from "yjs";
import { WebsocketProvider } from "y-websocket";

export function usePresence(roomId: string, currentUser: {
  userId: string; name: string; color: string;
}) {
  const [onlineUsers, setOnlineUsers] = useState<any[]>([]);

  useEffect(() => {
    const ydoc = new Y.Doc();
    const provider = new WebsocketProvider(
      "wss://collab.yourapp.com", `presence:${roomId}`, ydoc
    );

    provider.awareness.setLocalStateField("user", currentUser);

    const update = () => {
      const states = Array.from(provider.awareness.getStates().entries());
      setOnlineUsers(
        states
          .filter(([id]) => id !== provider.awareness.clientID)
          .map(([, s]) => s.user)
          .filter(Boolean)
      );
    };

    provider.awareness.on("change", update);

    const onMouseMove = (e: MouseEvent) => {
      provider.awareness.setLocalStateField("user", {
        ...currentUser, cursor: { x: e.clientX, y: e.clientY },
      });
    };
    document.addEventListener("mousemove", onMouseMove);

    return () => {
      document.removeEventListener("mousemove", onMouseMove);
      provider.destroy();
      ydoc.destroy();
    };
  }, [roomId]);

  return { onlineUsers };
}
```

## Key Commands Reference

```bash
# Install Yjs + Hocuspocus ecosystem
npm install yjs y-websocket y-indexeddb @hocuspocus/server @hocuspocus/provider
npm install @tiptap/extension-collaboration @tiptap/extension-collaboration-cursor

# Dev: run a basic Yjs WebSocket server (no auth, no persistence)
npx y-websocket  # ws://localhost:1234

# Inspect binary Yjs state
node -e "
const Y = require('yjs'), fs = require('fs');
const ydoc = new Y.Doc();
Y.applyUpdate(ydoc, fs.readFileSync('doc.bin'));
console.log(ydoc.getText('content').toString());
"

# Get document as Tiptap JSON (for search indexing)
const { TiptapTransformer } = require('@hocuspocus/transformer');
const json = TiptapTransformer.fromYdoc(ydoc, 'default');

# Encode current state for storage
const state = Y.encodeStateAsUpdate(ydoc);  // Uint8Array — always store this
```

## Common Patterns

### Pattern 1: Offline-First with IndexedDB

```typescript
// Load document from local storage first (no server needed for initial render)
// Then sync with server when online — offline changes merge automatically
import { IndexeddbPersistence } from "y-indexeddb";

function createOfflineFirstDoc(docId: string) {
  const ydoc = new Y.Doc();

  const local = new IndexeddbPersistence(docId, ydoc);
  local.on("synced", () => {
    // Document loaded from IndexedDB — can render immediately without server
    initEditor(ydoc);
  });

  const remote = new WebsocketProvider("wss://collab.yourapp.com", docId, ydoc);
  remote.on("status", ({ status }: { status: string }) => {
    setOnlineStatus(status === "connected");
  });

  return { ydoc, local, remote };
}
```

### Pattern 2: Automerge for JSON Documents

```typescript
// Automerge: simpler API when data is structured JSON, not rich text
import * as Automerge from "@automerge/automerge";

interface Doc { todos: Array<{ text: string; done: boolean }> }

let docA = Automerge.init<Doc>();
docA = Automerge.change(docA, d => {
  d.todos = [{ text: "Buy milk", done: false }];
});

// Simulate concurrent edits
const docB = Automerge.change(docA, d => { d.todos[0].done = true; });
const docC = Automerge.change(docA, d => { d.todos.push({ text: "Buy eggs", done: false }); });

// Merge both — conflict-free
const merged = Automerge.merge(docB, docC);
// Result: todos[0].done=true AND todos has "Buy eggs" — both changes preserved

const binary = Automerge.save(merged);  // Uint8Array for storage
```

### Pattern 3: Redis Pub/Sub for Multi-Server Hocuspocus

```typescript
// When Hocuspocus runs on multiple servers, Redis syncs state across instances
import { Server } from "@hocuspocus/server";
import { Redis } from "@hocuspocus/extension-redis";

const server = Server.configure({
  extensions: [
    new Redis({
      host: "redis.internal",
      port: 6379,
      // All Hocuspocus instances share document updates via Redis pub/sub
      // Clients can connect to any instance and get consistent state
    }),
  ],
});
```

## Pitfalls to Avoid

1. **Storing Yjs state as JSON**: `Y.encodeStateAsUpdate(ydoc)` produces a binary Uint8Array containing CRDT metadata (vector clocks, delete sets) required for correct merging. Serializing to JSON loses this metadata — clients reconnecting after offline edits cannot merge correctly. Always persist binary state alongside a JSON snapshot for search/display.

2. **Implementing OT instead of CRDTs for new projects**: Operational Transforms require a central server to sequence all operations — complex to implement and impossible to do peer-to-peer. Yjs/Automerge CRDTs guarantee mathematical convergence without a sequencer, support peer-to-peer sync, and handle offline editing. All major collaborative editors have migrated from OT to CRDTs.

3. **Not implementing the Y.js sync protocol on custom WebSocket servers**: When a client reconnects after being offline, it must receive all missed changes — not just future ones. Hocuspocus handles this via `syncStep1`/`syncStep2`. If building a custom WebSocket server, implement the Yjs sync protocol correctly; naive broadcast servers will leave reconnected clients with stale state.

## Related Skills

- `websocket-realtime` — WebSocket infrastructure and scaling
- `event-driven-architecture` — Pub/sub for broadcasting updates
- `redis-patterns` — Redis for presence and multi-server sync
- `graphql-subscriptions` — Alternative real-time pattern

## GitNexus Index

```json
{
  "skill": "realtime-collaboration",
  "category": "frontend",
  "triggers": ["real-time collaboration", "CRDT", "Yjs", "Automerge", "collaborative editing", "Hocuspocus", "y-websocket", "operational transform", "presence cursor", "offline sync CRDT", "collaborative rich text"],
  "outputs": ["HocuspocusProvider", "CollaborativeEditor", "usePresence", "Y.Doc()", "ydoc.transact()", "IndexeddbPersistence", "awareness.setLocalStateField", "Y.UndoManager"],
  "complexity": "high",
  "tools": ["yjs", "hocuspocus", "tiptap", "y-websocket", "y-indexeddb", "automerge", "websocket", "typescript"]
}
```
