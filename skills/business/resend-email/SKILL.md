---
name: resend-email
description: >
  Transactional email with Resend: React email templates, sending from Next.js, and email automation. Triggers on: Resend, resend.emails.send, react-email, EmailTemplate, transactional email, SMTP, email template.
---

# Resend Email

## When to Use

Trigger when setting up transactional email: order confirmations, welcome emails, password resets, or batch notifications. Covers Resend SDK setup, React Email components, Next.js Route Handler integration, domain verification, and delivery webhooks.

---

## Core Rules

- Resend API key goes in `RESEND_API_KEY` env var — server-side only
- `from` address must use a verified domain (or `onboarding@resend.dev` for testing)
- React Email components render to HTML and plain text automatically
- Prefer `<Html>`, `<Head>`, `<Body>` structure for maximum client compatibility
- Use `react-email` components (`<Text>`, `<Button>`, `<Link>`, `<Img>`, `<Hr>`) — not raw HTML
- Batch limit: 100 emails per `emails.batch()` call

---

## Setup

```bash
npm install resend react-email @react-email/components
```

```bash
# .env.local
RESEND_API_KEY=re_...
EMAIL_FROM=orders@yourdomain.com
EMAIL_FROM_NAME=Your Store Name
```

### Resend client singleton

```typescript
// lib/resend.ts
import { Resend } from "resend";

export const resend = new Resend(process.env.RESEND_API_KEY);

export const FROM_EMAIL = `${process.env.EMAIL_FROM_NAME} <${process.env.EMAIL_FROM}>`;
```

---

## React Email Templates

### Base layout

```tsx
// emails/layouts/BaseLayout.tsx
import {
  Html,
  Head,
  Preview,
  Body,
  Container,
  Section,
  Img,
  Text,
  Hr,
  Font,
} from "@react-email/components";

interface BaseLayoutProps {
  preview: string;
  children: React.ReactNode;
}

export function BaseLayout({ preview, children }: BaseLayoutProps) {
  return (
    <Html>
      <Head>
        <Font
          fontFamily="Inter"
          fallbackFontFamily="Arial"
          webFont={{
            url: "https://fonts.gstatic.com/s/inter/v13/UcCO3FwrK3iLTeHuS_fvQtMwCp50KnMw2boKoduKmMEVuLyfAZ9hiJ-Ek-_EeA.woff2",
            format: "woff2",
          }}
          fontWeight={400}
          fontStyle="normal"
        />
      </Head>
      <Preview>{preview}</Preview>
      <Body style={{ backgroundColor: "#f6f9fc", fontFamily: "Inter, Arial, sans-serif" }}>
        <Container
          style={{
            maxWidth: "600px",
            margin: "0 auto",
            backgroundColor: "#ffffff",
            borderRadius: "8px",
            overflow: "hidden",
          }}
        >
          {/* Header */}
          <Section style={{ backgroundColor: "#1a1a1a", padding: "24px" }}>
            <Img
              src="https://yourdomain.com/logo-white.png"
              alt="Your Store"
              width={120}
              height={40}
            />
          </Section>

          {/* Content */}
          <Section style={{ padding: "32px 40px" }}>
            {children}
          </Section>

          {/* Footer */}
          <Hr style={{ borderColor: "#e6ebf1" }} />
          <Section style={{ padding: "24px 40px", backgroundColor: "#f9fafb" }}>
            <Text style={{ color: "#8898aa", fontSize: "12px", lineHeight: "20px" }}>
              © {new Date().getFullYear()} Your Store. All rights reserved.
            </Text>
            <Text style={{ color: "#8898aa", fontSize: "12px" }}>
              123 Main St, St. Louis, MO 63108
            </Text>
          </Section>
        </Container>
      </Body>
    </Html>
  );
}
```

### Order Confirmation Email

```tsx
// emails/OrderConfirmation.tsx
import {
  Text,
  Button,
  Section,
  Row,
  Column,
  Img,
  Hr,
} from "@react-email/components";
import { BaseLayout } from "./layouts/BaseLayout";

interface OrderItem {
  name: string;
  quantity: number;
  price: number;  // cents
  image?: string;
}

interface OrderConfirmationProps {
  orderNumber: string;
  customerName: string;
  items: OrderItem[];
  subtotal: number;
  shipping: number;
  tax: number;
  total: number;
  shippingAddress: {
    line1: string;
    city: string;
    state: string;
    postalCode: string;
  };
  trackingUrl?: string;
}

function formatPrice(cents: number) {
  return new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" }).format(
    cents / 100
  );
}

export function OrderConfirmation({
  orderNumber,
  customerName,
  items,
  subtotal,
  shipping,
  tax,
  total,
  shippingAddress,
  trackingUrl,
}: OrderConfirmationProps) {
  return (
    <BaseLayout preview={`Order ${orderNumber} confirmed — thank you!`}>
      <Text style={{ fontSize: "24px", fontWeight: "bold", color: "#1a1a1a" }}>
        Order Confirmed!
      </Text>
      <Text style={{ color: "#525f7f", lineHeight: "26px" }}>
        Hi {customerName}, your order <strong>#{orderNumber}</strong> has been placed.
        We'll send you another email when it ships.
      </Text>

      <Hr style={{ borderColor: "#e6ebf1", margin: "24px 0" }} />

      {/* Items */}
      {items.map((item, i) => (
        <Row key={i} style={{ marginBottom: "16px" }}>
          {item.image && (
            <Column style={{ width: "80px" }}>
              <Img src={item.image} alt={item.name} width={64} height={64}
                style={{ borderRadius: "4px", objectFit: "cover" }} />
            </Column>
          )}
          <Column>
            <Text style={{ margin: "0", fontWeight: "600", color: "#1a1a1a" }}>
              {item.name}
            </Text>
            <Text style={{ margin: "2px 0 0", color: "#8898aa", fontSize: "14px" }}>
              Qty: {item.quantity}
            </Text>
          </Column>
          <Column style={{ textAlign: "right" }}>
            <Text style={{ margin: "0", fontWeight: "600" }}>
              {formatPrice(item.price * item.quantity)}
            </Text>
          </Column>
        </Row>
      ))}

      <Hr style={{ borderColor: "#e6ebf1", margin: "24px 0" }} />

      {/* Totals */}
      <Row>
        <Column><Text style={{ color: "#525f7f" }}>Subtotal</Text></Column>
        <Column style={{ textAlign: "right" }}><Text>{formatPrice(subtotal)}</Text></Column>
      </Row>
      <Row>
        <Column><Text style={{ color: "#525f7f" }}>Shipping</Text></Column>
        <Column style={{ textAlign: "right" }}>
          <Text>{shipping === 0 ? "Free" : formatPrice(shipping)}</Text>
        </Column>
      </Row>
      <Row>
        <Column><Text style={{ color: "#525f7f" }}>Tax</Text></Column>
        <Column style={{ textAlign: "right" }}><Text>{formatPrice(tax)}</Text></Column>
      </Row>
      <Row>
        <Column>
          <Text style={{ fontWeight: "bold", fontSize: "18px", color: "#1a1a1a" }}>
            Total
          </Text>
        </Column>
        <Column style={{ textAlign: "right" }}>
          <Text style={{ fontWeight: "bold", fontSize: "18px", color: "#1a1a1a" }}>
            {formatPrice(total)}
          </Text>
        </Column>
      </Row>

      <Hr style={{ borderColor: "#e6ebf1", margin: "24px 0" }} />

      {/* Shipping address */}
      <Text style={{ color: "#8898aa", fontSize: "14px", margin: "0" }}>
        Shipping to:
      </Text>
      <Text style={{ color: "#1a1a1a", margin: "4px 0 0" }}>
        {shippingAddress.line1}<br />
        {shippingAddress.city}, {shippingAddress.state} {shippingAddress.postalCode}
      </Text>

      {trackingUrl && (
        <Button
          href={trackingUrl}
          style={{
            backgroundColor: "#1a1a1a",
            color: "#ffffff",
            padding: "12px 24px",
            borderRadius: "6px",
            marginTop: "24px",
            display: "inline-block",
          }}
        >
          Track Your Order
        </Button>
      )}
    </BaseLayout>
  );
}

export default OrderConfirmation;
```

### Welcome Email

```tsx
// emails/WelcomeEmail.tsx
import { Text, Button, Link } from "@react-email/components";
import { BaseLayout } from "./layouts/BaseLayout";

interface WelcomeEmailProps {
  firstName: string;
  loginUrl: string;
}

export function WelcomeEmail({ firstName, loginUrl }: WelcomeEmailProps) {
  return (
    <BaseLayout preview={`Welcome to the store, ${firstName}!`}>
      <Text style={{ fontSize: "24px", fontWeight: "bold", color: "#1a1a1a" }}>
        Welcome, {firstName}!
      </Text>
      <Text style={{ color: "#525f7f", lineHeight: "26px" }}>
        Your account is ready. Browse our full selection of wines, spirits, and craft beers.
      </Text>
      <Button
        href={loginUrl}
        style={{
          backgroundColor: "#1a1a1a",
          color: "#ffffff",
          padding: "14px 28px",
          borderRadius: "6px",
          marginTop: "16px",
        }}
      >
        Start Shopping
      </Button>
      <Text style={{ color: "#8898aa", fontSize: "13px", marginTop: "24px" }}>
        Questions? Reply to this email or visit our{" "}
        <Link href="https://yourdomain.com/contact" style={{ color: "#1a1a1a" }}>
          contact page
        </Link>.
      </Text>
    </BaseLayout>
  );
}
```

### Password Reset Email

```tsx
// emails/PasswordReset.tsx
import { Text, Button, Link } from "@react-email/components";
import { BaseLayout } from "./layouts/BaseLayout";

interface PasswordResetProps {
  resetUrl: string;
  expiresInHours?: number;
}

export function PasswordReset({ resetUrl, expiresInHours = 24 }: PasswordResetProps) {
  return (
    <BaseLayout preview="Reset your password">
      <Text style={{ fontSize: "24px", fontWeight: "bold", color: "#1a1a1a" }}>
        Password Reset
      </Text>
      <Text style={{ color: "#525f7f", lineHeight: "26px" }}>
        We received a request to reset your password. Click the button below to choose
        a new one. This link expires in {expiresInHours} hours.
      </Text>
      <Button
        href={resetUrl}
        style={{
          backgroundColor: "#1a1a1a",
          color: "#ffffff",
          padding: "14px 28px",
          borderRadius: "6px",
        }}
      >
        Reset Password
      </Button>
      <Text style={{ color: "#8898aa", fontSize: "13px", marginTop: "24px" }}>
        If you didn't request this, you can safely ignore this email.
        Your password won't change.
      </Text>
      <Text style={{ color: "#8898aa", fontSize: "12px" }}>
        Or copy this link: <Link href={resetUrl} style={{ color: "#8898aa" }}>{resetUrl}</Link>
      </Text>
    </BaseLayout>
  );
}
```

---

## Sending from Next.js Route Handler

```typescript
// app/api/email/order-confirmation/route.ts
import { resend, FROM_EMAIL } from "@/lib/resend";
import { OrderConfirmation } from "@/emails/OrderConfirmation";

export async function POST(req: Request) {
  const { to, orderData } = await req.json();

  try {
    const { data, error } = await resend.emails.send({
      from: FROM_EMAIL,
      to,
      subject: `Order Confirmed — #${orderData.orderNumber}`,
      react: OrderConfirmation(orderData),
      // Optional: plain text fallback
      text: `Your order #${orderData.orderNumber} has been confirmed. Total: $${(orderData.total / 100).toFixed(2)}`,
      // Reply-to
      replyTo: "support@yourdomain.com",
      // Tags for filtering in dashboard
      tags: [
        { name: "category", value: "transactional" },
        { name: "type", value: "order-confirmation" },
      ],
    });

    if (error) throw new Error(error.message);

    return Response.json({ success: true, id: data?.id });
  } catch (err) {
    console.error("Email send failed:", err);
    return Response.json({ error: String(err) }, { status: 500 });
  }
}
```

### Send from server action or webhook handler

```typescript
// lib/email.ts — reusable email functions
import { resend, FROM_EMAIL } from "./resend";
import { OrderConfirmation } from "@/emails/OrderConfirmation";
import { WelcomeEmail } from "@/emails/WelcomeEmail";
import { PasswordReset } from "@/emails/PasswordReset";

export async function sendOrderConfirmation(
  to: string,
  orderData: OrderConfirmationProps
) {
  return resend.emails.send({
    from: FROM_EMAIL,
    to,
    subject: `Order #${orderData.orderNumber} Confirmed`,
    react: OrderConfirmation(orderData),
  });
}

export async function sendWelcome(to: string, props: WelcomeEmailProps) {
  return resend.emails.send({
    from: FROM_EMAIL,
    to,
    subject: "Welcome to the store!",
    react: WelcomeEmail(props),
  });
}

export async function sendPasswordReset(to: string, resetUrl: string) {
  return resend.emails.send({
    from: FROM_EMAIL,
    to,
    subject: "Reset Your Password",
    react: PasswordReset({ resetUrl }),
  });
}
```

---

## Batch Sending

```typescript
// Send up to 100 emails at once
const { data, error } = await resend.batch.send([
  {
    from: FROM_EMAIL,
    to: "customer1@example.com",
    subject: "Order Confirmed",
    react: OrderConfirmation({ ...order1 }),
  },
  {
    from: FROM_EMAIL,
    to: "customer2@example.com",
    subject: "Order Confirmed",
    react: OrderConfirmation({ ...order2 }),
  },
]);
```

---

## Domain Verification

```bash
# In Resend dashboard → Domains → Add domain
# Add DNS records:
# TXT  resend._domainkey.yourdomain.com  → (DKIM key from Resend)
# MX   feedback.yourdomain.com           → feedback-smtp.us-east-1.amazonses.com
# TXT  feedback.yourdomain.com           → (SPF record from Resend)

# Verify via CLI (if using resend CLI)
npx resend domains list
```

For testing without a domain, use: `from: "onboarding@resend.dev"` (limited to verified email addresses as recipients).

---

## Delivery Status Webhooks

```typescript
// app/api/webhooks/resend/route.ts
import { headers } from "next/headers";
import crypto from "crypto";

export async function POST(req: Request) {
  const body = await req.text();
  const sig = headers().get("svix-signature")!;
  const id = headers().get("svix-id")!;
  const timestamp = headers().get("svix-timestamp")!;

  // Verify signature (Resend uses Svix for webhooks)
  const signingSecret = process.env.RESEND_WEBHOOK_SECRET!;
  const signedContent = `${id}.${timestamp}.${body}`;
  const expectedSig = crypto
    .createHmac("sha256", Buffer.from(signingSecret.split("_")[1], "base64"))
    .update(signedContent)
    .digest("base64");

  if (!sig.split(" ").some((s) => s.startsWith("v1,") && s.slice(3) === expectedSig)) {
    return new Response("Invalid signature", { status: 400 });
  }

  const event = JSON.parse(body);

  switch (event.type) {
    case "email.sent":
      console.log("Email sent:", event.data.email_id);
      break;
    case "email.delivered":
      // Update DB: mark as delivered
      break;
    case "email.bounced":
      // Flag email as invalid, stop sending
      await markEmailBounced(event.data.to[0]);
      break;
    case "email.complained":
      // Unsubscribe user
      await unsubscribeEmail(event.data.to[0]);
      break;
    case "email.opened":
      // Track open rate
      break;
    case "email.clicked":
      // Track click-through
      break;
  }

  return new Response("OK", { status: 200 });
}
```

---

## React Email Dev Server

```bash
# Preview emails in browser
npx react-email dev

# Then open http://localhost:3000
# Emails in ./emails/ folder auto-appear in preview

# Export to HTML
npx react-email export

# Test render to string
import { render } from "@react-email/render";
const html = render(OrderConfirmation(props));
const text = render(OrderConfirmation(props), { plainText: true });
```

---

## Email Template Checklist

- [ ] Subject line is specific and includes order/action context
- [ ] Preview text set in `<Preview>` component
- [ ] CTA button has high-contrast colors, minimum 44px height
- [ ] All images have `alt` text
- [ ] Plain text version covers all key information
- [ ] Footer includes unsubscribe link (required by CAN-SPAM)
- [ ] Footer includes physical mailing address
- [ ] Tested in Gmail, Apple Mail, Outlook
- [ ] Mobile-responsive (single column, 600px max width)

## Related Skills
- `email-sequence` — email automation
- `shopify-integration` — e-commerce emails
- `zapier-make` — email automation

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/.claude/skills/resend-email/.gitnexus
Last indexed: 2026-05-23
