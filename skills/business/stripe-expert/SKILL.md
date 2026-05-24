---
name: stripe-expert
description: >
  Stripe payment integration: checkout sessions, payment intents, subscriptions, webhooks, and Connect. Triggers on: Stripe, stripe.checkout, PaymentIntent, Subscription, stripe.webhooks, Stripe Connect, payment_method.
---

# Stripe Expert

## When to Use

Trigger when integrating Stripe for any payment flow: hosted Checkout, custom Payment Intent UI, subscriptions, webhook handling, refunds, or Connect. Covers Next.js API route patterns and the Stripe CLI for local testing.

---

## Core Rules

- **Never** put `STRIPE_SECRET_KEY` in client-side code — server/API routes only
- Use `NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY` for client-side Stripe.js
- Always verify webhook signatures — never trust payload alone
- Use idempotency keys for all create operations to prevent duplicate charges
- Store `customerId`, `subscriptionId`, and `paymentIntentId` in your DB — never reconstruct from Stripe
- Test mode keys start with `sk_test_` and `pk_test_`; live start with `sk_live_` and `pk_live_`

---

## Setup

```bash
npm install stripe @stripe/stripe-js @stripe/react-stripe-js
npm install -D stripe-cli  # or brew install stripe/stripe-cli/stripe
```

```bash
# .env.local
STRIPE_SECRET_KEY=sk_test_...
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...   # from CLI or dashboard
```

### Server-side Stripe client

```typescript
// lib/stripe.ts
import Stripe from "stripe";

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: "2024-04-10",
  typescript: true,
});
```

### Client-side Stripe.js

```typescript
// lib/stripe-client.ts
import { loadStripe } from "@stripe/stripe-js";

export const stripePromise = loadStripe(
  process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!
);
```

---

## Option 1: Checkout Session (Hosted — Recommended)

Redirect to Stripe's hosted checkout page. Simplest, most secure, PCI compliant.

### Create Checkout Session (API Route)

```typescript
// app/api/checkout/route.ts
import { stripe } from "@/lib/stripe";
import { auth } from "@/lib/auth";

export async function POST(req: Request) {
  const session = await auth();
  const { priceId, quantity = 1 } = await req.json();

  const baseUrl = process.env.NEXT_PUBLIC_BASE_URL!;

  const checkoutSession = await stripe.checkout.sessions.create({
    mode: "payment",          // "payment" | "subscription" | "setup"
    line_items: [
      { price: priceId, quantity },
    ],
    customer_email: session?.user?.email ?? undefined,
    success_url: `${baseUrl}/order/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${baseUrl}/cart`,
    metadata: {
      userId: session?.user?.id ?? "",
      source: "checkout-page",
    },
    // Shipping address collection
    shipping_address_collection: {
      allowed_countries: ["US"],
    },
    // Billing address
    billing_address_collection: "required",
    // Tax
    automatic_tax: { enabled: true },
    // Discount codes
    allow_promotion_codes: true,
  }, {
    idempotencyKey: `checkout-${session?.user?.id}-${Date.now()}`,
  });

  return Response.json({ url: checkoutSession.url });
}
```

### Trigger from client

```tsx
// components/CheckoutButton.tsx
"use client";

export function CheckoutButton({ priceId }: { priceId: string }) {
  const handleCheckout = async () => {
    const res = await fetch("/api/checkout", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ priceId }),
    });
    const { url } = await res.json();
    window.location.href = url;
  };

  return <button onClick={handleCheckout}>Checkout</button>;
}
```

### Retrieve session on success page

```typescript
// app/order/success/page.tsx
import { stripe } from "@/lib/stripe";

export default async function SuccessPage({
  searchParams,
}: {
  searchParams: { session_id?: string };
}) {
  if (!searchParams.session_id) return <div>Invalid session</div>;

  const session = await stripe.checkout.sessions.retrieve(
    searchParams.session_id,
    { expand: ["payment_intent", "line_items"] }
  );

  return (
    <div>
      <h1>Order Confirmed!</h1>
      <p>Total: {(session.amount_total! / 100).toFixed(2)}</p>
      <p>Email: {session.customer_details?.email}</p>
    </div>
  );
}
```

---

## Option 2: Payment Intent (Custom UI)

Full control over the payment form using Stripe Elements.

### Create PaymentIntent (API Route)

```typescript
// app/api/payment-intent/route.ts
import { stripe } from "@/lib/stripe";

export async function POST(req: Request) {
  const { amount, currency = "usd", metadata } = await req.json();

  const paymentIntent = await stripe.paymentIntents.create({
    amount,          // in cents
    currency,
    automatic_payment_methods: { enabled: true },
    metadata,
  }, {
    idempotencyKey: `pi-${metadata.orderId}`,
  });

  return Response.json({ clientSecret: paymentIntent.client_secret });
}
```

### Stripe Elements (React)

```tsx
// app/checkout/PaymentForm.tsx
"use client";
import { Elements, PaymentElement, useStripe, useElements } from "@stripe/react-stripe-js";
import { stripePromise } from "@/lib/stripe-client";
import { useState, useEffect } from "react";

function CheckoutForm({ onSuccess }: { onSuccess: () => void }) {
  const stripe = useStripe();
  const elements = useElements();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!stripe || !elements) return;

    setLoading(true);
    setError(null);

    const { error: submitError } = await stripe.confirmPayment({
      elements,
      confirmParams: {
        return_url: `${window.location.origin}/order/success`,
      },
    });

    if (submitError) {
      setError(submitError.message ?? "Payment failed");
      setLoading(false);
    }
    // On success, Stripe redirects to return_url
  };

  return (
    <form onSubmit={handleSubmit}>
      <PaymentElement />
      {error && <p className="text-red-500 mt-2">{error}</p>}
      <button
        type="submit"
        disabled={!stripe || loading}
        className="btn-primary mt-4 w-full"
      >
        {loading ? "Processing..." : "Pay Now"}
      </button>
    </form>
  );
}

export function PaymentWrapper({ amount }: { amount: number }) {
  const [clientSecret, setClientSecret] = useState<string | null>(null);

  useEffect(() => {
    fetch("/api/payment-intent", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ amount }),
    })
      .then((r) => r.json())
      .then(({ clientSecret }) => setClientSecret(clientSecret));
  }, [amount]);

  if (!clientSecret) return <div>Loading...</div>;

  return (
    <Elements
      stripe={stripePromise}
      options={{
        clientSecret,
        appearance: { theme: "stripe" },
      }}
    >
      <CheckoutForm onSuccess={() => console.log("done")} />
    </Elements>
  );
}
```

---

## Subscriptions

### Create subscription (API Route)

```typescript
// app/api/subscribe/route.ts
import { stripe } from "@/lib/stripe";

export async function POST(req: Request) {
  const { priceId, customerId } = await req.json();

  // If no customer yet, create one
  let stripeCustomerId = customerId;
  if (!stripeCustomerId) {
    const customer = await stripe.customers.create({
      email: "user@example.com",
      metadata: { userId: "internal-user-id" },
    });
    stripeCustomerId = customer.id;
    // Save to DB: user.stripeCustomerId = stripeCustomerId
  }

  const subscription = await stripe.subscriptions.create({
    customer: stripeCustomerId,
    items: [{ price: priceId }],
    payment_behavior: "default_incomplete",
    payment_settings: { save_default_payment_method: "on_subscription" },
    expand: ["latest_invoice.payment_intent"],
  });

  const invoice = subscription.latest_invoice as Stripe.Invoice;
  const paymentIntent = invoice.payment_intent as Stripe.PaymentIntent;

  return Response.json({
    subscriptionId: subscription.id,
    clientSecret: paymentIntent.client_secret,
  });
}
```

### Subscription lifecycle events (via webhook)

```
customer.subscription.created      → provision access
customer.subscription.updated      → update plan
customer.subscription.deleted      → revoke access
invoice.paid                       → renew access
invoice.payment_failed             → send dunning email, set status = "past_due"
customer.subscription.trial_will_end → reminder email
```

---

## Webhook Handler

```typescript
// app/api/webhooks/stripe/route.ts
import { stripe } from "@/lib/stripe";
import Stripe from "stripe";
import { headers } from "next/headers";

export async function POST(req: Request) {
  const body = await req.text();
  const sig = headers().get("stripe-signature")!;

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(
      body,
      sig,
      process.env.STRIPE_WEBHOOK_SECRET!
    );
  } catch (err) {
    console.error("Webhook signature verification failed:", err);
    return new Response(`Webhook Error: ${String(err)}`, { status: 400 });
  }

  // Handle events
  switch (event.type) {
    case "checkout.session.completed": {
      const session = event.data.object as Stripe.Checkout.Session;
      await handleCheckoutComplete(session);
      break;
    }
    case "payment_intent.succeeded": {
      const pi = event.data.object as Stripe.PaymentIntent;
      await handlePaymentSuccess(pi);
      break;
    }
    case "customer.subscription.created":
    case "customer.subscription.updated": {
      const sub = event.data.object as Stripe.Subscription;
      await upsertSubscription(sub);
      break;
    }
    case "customer.subscription.deleted": {
      const sub = event.data.object as Stripe.Subscription;
      await cancelSubscription(sub.id);
      break;
    }
    case "invoice.paid": {
      const invoice = event.data.object as Stripe.Invoice;
      await handleInvoicePaid(invoice);
      break;
    }
    case "invoice.payment_failed": {
      const invoice = event.data.object as Stripe.Invoice;
      await handlePaymentFailed(invoice);
      break;
    }
    default:
      console.log(`Unhandled event type: ${event.type}`);
  }

  return new Response("OK", { status: 200 });
}
```

---

## Idempotency Keys

```typescript
// Prevent duplicate charges on retry
const paymentIntent = await stripe.paymentIntents.create(
  { amount: 2999, currency: "usd" },
  { idempotencyKey: `order-${orderId}-${userId}` }
);

// For subscriptions
const subscription = await stripe.subscriptions.create(
  { customer: customerId, items: [{ price: priceId }] },
  { idempotencyKey: `sub-${userId}-${priceId}` }
);
```

---

## Refunds

```typescript
// Full refund
const refund = await stripe.refunds.create({
  payment_intent: "pi_xxxxx",
  reason: "requested_by_customer",
});

// Partial refund
const refund = await stripe.refunds.create({
  payment_intent: "pi_xxxxx",
  amount: 1500,  // $15.00 partial refund
});

// Refund via charge ID
const refund = await stripe.refunds.create({
  charge: "ch_xxxxx",
});
```

---

## Stripe CLI — Local Webhook Testing

```bash
# Install
brew install stripe/stripe-cli/stripe

# Login
stripe login

# Forward webhooks to local dev server
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# Trigger test events
stripe trigger checkout.session.completed
stripe trigger payment_intent.succeeded
stripe trigger customer.subscription.created
stripe trigger invoice.payment_failed

# Watch events in real-time
stripe listen

# Get webhook secret for local dev
stripe listen --print-secret
# Copy output as STRIPE_WEBHOOK_SECRET in .env.local
```

---

## Test Card Numbers

| Card | Number | Use Case |
|------|--------|----------|
| Visa (success) | 4242 4242 4242 4242 | Basic payment |
| Visa (3D Secure) | 4000 0025 0000 3155 | Auth required |
| Declined | 4000 0000 0000 0002 | Card declined |
| Insufficient funds | 4000 0000 0000 9995 | Funds error |
| Expired | 4000 0000 0000 0069 | Expired card |
| CVC fail | 4000 0000 0000 0101 | CVC mismatch |

Use any future expiry date (e.g., 12/34) and any 3-digit CVC.

---

## Stripe Connect (Multi-vendor / Split Payments)

```typescript
// Create connected account
const account = await stripe.accounts.create({
  type: "express",
  country: "US",
  email: "vendor@example.com",
  capabilities: {
    card_payments: { requested: true },
    transfers: { requested: true },
  },
});

// Generate onboarding link
const link = await stripe.accountLinks.create({
  account: account.id,
  refresh_url: `${baseUrl}/connect/refresh`,
  return_url: `${baseUrl}/connect/success`,
  type: "account_onboarding",
});
redirect(link.url);

// Create payment with platform fee
const paymentIntent = await stripe.paymentIntents.create({
  amount: 10000,       // $100
  currency: "usd",
  application_fee_amount: 1000,  // $10 platform fee
  transfer_data: { destination: "acct_connected_account_id" },
});
```

---

## Common Next.js API Route Patterns

```typescript
// Generic payment handler with error wrapping
export async function POST(req: Request) {
  try {
    const body = await req.json();
    // ... stripe operations
    return Response.json({ success: true, data });
  } catch (err) {
    if (err instanceof Stripe.errors.StripeError) {
      return Response.json(
        { error: err.message, code: err.code },
        { status: err.statusCode ?? 500 }
      );
    }
    return Response.json({ error: "Internal server error" }, { status: 500 });
  }
}
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/business/stripe-expert/.gitnexus
Last indexed: 2026-05-23
