---
name: shopify-integration
description: >
  Shopify Storefront API, Admin API, and headless commerce with Next.js. Triggers on: Shopify, Storefront API, shopify_storefront, Admin API, Shopify SDK, storefront access token, graphql shopify.
---

# Shopify Integration

## When to Use

Trigger when building headless Shopify storefronts, querying products/cart/checkout via GraphQL, setting up webhooks, or working with metafields. Covers Storefront API vs Admin API choice, Next.js headless setup, and alcohol/age verification patterns.

---

## Core Rules

- **Storefront API** = public-facing, safe for client-side, uses `storefront access token` (read-only by default)
- **Admin API** = server-side only, uses `admin API access token`, never expose to client
- Cart mutations happen via Storefront API — `cartCreate`, `cartLinesAdd`, `cartLinesUpdate`
- Checkout is handled via Shopify's hosted checkout URL (redirect) or Storefront API checkout
- Metafields are the extension point for custom product data (e.g., ABV, region, varietal)
- For alcohol (liquor store): always implement age gate before showing products

---

## API Choice

| Use Case | API |
|----------|-----|
| List products on storefront | Storefront API |
| Cart create/update | Storefront API |
| Checkout (redirect) | Storefront API |
| Customer auth (login/register) | Storefront API |
| Create/update products | Admin API |
| Order management | Admin API |
| Inventory updates | Admin API |
| Webhook registration | Admin API |
| Discount codes | Admin API |

---

## Setup

```bash
npm install @shopify/hydrogen-react
# or lightweight Storefront API client:
npm install graphql-request
```

### Environment variables

```bash
# .env.local
SHOPIFY_STORE_DOMAIN=your-store.myshopify.com
SHOPIFY_STOREFRONT_ACCESS_TOKEN=shpat_xxxxxxxx   # public
SHOPIFY_ADMIN_ACCESS_TOKEN=shpat_admin_xxxx       # NEVER expose to client
SHOPIFY_WEBHOOK_SECRET=your-webhook-secret
```

### Storefront API client

```typescript
// lib/shopify.ts
const SHOPIFY_GRAPHQL_URL = `https://${process.env.SHOPIFY_STORE_DOMAIN}/api/2024-01/graphql.json`;

export async function shopifyFetch<T>(
  query: string,
  variables?: Record<string, unknown>
): Promise<T> {
  const res = await fetch(SHOPIFY_GRAPHQL_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Shopify-Storefront-Access-Token":
        process.env.SHOPIFY_STOREFRONT_ACCESS_TOKEN!,
    },
    body: JSON.stringify({ query, variables }),
    next: { revalidate: 60 }, // ISR cache
  });

  const { data, errors } = await res.json();
  if (errors) throw new Error(errors[0].message);
  return data as T;
}
```

### Admin API client

```typescript
// lib/shopify-admin.ts (server-side only)
const ADMIN_URL = `https://${process.env.SHOPIFY_STORE_DOMAIN}/admin/api/2024-01/graphql.json`;

export async function shopifyAdminFetch<T>(
  query: string,
  variables?: Record<string, unknown>
): Promise<T> {
  const res = await fetch(ADMIN_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Shopify-Access-Token": process.env.SHOPIFY_ADMIN_ACCESS_TOKEN!,
    },
    body: JSON.stringify({ query, variables }),
  });

  const { data, errors } = await res.json();
  if (errors) throw new Error(errors[0].message);
  return data as T;
}
```

---

## GraphQL Queries — Products

### Get all products

```graphql
query GetProducts($first: Int!, $cursor: String, $query: String) {
  products(first: $first, after: $cursor, query: $query) {
    pageInfo {
      hasNextPage
      endCursor
    }
    edges {
      node {
        id
        title
        handle
        description
        priceRange {
          minVariantPrice {
            amount
            currencyCode
          }
        }
        compareAtPriceRange {
          minVariantPrice {
            amount
            currencyCode
          }
        }
        images(first: 3) {
          edges {
            node {
              url
              altText
              width
              height
            }
          }
        }
        variants(first: 10) {
          edges {
            node {
              id
              title
              price {
                amount
                currencyCode
              }
              quantityAvailable
              availableForSale
              selectedOptions {
                name
                value
              }
            }
          }
        }
        tags
        productType
        metafields(identifiers: [
          { namespace: "custom", key: "abv" }
          { namespace: "custom", key: "region" }
          { namespace: "custom", key: "varietal" }
        ]) {
          namespace
          key
          value
        }
      }
    }
  }
}
```

### Get single product by handle

```graphql
query GetProduct($handle: String!) {
  productByHandle(handle: $handle) {
    id
    title
    handle
    description
    descriptionHtml
    priceRange {
      minVariantPrice { amount currencyCode }
    }
    images(first: 10) {
      edges {
        node { url altText width height }
      }
    }
    variants(first: 20) {
      edges {
        node {
          id
          title
          price { amount currencyCode }
          compareAtPrice { amount currencyCode }
          quantityAvailable
          availableForSale
          sku
        }
      }
    }
    seo { title description }
  }
}
```

```typescript
// Usage
const { productByHandle } = await shopifyFetch<{ productByHandle: ShopifyProduct }>(
  GET_PRODUCT_QUERY,
  { handle: "meiomi-pinot-noir-2022" }
);
```

---

## Cart Operations

### Create cart

```graphql
mutation CartCreate($input: CartInput!) {
  cartCreate(input: $input) {
    cart {
      id
      checkoutUrl
      totalQuantity
      cost {
        subtotalAmount { amount currencyCode }
        totalAmount { amount currencyCode }
        totalTaxAmount { amount currencyCode }
      }
      lines(first: 100) {
        edges {
          node {
            id
            quantity
            merchandise {
              ... on ProductVariant {
                id
                title
                product { title handle }
                price { amount currencyCode }
                image { url altText }
              }
            }
            cost {
              totalAmount { amount currencyCode }
            }
          }
        }
      }
    }
    userErrors { field message }
  }
}
```

### Add to cart

```graphql
mutation CartLinesAdd($cartId: ID!, $lines: [CartLineInput!]!) {
  cartLinesAdd(cartId: $cartId, lines: $lines) {
    cart {
      id
      totalQuantity
      lines(first: 100) {
        edges {
          node {
            id
            quantity
            merchandise {
              ... on ProductVariant {
                id
                title
                price { amount currencyCode }
              }
            }
          }
        }
      }
    }
    userErrors { field message }
  }
}
```

### Update quantity

```graphql
mutation CartLinesUpdate($cartId: ID!, $lines: [CartLineUpdateInput!]!) {
  cartLinesUpdate(cartId: $cartId, lines: $lines) {
    cart {
      id
      totalQuantity
      cost { totalAmount { amount currencyCode } }
    }
    userErrors { field message }
  }
}
```

### Remove from cart

```graphql
mutation CartLinesRemove($cartId: ID!, $lineIds: [ID!]!) {
  cartLinesRemove(cartId: $cartId, lineIds: $lineIds) {
    cart { id totalQuantity }
    userErrors { field message }
  }
}
```

### Cart API wrapper

```typescript
// lib/cart.ts
export async function createCart(variantId: string, quantity = 1) {
  const { cartCreate } = await shopifyFetch<{ cartCreate: CartCreatePayload }>(
    CART_CREATE_MUTATION,
    { input: { lines: [{ merchandiseId: variantId, quantity }] } }
  );
  if (cartCreate.userErrors.length) throw new Error(cartCreate.userErrors[0].message);
  return cartCreate.cart;
}

export async function addToCart(cartId: string, variantId: string, quantity = 1) {
  const { cartLinesAdd } = await shopifyFetch<{ cartLinesAdd: CartLinesAddPayload }>(
    CART_LINES_ADD_MUTATION,
    { cartId, lines: [{ merchandiseId: variantId, quantity }] }
  );
  return cartLinesAdd.cart;
}
```

---

## Next.js Headless Setup

### App Router structure

```
app/
  shop/
    page.tsx           # Product listing
    [handle]/
      page.tsx         # Product detail
  cart/
    page.tsx           # Cart view
  checkout/
    page.tsx           # Redirect to Shopify checkout
  api/
    cart/
      create/route.ts
      add/route.ts
      update/route.ts
      remove/route.ts
```

### Product listing page (Server Component + ISR)

```tsx
// app/shop/page.tsx
import { shopifyFetch } from "@/lib/shopify";

export const revalidate = 60; // ISR: revalidate every 60s

export default async function ShopPage() {
  const { products } = await shopifyFetch<{ products: ProductConnection }>(
    GET_PRODUCTS_QUERY,
    { first: 24 }
  );

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-6">
      {products.edges.map(({ node }) => (
        <ProductCard key={node.id} product={node} />
      ))}
    </div>
  );
}
```

### Shopify checkout redirect

```typescript
// app/api/checkout/route.ts
export async function GET(req: Request) {
  const cartId = req.headers.get("x-cart-id");
  const cart = await getCart(cartId!); // fetch cart with checkoutUrl
  return Response.redirect(cart.checkoutUrl);
}
```

---

## Webhooks

### Register webhook (Admin API)

```graphql
mutation {
  webhookSubscriptionCreate(
    topic: ORDERS_PAID
    webhookSubscription: {
      format: JSON
      callbackUrl: "https://your-store.com/api/webhooks/orders-paid"
    }
  ) {
    webhookSubscription { id }
    userErrors { field message }
  }
}
```

### Verify webhook signature (Next.js)

```typescript
// app/api/webhooks/orders-paid/route.ts
import crypto from "crypto";

export async function POST(req: Request) {
  const body = await req.text();
  const hmac = req.headers.get("X-Shopify-Hmac-Sha256");

  const computed = crypto
    .createHmac("sha256", process.env.SHOPIFY_WEBHOOK_SECRET!)
    .update(body, "utf8")
    .digest("base64");

  if (computed !== hmac) {
    return new Response("Unauthorized", { status: 401 });
  }

  const order = JSON.parse(body);

  // Handle order
  await handlePaidOrder(order);

  return new Response("OK", { status: 200 });
}
```

---

## Metafields (Custom Product Data)

### Query metafields

```graphql
query GetProductWithMetafields($handle: String!) {
  productByHandle(handle: $handle) {
    title
    metafields(identifiers: [
      { namespace: "custom", key: "abv" }
      { namespace: "custom", key: "region" }
      { namespace: "custom", key: "varietal" }
      { namespace: "custom", key: "tasting_notes" }
    ]) {
      namespace
      key
      value
      type
    }
  }
}
```

### Set metafield via Admin API

```graphql
mutation SetMetafield($metafields: [MetafieldsSetInput!]!) {
  metafieldsSet(metafields: $metafields) {
    metafields { key value }
    userErrors { field message }
  }
}
```

```typescript
await shopifyAdminFetch(SET_METAFIELD_MUTATION, {
  metafields: [{
    ownerId: "gid://shopify/Product/123456789",
    namespace: "custom",
    key: "abv",
    value: "13.5%",
    type: "single_line_text_field",
  }],
});
```

---

## Age Verification (Alcohol)

```tsx
// components/AgeGate.tsx
"use client";
import { useState, useEffect } from "react";

const AGE_GATE_KEY = "age-verified";

export function AgeGate({ children }: { children: React.ReactNode }) {
  const [verified, setVerified] = useState<boolean | null>(null);

  useEffect(() => {
    const stored = localStorage.getItem(AGE_GATE_KEY);
    setVerified(stored === "true");
  }, []);

  const handleVerify = (isOfAge: boolean) => {
    if (isOfAge) {
      localStorage.setItem(AGE_GATE_KEY, "true");
      setVerified(true);
    } else {
      window.location.href = "https://responsibility.org";
    }
  };

  if (verified === null) return null; // SSR hydration

  if (!verified) {
    return (
      <div className="fixed inset-0 bg-black/90 z-50 flex items-center justify-center">
        <div className="bg-white rounded-xl p-8 max-w-md text-center">
          <h2 className="text-2xl font-bold mb-2">Age Verification</h2>
          <p className="text-gray-600 mb-6">
            You must be 21 years or older to enter this site.
            Are you of legal drinking age?
          </p>
          <div className="flex gap-4 justify-center">
            <button
              onClick={() => handleVerify(true)}
              className="bg-black text-white px-6 py-2 rounded-lg"
            >
              Yes, I am 21+
            </button>
            <button
              onClick={() => handleVerify(false)}
              className="border px-6 py-2 rounded-lg"
            >
              No
            </button>
          </div>
        </div>
      </div>
    );
  }

  return <>{children}</>;
}
```

---

## Hydrogen React (Optional)

For projects using Shopify's official React components:

```tsx
import {
  ShopifyProvider,
  CartProvider,
  useCart,
  Money,
  Image,
  AddToCartButton,
} from "@shopify/hydrogen-react";

// Wrap app
<ShopifyProvider
  storeDomain={process.env.NEXT_PUBLIC_SHOPIFY_STORE_DOMAIN!}
  storefrontToken={process.env.NEXT_PUBLIC_SHOPIFY_STOREFRONT_TOKEN!}
  storefrontApiVersion="2024-01"
  countryIsoCode="US"
  languageIsoCode="EN"
>
  <CartProvider>
    <App />
  </CartProvider>
</ShopifyProvider>

// Price formatting
<Money data={variant.price} />  // renders "$29.99"

// Image with Shopify CDN optimization
<Image data={product.images.edges[0].node} width={800} />
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/business/shopify-integration/.gitnexus
Last indexed: 2026-05-23
