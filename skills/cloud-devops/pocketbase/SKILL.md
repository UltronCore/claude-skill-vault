---
name: pocketbase
description: >
  PocketBase self-hosted backend: collections, auth, realtime, file storage, and JS SDK. Triggers on: PocketBase, pocketbase, pb.collection, pb.authStore, PocketBase SDK, .getFullList(), pb.files.getUrl.
---

# PocketBase

## When to Use
Use PocketBase for side projects, MVPs, or small-team apps that need a complete backend (auth, DB, files, realtime) without infrastructure complexity. Single binary — runs anywhere.

---

## Core Rules
- PocketBase collections = tables; `id` is always a 15-character string (not UUID)
- `authStore` persists in localStorage (browser) or manually (server)
- Always filter on the server, never fetch all records and filter in JS
- Use `expand` for relations — don't make N requests for related records
- OAuth2 requires the browser flow — can't do server-side only

---

## PocketBase vs Supabase

| Feature | PocketBase | Supabase |
|---|---|---|
| Hosting | Self-hosted (single binary) | Managed or self-hosted |
| Database | SQLite (embedded) | PostgreSQL |
| Scale | Small-medium apps | Enterprise-grade |
| Auth | Built-in UI + API | GoTrue |
| Realtime | Built-in | Postgres Realtime |
| Storage | Local filesystem | S3-compatible |
| Admin UI | Built-in at /_ | Supabase Dashboard |
| Price | Free (hosting costs only) | Free tier + paid plans |
| Best for | MVPs, personal projects | Production apps |

---

## Install SDK

```bash
npm install pocketbase
```

```typescript
// lib/pocketbase.ts
import PocketBase from 'pocketbase';

// Client-side (singleton)
export const pb = new PocketBase(process.env.NEXT_PUBLIC_POCKETBASE_URL!);

// Server-side (new instance per request — don't share auth state)
export function createServerClient() {
  const pb = new PocketBase(process.env.POCKETBASE_URL!);
  pb.autoCancellation(false); // disable for server requests
  return pb;
}
```

---

## Collection CRUD

### Type Definitions (from PocketBase schema)
```typescript
// types/pocketbase.ts
export interface UserRecord {
  id: string;
  email: string;
  username: string;
  name: string;
  avatar?: string;
  created: string;
  updated: string;
}

export interface PostRecord {
  id: string;
  title: string;
  body: string;
  published: boolean;
  author: string;        // relation field — stores ID
  tags: string[];        // multi-value select
  cover?: string;        // file field — stores filename
  created: string;
  updated: string;
  // expanded relations (optional)
  expand?: {
    author?: UserRecord;
  };
}
```

### Read Records
```typescript
import { pb } from '@/lib/pocketbase';

// Get full list (auto-paginates, returns all records)
const posts = await pb.collection('posts').getFullList<PostRecord>({
  sort: '-created',      // descending by created
  filter: 'published = true',
  expand: 'author',     // expand relation
  fields: 'id,title,created,expand.author.name', // projection
});

// Get paginated list
const page = await pb.collection('posts').getList<PostRecord>(1, 20, {
  sort: '-created',
  filter: 'published = true && author = "abc123"',
});
// page.totalItems, page.totalPages, page.items

// Get single record
const post = await pb.collection('posts').getOne<PostRecord>('RECORD_ID', {
  expand: 'author',
});

// Get first matching record
const draft = await pb.collection('posts').getFirstListItem<PostRecord>(
  'author = "abc123" && published = false',
  { sort: '-created' }
);
```

### Create / Update / Delete
```typescript
// Create
const newPost = await pb.collection('posts').create<PostRecord>({
  title: 'Hello World',
  body: 'My first post.',
  published: false,
  author: pb.authStore.model?.id,
});

// Create with file
const formData = new FormData();
formData.append('title', 'Post with Image');
formData.append('cover', imageFile); // File object
const post = await pb.collection('posts').create<PostRecord>(formData);

// Update (partial — only sends changed fields)
const updated = await pb.collection('posts').update<PostRecord>('RECORD_ID', {
  published: true,
  updated: new Date().toISOString(),
});

// Delete
await pb.collection('posts').delete('RECORD_ID');
```

---

## Filtering & Sorting

```typescript
// Filter syntax (PocketBase filter expression)
// Comparison: =, !=, >, >=, <, <=
// Logical: &&, ||, !
// String: ~, !~ (LIKE), ?=, ?~
// Dates: '2024-01-01 00:00:00'

const examples = [
  'published = true',
  'author = "' + userId + '"',
  'created >= "2024-01-01 00:00:00"',
  'tags ?= "typescript"',         // array contains
  'title ~ "hello"',              // LIKE %hello%
  'status = "active" && role != "admin"',
  '(role = "admin" || role = "editor") && active = true',
];

// Sort: prefix with - for DESC
sort: '-created'          // newest first
sort: 'name,-created'    // name ASC, created DESC
```

---

## Authentication

### Email / Password
```typescript
// Register
const user = await pb.collection('users').create({
  email: 'user@example.com',
  password: 'secure-password',
  passwordConfirm: 'secure-password',
  name: 'Example User',
});

// Login
const authData = await pb.collection('users').authWithPassword(
  'user@example.com',
  'secure-password'
);
// pb.authStore.isValid → true
// pb.authStore.token → JWT token
// pb.authStore.model → user record

// Logout
pb.authStore.clear();

// Refresh auth (extend session)
await pb.collection('users').authRefresh();
```

### OAuth2
```typescript
// Get providers list
const methods = await pb.collection('users').listAuthMethods();
// methods.oauth2.providers: [{ name: 'google', ... }]

// Redirect to provider (browser only)
const authData = await pb.collection('users').authWithOAuth2({
  provider: 'google',
  // PocketBase opens popup or redirects automatically
});
```

### Auth in Next.js
```typescript
// Store token in cookie (SSR-compatible)
import { serialize } from 'cookie';

// After login
const authData = await pb.collection('users').authWithPassword(email, password);

const cookie = serialize('pb_auth', JSON.stringify({
  token: authData.token,
  model: authData.record,
}), {
  httpOnly: true,
  sameSite: 'strict',
  secure: process.env.NODE_ENV === 'production',
  path: '/',
  maxAge: 60 * 60 * 24 * 7, // 7 days
});

// Server-side: restore auth from cookie
const pbServer = createServerClient();
const cookieData = JSON.parse(req.cookies['pb_auth'] ?? '{}');
pbServer.authStore.save(cookieData.token, cookieData.model);

if (pbServer.authStore.isValid) {
  await pbServer.collection('users').authRefresh(); // refresh token
}
```

---

## Relations (expand)

```typescript
// Schema: posts.author → users (single relation)
//         posts.tags → tags (multi-relation)

// Expand single relation
const post = await pb.collection('posts').getOne<PostRecord & {
  expand: { author: UserRecord }
}>('POST_ID', {
  expand: 'author',
});

const authorName = post.expand?.author?.name;

// Expand nested relation
const post = await pb.collection('posts').getOne('POST_ID', {
  expand: 'author,author.profile', // nested
});

// Expand back-relation (from parent to children)
const user = await pb.collection('users').getOne('USER_ID', {
  expand: 'posts_via_author', // back-relation: collectionName_via_fieldName
});
```

---

## File Storage

```typescript
// Get file URL
const imageUrl = pb.files.getUrl(record, record.cover, {
  thumb: '100x100', // auto-generate thumbnail
});
// Supported: 100x100 (crop), 100x0 (scale width), 0x100 (scale height), 100x100f (fit)

// Upload file in form
const formData = new FormData();
formData.append('cover', file);
formData.append('title', 'Post Title');
await pb.collection('posts').create(formData);

// Delete file (set field to empty string or null)
await pb.collection('posts').update('RECORD_ID', { cover: null });

// Download private file (requires auth token)
const url = pb.files.getUrl(record, record.file);
const response = await fetch(url, {
  headers: { Authorization: pb.authStore.token },
});
```

---

## Realtime Subscriptions

```typescript
// Subscribe to a collection (all events)
const unsubscribe = await pb.collection('posts').subscribe('*', (e) => {
  // e.action: 'create' | 'update' | 'delete'
  // e.record: PostRecord
  console.log(e.action, e.record);

  if (e.action === 'create') {
    setPosts((prev) => [e.record, ...prev]);
  }
  if (e.action === 'update') {
    setPosts((prev) => prev.map((p) => p.id === e.record.id ? e.record : p));
  }
  if (e.action === 'delete') {
    setPosts((prev) => prev.filter((p) => p.id !== e.record.id));
  }
});

// Subscribe to a specific record
await pb.collection('posts').subscribe('RECORD_ID', (e) => {
  setPost(e.record);
});

// Cleanup
unsubscribe(); // call the returned function

// In React
useEffect(() => {
  let unsub: (() => void) | null = null;
  pb.collection('posts').subscribe('*', handler).then((fn) => { unsub = fn; });
  return () => { unsub?.(); };
}, []);
```

---

## Deploying on Fly.io

```dockerfile
# Dockerfile
FROM alpine:latest

WORKDIR /pb

# Download PocketBase binary
ARG PB_VERSION=0.22.0
RUN wget -q https://github.com/pocketbase/pocketbase/releases/download/v${PB_VERSION}/pocketbase_${PB_VERSION}_linux_amd64.zip \
  && unzip pocketbase_${PB_VERSION}_linux_amd64.zip \
  && rm pocketbase_${PB_VERSION}_linux_amd64.zip

EXPOSE 8090

CMD ["./pocketbase", "serve", "--http=0.0.0.0:8090"]
```

```toml
# fly.toml
app = "my-pocketbase"
primary_region = "ord"

[build]

[http_service]
  internal_port = 8090
  force_https = true

[[vm]]
  memory = "256mb"
  cpu_kind = "shared"
  cpus = 1

# Persistent volume for SQLite + files
[mounts]
  source = "pb_data"
  destination = "/pb/pb_data"
```

```bash
fly launch
fly volumes create pb_data --size 1  # 1 GB
fly deploy
fly secrets set PB_ADMIN_EMAIL=admin@example.com PB_ADMIN_PASSWORD=secret
```

---

## Quick Reference

| Task | API |
|---|---|
| Get all records | `pb.collection('x').getFullList()` |
| Get page | `pb.collection('x').getList(page, perPage)` |
| Get one | `pb.collection('x').getOne(id)` |
| Create | `pb.collection('x').create(data)` |
| Update | `pb.collection('x').update(id, data)` |
| Delete | `pb.collection('x').delete(id)` |
| Login | `pb.collection('users').authWithPassword(email, pw)` |
| Logout | `pb.authStore.clear()` |
| Current user | `pb.authStore.model` |
| File URL | `pb.files.getUrl(record, record.field)` |
| Subscribe | `pb.collection('x').subscribe('*', handler)` |
| Expand relation | `{ expand: 'fieldName' }` option |
