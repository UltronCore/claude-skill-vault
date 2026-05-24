---
name: zapier-make
description: >
  Zapier and Make.com workflow automation design: webhook triggers, data transformation, and integration patterns. Triggers on: Zapier, Make.com, webhook, zap, scenario, automation workflow, trigger-action.
---

# Zapier & Make.com Automation

## When to Use

Trigger when designing, debugging, or explaining automation workflows between SaaS tools. Use this skill to choose between Zapier and Make, structure webhook flows, handle data mapping, write filters, and set up common patterns like form-to-email, CMS-to-Slack, or spreadsheet-to-database.

---

## Core Rules

- Zapier = simpler, faster to set up, better for linear trigger-action chains
- Make.com = better for complex branching, loops, error handling, and lower cost at volume
- Always test with real sample data before activating a Zap/Scenario
- Webhooks are the universal glue — prefer them over polling when the source supports them
- Never store secrets in Zap/Scenario names or descriptions — use platform auth instead

---

## Zapier vs Make.com — Choosing the Right Tool

| Factor | Zapier | Make.com |
|--------|--------|----------|
| Setup speed | Fast (5 min) | Slower (15–30 min) |
| Branching logic | Limited (paths) | Full visual routing |
| Loops/iterators | Basic | Native support |
| Error handling | Simple retry | Full error routes |
| Pricing model | Per task | Per operation (cheaper at volume) |
| Data transformation | Formatter (basic) | Built-in functions (powerful) |
| Custom code | Code step (JS/Python) | HTTP + JSON (no code step on free) |
| Best for | Simple linear flows | Complex multi-path workflows |
| Debugging | Step-by-step history | Execution log with full data |

**Rule of thumb:**
- 1–3 steps, one trigger → one action → **Zapier**
- Loops, conditionals, multiple destinations, or >1000 runs/month → **Make.com**

---

## Webhook Basics

### Receiving a webhook (inbound)

**Zapier:** Add trigger "Webhooks by Zapier" → "Catch Hook" → copy URL → send test data.

**Make.com:** Add module "Webhooks" → "Custom webhook" → copy URL → click "Redetermine data structure" → send test payload.

### Sending a webhook (outbound)

**Zapier action:** "Webhooks by Zapier" → "POST"

```
URL: https://your-endpoint.com/webhook
Payload Type: json
Data:
  event: order.created
  order_id: {{order_id}}
  amount: {{amount}}
  customer_email: {{customer_email}}
```

**Make.com module:** "HTTP" → "Make a request"

```json
{
  "url": "https://your-endpoint.com/webhook",
  "method": "POST",
  "headers": [
    { "name": "Content-Type", "value": "application/json" },
    { "name": "Authorization", "value": "Bearer {{env.API_KEY}}" }
  ],
  "body": {
    "type": "raw",
    "content": "{ \"event\": \"{{event}}\", \"data\": {{toJSON(data)}} }"
  }
}
```

---

## Zapier Patterns

### Basic Zap structure

```
Trigger: [App] → [Event]
  └─ Filter (optional)
  └─ Action 1: [App] → [Action]
  └─ Action 2: [App] → [Action]
```

### Form submission → Email + Spreadsheet

```
Trigger: Typeform → New Entry
  └─ Filter: Field "interest" contains "liquor"
  └─ Action 1: Gmail → Send Email
       To: public@example.com
       Subject: New lead: {{name}}
       Body: Name: {{name}}\nEmail: {{email}}\nMessage: {{message}}
  └─ Action 2: Google Sheets → Create Row
       Spreadsheet: Leads 2026
       Sheet: Sheet1
       Row: {{name}} | {{email}} | {{message}} | {{completed_at}}
```

### Zapier Paths (branching)

```
Trigger: Stripe → Payment Succeeded
  └─ Path A: amount >= 500
       └─ Slack → Send message to #big-orders
  └─ Path B: amount < 500
       └─ Google Sheets → Log row
```

### Zapier Formatter (data transformation)

```
Action: Formatter by Zapier → Text
  Transform: Capitalize
  Input: {{customer_name}}

Action: Formatter by Zapier → Numbers
  Transform: Format Number
  Input: {{amount_cents}}
  To Format: $1,000.00  (divide by 100 first using "Spreadsheet-Style Formula")

Action: Formatter by Zapier → Date/Time
  Transform: Format Date
  Input: {{created_at}}
  To Format: MMMM D, YYYY
```

### Zapier Code Step (JavaScript)

```javascript
// Input: inputData.order (JSON string or object)
const order = JSON.parse(inputData.order || "{}");
const total = (order.items || []).reduce((sum, item) => sum + item.price * item.qty, 0);
const formattedTotal = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(total / 100);

return {
  total_cents: total,
  total_formatted: formattedTotal,
  item_count: (order.items || []).length,
};
```

---

## Make.com Patterns

### Scenario structure

```
[Trigger Module] → [Module 1] → [Module 2] → [Router] → [Branch A] → [Module A1]
                                                        └→ [Branch B] → [Module B1]
```

### Webhook → Transform → Multiple destinations

```
Webhooks (Custom) → Receive order data
  → Tools: Set variable (normalize data)
  → Router:
      Branch 1: order.total >= 500
        → Slack: Post message to #vip-orders
        → Google Sheets: Append row to VIP sheet
      Branch 2: order.total < 500
        → Google Sheets: Append row to All Orders sheet
  → Gmail: Send confirmation email
```

### Iterator + Aggregator (loop over array)

```
Webhooks → Get order (contains items array)
  → Iterator: items[] (emits one bundle per item)
    → HTTP: POST to inventory API for each item
    → Aggregator: collect results
  → Slack: Post summary of all item updates
```

### Error handling in Make

```
[Module with error] ──(error route)──> [Error Handler]
                                         → Slack: Alert team
                                         → Ignore / Resume / Break / Commit
```

Set error handling on any module: right-click → Set error handler.

### Make.com Built-in Functions

```javascript
// String functions
{{upper(customer.name)}}
{{lower(customer.email)}}
{{trim(text)}}
{{replace(text, "old", "new")}}
{{substring(text, 0, 50)}}
{{length(text)}}

// Number functions
{{round(price / 100, 2)}}
{{formatNumber(amount, 2, ".", ",")}}
{{ceil(value)}}
{{floor(value)}}

// Date functions
{{formatDate(date, "YYYY-MM-DD")}}
{{addDays(now; 7)}}
{{dateDifference(date1, date2, "days")}}
{{now}}

// Array functions
{{first(array)}}
{{last(array)}}
{{length(array)}}
{{map(array; property)}}
{{filter(array; property; value)}}

// Conditionals
{{if(condition; trueValue; falseValue)}}
{{ifempty(value; fallback)}}
```

---

## Common Integration Patterns

### Contact form → Email + CRM

```
Trigger: Website webhook (POST from Next.js API route)
  → Gmail: Send notification to owner
  → HubSpot: Create/update contact
  → Notion: Add row to Leads database
```

Next.js API route to trigger webhook:
```typescript
// app/api/contact/route.ts
export async function POST(req: Request) {
  const data = await req.json();

  // Send to Make/Zapier webhook
  await fetch(process.env.WEBHOOK_URL!, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      name: data.name,
      email: data.email,
      message: data.message,
      timestamp: new Date().toISOString(),
      source: "website-contact-form",
    }),
  });

  return Response.json({ success: true });
}
```

### E-commerce order → Multiple notifications

```
Trigger: Stripe webhook → payment_intent.succeeded
  → Parse: Extract amount, customer, metadata
  → Router:
      If amount > 500 → Slack #big-orders + owner SMS
      Always → Gmail order confirmation to customer
      Always → Google Sheets: log order
      If first order → Welcome email sequence start
```

### Spreadsheet → Database sync

```
Trigger: Google Sheets → New or Updated Row (poll every 15 min)
  → Filter: Row not already processed (check "Synced" column = empty)
  → HTTP: POST to your API endpoint
  → Google Sheets: Update "Synced" column = "yes" + timestamp
```

### Slack command → Action

```
Trigger: Slack → Slash Command (/deploy)
  → Filter: user is authorized (check against list)
  → HTTP: POST to Vercel Deploy Hook
  → Slack: Reply "Deployment triggered by {{user}}"
```

---

## Webhook Security

### Verify Zapier webhooks
Zapier doesn't sign webhooks by default. Add a secret token:

```typescript
// Verify shared secret in query param
const { searchParams } = new URL(req.url);
const token = searchParams.get("token");
if (token !== process.env.ZAPIER_SECRET) {
  return new Response("Unauthorized", { status: 401 });
}
```

### Verify Make.com webhooks
Make supports a custom header for auth:

```typescript
const sig = req.headers.get("x-make-secret");
if (sig !== process.env.MAKE_SECRET) {
  return new Response("Unauthorized", { status: 401 });
}
```

---

## Testing Workflows

### Zapier testing
1. Click "Test trigger" → load sample data
2. Click "Test action" → verify output
3. Use "Task History" to debug failed runs

### Make.com testing
1. Click "Run once" → executes with next real event
2. Use "Execution History" → click any execution to see all bundle data
3. Use "Development" mode (won't consume operations)

### Test webhook locally with ngrok

```bash
# Expose local Next.js to Make/Zapier
ngrok http 3000

# Copy the https URL, paste into Make/Zapier as webhook URL
# Trigger locally, watch Make receive the data
```

---

## Filters & Conditions

### Zapier filter syntax
- Text: "Contains", "Does not contain", "Exactly matches"
- Number: "Greater than", "Less than", "Is between"
- Boolean: "Is true", "Is false"
- Existence: "Exists", "Does not exist"

### Make.com filter syntax

```
# In filter between modules:
{{order.amount}} Greater than: 500
AND
{{order.status}} Equal to: "completed"
OR
{{order.customer.vip}} Equal to: true
```

## Related Skills
- `gmail-integration` — email automation
- `shopify-integration` — e-commerce automation
- `resend-email` — transactional email

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/zapier-make/.gitnexus
Last indexed: 2026-05-23
