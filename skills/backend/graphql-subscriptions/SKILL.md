---
name: graphql-subscriptions
description: Implement real-time GraphQL subscriptions using WebSockets, Server-Sent Events, and Pub/Sub backends. Covers Apollo Server, graphql-ws, Pothos schema builder, Redis Pub/Sub, and React client integration with live query invalidation patterns.
version: 1.0.0
tags: [graphql, subscriptions, websockets, real-time, apollo-server, graphql-ws, redis-pubsub, react, pothos]
---

# GraphQL Subscriptions

## Overview

GraphQL subscriptions enable servers to push real-time data to clients over persistent connections. Unlike queries and mutations (request-response), subscriptions maintain a long-lived channel — typically WebSocket — and emit new results whenever the subscribed data changes. The `graphql-ws` protocol is the modern standard, replacing the deprecated `subscriptions-transport-ws`. Paired with Redis Pub/Sub, subscriptions scale horizontally across multiple server instances.

## When to Use

- Chat applications, live feeds, and notification systems
- Dashboards where metrics or order status must update without polling
- Collaborative editing where multiple users see each other's changes
- IoT sensor data and monitoring streams
- Trading or sports platforms with real-time price/score updates
- Replacing polling-based patterns (status checks, job progress) with push

## Step-by-Step Workflow

### 1. Apollo Server with graphql-ws

```bash
npm install @apollo/server graphql graphql-ws ws @graphql-tools/schema
npm install express graphql-subscriptions
```

```typescript
// server/index.ts
import { ApolloServer } from "@apollo/server";
import { expressMiddleware } from "@apollo/server/express4";
import { ApolloServerPluginDrainHttpServer } from "@apollo/server/plugin/drainHttpServer";
import { makeExecutableSchema } from "@graphql-tools/schema";
import { WebSocketServer } from "ws";
import { useServer } from "graphql-ws/lib/use/ws";
import { PubSub } from "graphql-subscriptions";
import express from "express";
import http from "http";
import bodyParser from "body-parser";
import cors from "cors";

// Pub/Sub instance — use RedisRedisPubSub for production (horizontal scaling)
const pubSub = new PubSub();

const typeDefs = `#graphql
  type Message {
    id: ID!
    content: String!
    sender: String!
    roomId: String!
    timestamp: String!
  }

  type Query {
    messages(roomId: String!): [Message!]!
  }

  type Mutation {
    sendMessage(roomId: String!, content: String!, sender: String!): Message!
  }

  type Subscription {
    messageSent(roomId: String!): Message!
    userTyping(roomId: String!): String!
  }
`;

const EVENTS = {
  MESSAGE_SENT: "MESSAGE_SENT",
  USER_TYPING: "USER_TYPING",
};

const messages: Record<string, any[]> = {};

const resolvers = {
  Query: {
    messages: (_: any, { roomId }: { roomId: string }) => messages[roomId] ?? [],
  },

  Mutation: {
    sendMessage: (_: any, { roomId, content, sender }: any) => {
      const message = {
        id: crypto.randomUUID(),
        content,
        sender,
        roomId,
        timestamp: new Date().toISOString(),
      };
      messages[roomId] = [...(messages[roomId] ?? []), message];

      // Publish to the channel — all subscribers with matching roomId receive this
      pubSub.publish(`${EVENTS.MESSAGE_SENT}_${roomId}`, { messageSent: message });
      return message;
    },
  },

  Subscription: {
    messageSent: {
      // asyncIterator returns the event stream for this subscription
      subscribe: (_: any, { roomId }: { roomId: string }) =>
        pubSub.asyncIterator([`${EVENTS.MESSAGE_SENT}_${roomId}`]),

      // Optional: filter events before sending to client
      resolve: (payload: any) => payload.messageSent,
    },

    userTyping: {
      subscribe: (_: any, { roomId }: { roomId: string }) =>
        pubSub.asyncIterator([`${EVENTS.USER_TYPING}_${roomId}`]),
      resolve: (payload: any) => payload.userTyping,
    },
  },
};

async function main() {
  const schema = makeExecutableSchema({ typeDefs, resolvers });
  const app = express();
  const httpServer = http.createServer(app);

  // Set up WebSocket server for subscriptions
  const wsServer = new WebSocketServer({ server: httpServer, path: "/graphql" });

  const serverCleanup = useServer(
    {
      schema,
      // Optional: authenticate WebSocket connections
      onConnect: async (ctx) => {
        const token = ctx.connectionParams?.authToken as string;
        if (!token) return false; // Reject unauthenticated connections
        // Validate token...
        return true;
      },
      context: async (ctx) => {
        // Context available in subscription resolvers
        return { userId: ctx.connectionParams?.userId };
      },
    },
    wsServer
  );

  const server = new ApolloServer({
    schema,
    plugins: [
      ApolloServerPluginDrainHttpServer({ httpServer }),
      {
        async serverWillStart() {
          return {
            async drainServer() {
              await serverCleanup.dispose();
            },
          };
        },
      },
    ],
  });

  await server.start();
  app.use("/graphql", cors(), bodyParser.json(), expressMiddleware(server));

  httpServer.listen(4000, () => {
    console.log("Server ready at http://localhost:4000/graphql");
    console.log("Subscriptions ready at ws://localhost:4000/graphql");
  });
}

main();
```

### 2. Redis Pub/Sub for Horizontal Scaling

```typescript
// pub-sub/redis-pubsub.ts
// npm install graphql-redis-subscriptions ioredis
import { RedisPubSub } from "graphql-redis-subscriptions";
import { Redis } from "ioredis";

const pubSubOptions = {
  publisher: new Redis({ host: "localhost", port: 6379 }),
  subscriber: new Redis({ host: "localhost", port: 6379 }),
  // In production:
  // publisher: new Redis(process.env.REDIS_URL!),
  // subscriber: new Redis(process.env.REDIS_URL!),
};

export const pubSub = new RedisPubSub(pubSubOptions);

// Usage is identical to in-memory PubSub:
// pubSub.publish("channel", payload)
// pubSub.asyncIterator(["channel"])

// Pattern subscriptions: subscribe to all messages in any room
export const pubSubWithPattern = new RedisPubSub({
  ...pubSubOptions,
  reviver: (key: string, value: any) => {
    // Custom deserialization for Redis messages
    if (key === "timestamp") return new Date(value);
    return value;
  },
});

// Subscribe to a wildcard pattern
// const iterator = pubSubWithPattern.asyncIterableIterator("MESSAGE_*");
```

### 3. Subscription Filtering and Complex Events

```typescript
// Filtering: only emit subscription events that match the client's context
import { withFilter } from "graphql-subscriptions";

const resolvers = {
  Subscription: {
    orderStatusChanged: {
      subscribe: withFilter(
        // Base subscription — listens to all order updates
        () => pubSub.asyncIterator(["ORDER_STATUS_CHANGED"]),

        // Filter: only forward events for orders belonging to the requesting user
        (payload: any, args: any, context: any) => {
          return payload.orderStatusChanged.userId === context.userId;
        }
      ),

      resolve: (payload: any) => payload.orderStatusChanged,
    },

    // Subscription with arguments to scope the event stream
    stockPriceUpdated: {
      subscribe: withFilter(
        () => pubSub.asyncIterator(["STOCK_PRICE_UPDATED"]),
        (payload: any, args: { symbols: string[] }) => {
          return args.symbols.includes(payload.stockPriceUpdated.symbol);
        }
      ),
    },
  },
};

// Publishing from a mutation or external event source
async function handleOrderStatusChange(orderId: string, userId: string, newStatus: string) {
  const event = { orderId, userId, status: newStatus, updatedAt: new Date().toISOString() };
  await pubSub.publish("ORDER_STATUS_CHANGED", { orderStatusChanged: event });
}

// External event source: Kafka consumer or database CDC
// e.g., publish when Postgres NOTIFY fires
import pg from "pg";

const pgClient = new pg.Client({ connectionString: process.env.DATABASE_URL });
await pgClient.connect();
await pgClient.query("LISTEN order_changes");

pgClient.on("notification", (msg) => {
  const payload = JSON.parse(msg.payload ?? "{}");
  pubSub.publish("ORDER_STATUS_CHANGED", { orderStatusChanged: payload });
});
```

### 4. Pothos Schema Builder with Subscriptions

```typescript
// Modern type-safe GraphQL schema with Pothos
// npm install @pothos/core @pothos/plugin-relay @pothos/plugin-prisma
import SchemaBuilder from "@pothos/core";
import { PubSub } from "graphql-subscriptions";

const pubSub = new PubSub();

const builder = new SchemaBuilder<{
  Scalars: { Date: { Input: Date; Output: Date } };
}>({});

const MessageType = builder.objectType("Message", {
  fields: (t) => ({
    id: t.exposeID("id"),
    content: t.exposeString("content"),
    sender: t.exposeString("sender"),
    roomId: t.exposeString("roomId"),
  }),
});

builder.subscriptionType({
  fields: (t) => ({
    messageSent: t.field({
      type: MessageType,
      args: {
        roomId: t.arg.string({ required: true }),
      },
      subscribe: (_, args) =>
        pubSub.asyncIterator([`MESSAGE_SENT_${args.roomId}`]),
      resolve: (payload: any) => payload.messageSent,
    }),

    countdown: t.field({
      type: "Int",
      args: {
        from: t.arg.int({ required: true }),
      },
      // Async generator as subscription source
      subscribe: async function* (_, args) {
        for (let i = args.from; i >= 0; i--) {
          yield i;
          await new Promise((r) => setTimeout(r, 1000));
        }
      },
      resolve: (value) => value,
    }),
  }),
});
```

### 5. React Client with Apollo Client

```tsx
// npm install @apollo/client graphql
import { ApolloClient, InMemoryCache, split, HttpLink } from "@apollo/client";
import { GraphQLWsLink } from "@apollo/client/link/subscriptions";
import { getMainDefinition } from "@apollo/client/utilities";
import { createClient } from "graphql-ws";

// Split traffic: subscriptions → WebSocket, queries/mutations → HTTP
const httpLink = new HttpLink({ uri: "http://localhost:4000/graphql" });

const wsLink = new GraphQLWsLink(
  createClient({
    url: "ws://localhost:4000/graphql",
    connectionParams: {
      authToken: localStorage.getItem("token"),
    },
    // Reconnect on disconnect
    retryAttempts: 10,
    on: {
      error: (err) => console.error("WS Error:", err),
      connected: () => console.log("WS Connected"),
    },
  })
);

const splitLink = split(
  ({ query }) => {
    const def = getMainDefinition(query);
    return def.kind === "OperationDefinition" && def.operation === "subscription";
  },
  wsLink,
  httpLink
);

export const apolloClient = new ApolloClient({
  link: splitLink,
  cache: new InMemoryCache(),
});

// ChatRoom.tsx — subscribe to new messages
import { gql, useSubscription, useMutation, useQuery } from "@apollo/client";

const MESSAGES_QUERY = gql`
  query GetMessages($roomId: String!) {
    messages(roomId: $roomId) {
      id content sender timestamp
    }
  }
`;

const MESSAGE_SUBSCRIPTION = gql`
  subscription OnMessageSent($roomId: String!) {
    messageSent(roomId: $roomId) {
      id content sender timestamp
    }
  }
`;

const SEND_MESSAGE = gql`
  mutation SendMessage($roomId: String!, $content: String!, $sender: String!) {
    sendMessage(roomId: $roomId, content: $content, sender: $sender) {
      id content sender timestamp
    }
  }
`;

function ChatRoom({ roomId, userId }: { roomId: string; userId: string }) {
  const { data: initial } = useQuery(MESSAGES_QUERY, { variables: { roomId } });

  // useSubscription auto-updates when new messages arrive
  const { data: sub } = useSubscription(MESSAGE_SUBSCRIPTION, {
    variables: { roomId },
    onData: ({ client, data }) => {
      // Manually update Apollo cache with new message
      client.cache.updateQuery(
        { query: MESSAGES_QUERY, variables: { roomId } },
        (existing) => ({
          messages: [...(existing?.messages ?? []), data.data!.messageSent],
        })
      );
    },
  });

  const [sendMessage] = useMutation(SEND_MESSAGE);

  const messages = initial?.messages ?? [];

  return (
    <div>
      <ul>
        {messages.map((m: any) => (
          <li key={m.id}>{m.sender}: {m.content}</li>
        ))}
      </ul>
      <button onClick={() => sendMessage({ variables: { roomId, content: "Hello!", sender: userId } })}>
        Send
      </button>
    </div>
  );
}
```

### 6. Live Query Pattern (Polling Replacement)

```typescript
// Live queries: re-run a query whenever relevant data changes
// Simpler than subscriptions for dashboard-style use cases

// Server: publish "INVALIDATE" events instead of full payloads
const resolvers = {
  Subscription: {
    dashboardUpdated: {
      subscribe: (_: any, _args: any, ctx: any) =>
        pubSub.asyncIterator(["DASHBOARD_INVALIDATE"]),

      // Return the full fresh query result on each invalidation
      resolve: async (_payload: any, _args: any, ctx: any) => {
        return await ctx.prisma.dashboard.findUnique({ where: { id: ctx.userId } });
      },
    },
  },
};

// Publish from any mutation that affects dashboard data
async function onOrderComplete(orderId: string) {
  await updateOrderStatus(orderId, "complete");
  // Invalidate all dashboard subscribers
  await pubSub.publish("DASHBOARD_INVALIDATE", {});
}
```

## Key Commands Reference

```bash
# Install stack
npm install @apollo/server graphql graphql-ws ws @graphql-tools/schema
npm install graphql-subscriptions graphql-redis-subscriptions ioredis

# React client
npm install @apollo/client graphql graphql-ws

# Alternative: Mercurius (Fastify-native GraphQL with subscriptions)
npm install fastify mercurius mercurius-integration-test

# Test subscriptions with wscat
npm install -g wscat
wscat -c ws://localhost:4000/graphql

# Test with graphql-ws CLI
npx graphql-ws ws://localhost:4000/graphql \
  --subscribe '{"type":"subscribe","id":"1","payload":{"query":"subscription { messageSent(roomId: \"room-1\") { id content } }"}}'

# Redis for pub/sub in dev
docker run -d -p 6379:6379 redis:7-alpine

# Monitor Redis pub/sub channels
redis-cli subscribe MESSAGE_SENT_room-1
redis-cli publish MESSAGE_SENT_room-1 '{"messageSent":{"id":"1","content":"hi"}}'
```

## Common Patterns

### Pattern 1: Connection Lifecycle Hooks

```typescript
// Track connected clients, handle auth, clean up on disconnect
const serverCleanup = useServer(
  {
    schema,
    onConnect: async (ctx) => {
      const token = ctx.connectionParams?.authToken as string | undefined;
      if (!token) {
        throw new Error("Unauthorized");
      }
      const user = await verifyToken(token);
      console.log(`User ${user.id} connected`);
      return { userId: user.id }; // Stored in ctx.extra
    },
    onSubscribe: async (ctx, msg) => {
      // Called before subscribe resolver — can reject specific subscriptions
      if (!ctx.extra?.userId) throw new Error("Not authenticated");
    },
    onDisconnect: (ctx) => {
      console.log(`User ${ctx.extra?.userId} disconnected`);
    },
    context: (ctx) => ({ userId: ctx.extra?.userId }),
  },
  wsServer
);
```

### Pattern 2: Batching Subscription Events

```typescript
// Debounce high-frequency events before broadcasting
import { debounce } from "lodash";

const pendingUpdates: Map<string, any[]> = new Map();

const flushUpdates = debounce(() => {
  for (const [channel, events] of pendingUpdates.entries()) {
    // Batch publish — one message with all pending events
    pubSub.publish(channel, { batchedEvents: events });
    pendingUpdates.delete(channel);
  }
}, 50); // Collect events for 50ms before broadcasting

function publishUpdate(channel: string, event: any) {
  const pending = pendingUpdates.get(channel) ?? [];
  pending.push(event);
  pendingUpdates.set(channel, pending);
  flushUpdates();
}
```

### Pattern 3: Subscription Cleanup and Memory Safety

```typescript
// Always dispose of subscriptions in React when component unmounts
// Apollo Client handles this automatically with useSubscription

// For manual WebSocket subscriptions:
function usePriceSubscription(symbols: string[]) {
  const client = useApolloClient();
  const [prices, setPrices] = useState<Record<string, number>>({});

  useEffect(() => {
    const observable = client.subscribe({
      query: PRICE_SUBSCRIPTION,
      variables: { symbols },
    });

    const sub = observable.subscribe({
      next: ({ data }) => {
        setPrices((prev) => ({ ...prev, [data.stockPriceUpdated.symbol]: data.stockPriceUpdated.price }));
      },
    });

    // Cleanup: unsubscribes from WebSocket channel
    return () => sub.unsubscribe();
  }, [symbols.join(",")]); // Re-subscribe if symbols list changes

  return prices;
}
```

## Pitfalls to Avoid

1. **Using deprecated `subscriptions-transport-ws`**: The original Apollo WebSocket protocol is unmaintained and has known issues with connection cleanup. Always use `graphql-ws` (the `graphql-ws` npm package + `graphql-ws/lib/use/ws` adapter). Check the client library: Apollo Client 3.7+ uses `GraphQLWsLink` from `@apollo/client/link/subscriptions`.

2. **In-memory PubSub with multiple server instances**: The default `graphql-subscriptions` `PubSub` only works within a single Node.js process. In production with multiple instances behind a load balancer, every server has its own PubSub — a client on server A won't receive events published on server B. Replace with `graphql-redis-subscriptions` or `@graphql-yoga/plugin-defer-stream` backed by Redis Streams.

3. **Not cleaning up subscriptions on disconnect**: If subscription resolvers start timers, intervals, or hold references, they'll leak memory when clients disconnect. Always wrap async generators with `try/finally` to clean up, and use `onDisconnect` hooks to cancel any ongoing work tied to that connection.

## Related Skills

- `websocket-realtime` — Raw WebSocket patterns when GraphQL overhead isn't needed
- `graphql-expert` — Queries, mutations, schema design, and performance optimization
- `event-driven-architecture` — Pub/Sub event bus patterns that feed subscription systems
- `redis-patterns` — Redis Pub/Sub, Streams, and keyspace notifications as subscription backends

## GitNexus Index

```json
{
  "skill": "graphql-subscriptions",
  "category": "backend",
  "triggers": ["graphql subscriptions", "graphql-ws", "apollo subscriptions", "real-time graphql", "pubsub graphql", "websocket graphql", "graphql live query"],
  "outputs": ["subscription resolver", "PubSub", "WebSocketServer", "RedisPubSub", "useSubscription hook", "withFilter"],
  "complexity": "medium",
  "tools": ["graphql-ws", "apollo-server", "redis", "react", "pothos", "typescript", "express"]
}
```
