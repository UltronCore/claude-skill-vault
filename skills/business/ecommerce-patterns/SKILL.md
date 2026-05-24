---
name: ecommerce-patterns
description: >
  E-commerce implementation patterns: product catalog, cart state, checkout flow, inventory, and order management. Triggers on: shopping cart, checkout, product catalog, inventory, add to cart, order management, ecommerce.
---

# E-Commerce Patterns

## When to Use

Trigger when building any e-commerce feature: product listings, cart, checkout steps, inventory tracking, order status, search/filter, or wishlist. Covers React/Next.js patterns with Zustand for state, Stripe for payments, and Prisma/Postgres for persistence.

---

## Core Rules

- Cart state lives in Zustand + localStorage for guest sessions; sync to DB on auth
- Always format prices server-side or with `Intl.NumberFormat` — never raw cents in UI without formatting
- Inventory checks happen at add-to-cart AND at checkout (two-phase: soft lock → confirmed)
- Order status is an enum: `pending → processing → shipped → delivered | cancelled | refunded`
- Product slugs are URL-safe, unique, and derived from name at creation

---

## Product Data Model

```typescript
// types/product.ts
export interface Product {
  id: string;
  slug: string;
  name: string;
  description: string;
  shortDescription?: string;
  price: number;        // stored in cents (integer)
  compareAtPrice?: number;  // original price for "sale" display
  images: ProductImage[];
  variants?: ProductVariant[];
  category: string;
  tags: string[];
  inventory: number;    // stock count; -1 = unlimited
  isActive: boolean;
  isFeatured: boolean;
  metadata?: Record<string, string>;  // e.g., { abv: "12%", region: "Napa" }
  createdAt: Date;
  updatedAt: Date;
}

export interface ProductImage {
  url: string;
  alt: string;
  isPrimary: boolean;
}

export interface ProductVariant {
  id: string;
  name: string;         // e.g., "750ml", "1.5L"
  price: number;        // in cents
  inventory: number;
  sku: string;
}
```

### Prisma schema

```prisma
model Product {
  id              String    @id @default(cuid())
  slug            String    @unique
  name            String
  description     String
  price           Int       // cents
  compareAtPrice  Int?
  images          Json      // ProductImage[]
  category        String
  tags            String[]
  inventory       Int       @default(0)
  isActive        Boolean   @default(true)
  isFeatured      Boolean   @default(false)
  metadata        Json?
  createdAt       DateTime  @default(now())
  updatedAt       DateTime  @updatedAt
  orderItems      OrderItem[]
}
```

---

## Price Formatting

```typescript
// utils/price.ts
export function formatPrice(cents: number, currency = "USD"): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency,
    minimumFractionDigits: 2,
  }).format(cents / 100);
}

export function formatPriceRange(min: number, max: number): string {
  if (min === max) return formatPrice(min);
  return `${formatPrice(min)} – ${formatPrice(max)}`;
}

export function calcDiscount(original: number, sale: number): number {
  return Math.round(((original - sale) / original) * 100);
}

// Usage
formatPrice(2999);           // "$29.99"
formatPrice(5000, "EUR");    // "€50.00"
calcDiscount(3999, 2999);   // 25 (percent)
```

---

## Cart State (Zustand)

```typescript
// store/cart.ts
import { create } from "zustand";
import { persist } from "zustand/middleware";

export interface CartItem {
  productId: string;
  variantId?: string;
  name: string;
  price: number;       // cents
  quantity: number;
  image: string;
  slug: string;
  maxInventory: number;
}

interface CartStore {
  items: CartItem[];
  addItem: (item: Omit<CartItem, "quantity"> & { quantity?: number }) => void;
  removeItem: (productId: string, variantId?: string) => void;
  updateQuantity: (productId: string, quantity: number, variantId?: string) => void;
  clearCart: () => void;
  itemCount: () => number;
  subtotal: () => number;
}

export const useCartStore = create<CartStore>()(
  persist(
    (set, get) => ({
      items: [],

      addItem: (item) =>
        set((state) => {
          const key = item.variantId ?? item.productId;
          const existing = state.items.find(
            (i) => (i.variantId ?? i.productId) === key
          );
          if (existing) {
            return {
              items: state.items.map((i) =>
                (i.variantId ?? i.productId) === key
                  ? {
                      ...i,
                      quantity: Math.min(
                        i.quantity + (item.quantity ?? 1),
                        i.maxInventory
                      ),
                    }
                  : i
              ),
            };
          }
          return {
            items: [...state.items, { ...item, quantity: item.quantity ?? 1 }],
          };
        }),

      removeItem: (productId, variantId) =>
        set((state) => ({
          items: state.items.filter(
            (i) =>
              !(i.productId === productId &&
                (variantId ? i.variantId === variantId : true))
          ),
        })),

      updateQuantity: (productId, quantity, variantId) =>
        set((state) => ({
          items:
            quantity <= 0
              ? state.items.filter(
                  (i) =>
                    !(i.productId === productId &&
                      (variantId ? i.variantId === variantId : true))
                )
              : state.items.map((i) =>
                  i.productId === productId &&
                  (variantId ? i.variantId === variantId : true)
                    ? { ...i, quantity: Math.min(quantity, i.maxInventory) }
                    : i
                ),
        })),

      clearCart: () => set({ items: [] }),

      itemCount: () =>
        get().items.reduce((sum, item) => sum + item.quantity, 0),

      subtotal: () =>
        get().items.reduce(
          (sum, item) => sum + item.price * item.quantity,
          0
        ),
    }),
    {
      name: "cart-storage",
      partialize: (state) => ({ items: state.items }),
    }
  )
);
```

### Add to Cart Component

```tsx
// components/AddToCartButton.tsx
"use client";
import { useCartStore } from "@/store/cart";
import { useState } from "react";

export function AddToCartButton({ product }: { product: Product }) {
  const addItem = useCartStore((s) => s.addItem);
  const [added, setAdded] = useState(false);

  if (product.inventory === 0) {
    return <button disabled className="btn-disabled">Out of Stock</button>;
  }

  const handleAdd = () => {
    addItem({
      productId: product.id,
      name: product.name,
      price: product.price,
      image: product.images[0]?.url ?? "",
      slug: product.slug,
      maxInventory: product.inventory,
    });
    setAdded(true);
    setTimeout(() => setAdded(false), 2000);
  };

  return (
    <button onClick={handleAdd} className="btn-primary">
      {added ? "Added!" : "Add to Cart"}
    </button>
  );
}
```

---

## Product Catalog

### Server Component with filtering

```tsx
// app/shop/page.tsx
import { prisma } from "@/lib/prisma";
import { ProductCard } from "@/components/ProductCard";

interface SearchParams {
  category?: string;
  sort?: "price-asc" | "price-desc" | "newest";
  q?: string;
  page?: string;
}

const PAGE_SIZE = 12;

export default async function ShopPage({
  searchParams,
}: {
  searchParams: SearchParams;
}) {
  const page = Number(searchParams.page ?? "1");
  const skip = (page - 1) * PAGE_SIZE;

  const where = {
    isActive: true,
    ...(searchParams.category && { category: searchParams.category }),
    ...(searchParams.q && {
      OR: [
        { name: { contains: searchParams.q, mode: "insensitive" } },
        { description: { contains: searchParams.q, mode: "insensitive" } },
        { tags: { has: searchParams.q } },
      ],
    }),
  };

  const orderBy = {
    "price-asc": { price: "asc" as const },
    "price-desc": { price: "desc" as const },
    newest: { createdAt: "desc" as const },
  }[searchParams.sort ?? "newest"];

  const [products, total] = await Promise.all([
    prisma.product.findMany({ where, orderBy, skip, take: PAGE_SIZE }),
    prisma.product.count({ where }),
  ]);

  const totalPages = Math.ceil(total / PAGE_SIZE);

  return (
    <div>
      <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-6">
        {products.map((p) => <ProductCard key={p.id} product={p} />)}
      </div>
      <Pagination page={page} totalPages={totalPages} />
    </div>
  );
}
```

### Product Card

```tsx
// components/ProductCard.tsx
import Image from "next/image";
import Link from "next/link";
import { formatPrice, calcDiscount } from "@/utils/price";

export function ProductCard({ product }: { product: Product }) {
  const discount = product.compareAtPrice
    ? calcDiscount(product.compareAtPrice, product.price)
    : null;

  return (
    <Link href={`/shop/${product.slug}`} className="group">
      <div className="relative aspect-square overflow-hidden rounded-lg">
        <Image
          src={product.images[0]?.url ?? "/placeholder.jpg"}
          alt={product.images[0]?.alt ?? product.name}
          fill
          className="object-cover group-hover:scale-105 transition-transform"
          sizes="(max-width: 768px) 50vw, 25vw"
        />
        {discount && (
          <span className="absolute top-2 right-2 bg-red-500 text-white text-xs px-2 py-1 rounded">
            -{discount}%
          </span>
        )}
        {product.inventory === 0 && (
          <div className="absolute inset-0 bg-black/40 flex items-center justify-center">
            <span className="text-white font-semibold">Out of Stock</span>
          </div>
        )}
      </div>
      <div className="mt-2">
        <h3 className="font-medium text-sm truncate">{product.name}</h3>
        <div className="flex items-center gap-2">
          <span className="font-bold">{formatPrice(product.price)}</span>
          {product.compareAtPrice && (
            <span className="text-sm text-gray-400 line-through">
              {formatPrice(product.compareAtPrice)}
            </span>
          )}
        </div>
      </div>
    </Link>
  );
}
```

---

## Checkout Flow

### Multi-step checkout state

```typescript
// types/checkout.ts
export type CheckoutStep = "information" | "shipping" | "payment" | "confirmation";

export interface CheckoutState {
  step: CheckoutStep;
  email: string;
  shippingAddress: Address;
  shippingMethod?: ShippingMethod;
  paymentIntentId?: string;
}

export interface Address {
  firstName: string;
  lastName: string;
  address1: string;
  address2?: string;
  city: string;
  state: string;
  postalCode: string;
  country: string;
}
```

### Checkout step component pattern

```tsx
// app/checkout/page.tsx
"use client";
import { useState } from "react";
import { InformationStep } from "./steps/InformationStep";
import { ShippingStep } from "./steps/ShippingStep";
import { PaymentStep } from "./steps/PaymentStep";

export default function CheckoutPage() {
  const [step, setStep] = useState<CheckoutStep>("information");
  const [checkoutData, setCheckoutData] = useState<Partial<CheckoutState>>({});

  return (
    <div className="max-w-2xl mx-auto py-8">
      <CheckoutBreadcrumb currentStep={step} />

      {step === "information" && (
        <InformationStep
          onComplete={(data) => {
            setCheckoutData((prev) => ({ ...prev, ...data }));
            setStep("shipping");
          }}
        />
      )}
      {step === "shipping" && (
        <ShippingStep
          email={checkoutData.email!}
          address={checkoutData.shippingAddress!}
          onComplete={(method) => {
            setCheckoutData((prev) => ({ ...prev, shippingMethod: method }));
            setStep("payment");
          }}
          onBack={() => setStep("information")}
        />
      )}
      {step === "payment" && (
        <PaymentStep
          checkoutData={checkoutData as CheckoutState}
          onComplete={() => setStep("confirmation")}
          onBack={() => setStep("shipping")}
        />
      )}
      {step === "confirmation" && <ConfirmationStep />}
    </div>
  );
}
```

---

## Inventory Management

### Soft inventory lock at add-to-cart

```typescript
// app/api/cart/add/route.ts
export async function POST(req: Request) {
  const { productId, variantId, quantity } = await req.json();

  const product = await prisma.product.findUnique({ where: { id: productId } });
  if (!product) return Response.json({ error: "Product not found" }, { status: 404 });

  if (product.inventory !== -1 && product.inventory < quantity) {
    return Response.json(
      { error: "Insufficient inventory", available: product.inventory },
      { status: 409 }
    );
  }

  return Response.json({ success: true, inventory: product.inventory });
}
```

### Hard inventory decrement at order creation

```typescript
// Atomic inventory decrement — prevents overselling
const result = await prisma.$transaction(async (tx) => {
  const product = await tx.product.findUnique({
    where: { id: item.productId },
    select: { inventory: true },
  });

  if (product!.inventory !== -1 && product!.inventory < item.quantity) {
    throw new Error(`Insufficient inventory for ${item.productId}`);
  }

  if (product!.inventory !== -1) {
    await tx.product.update({
      where: { id: item.productId },
      data: { inventory: { decrement: item.quantity } },
    });
  }

  return tx.orderItem.create({ data: { ...item } });
});
```

---

## Order Status Flow

```typescript
// types/order.ts
export type OrderStatus =
  | "pending"      // created, payment not confirmed
  | "processing"   // payment confirmed, preparing
  | "shipped"      // tracking number assigned
  | "delivered"    // confirmed delivered
  | "cancelled"    // cancelled before ship
  | "refunded";    // refund issued

export interface Order {
  id: string;
  orderNumber: string;   // human-readable: ORD-2026-0042
  status: OrderStatus;
  items: OrderItem[];
  subtotal: number;
  shippingCost: number;
  tax: number;
  total: number;
  shippingAddress: Address;
  trackingNumber?: string;
  stripePaymentIntentId: string;
  customerEmail: string;
  createdAt: Date;
  updatedAt: Date;
}
```

### Order number generation

```typescript
export async function generateOrderNumber(): Promise<string> {
  const year = new Date().getFullYear();
  const count = await prisma.order.count({
    where: { createdAt: { gte: new Date(`${year}-01-01`) } },
  });
  return `ORD-${year}-${String(count + 1).padStart(4, "0")}`;
}
```

---

## Search & Filter Patterns

```tsx
// components/FilterBar.tsx — URL-based filter state
"use client";
import { useRouter, useSearchParams, usePathname } from "next/navigation";
import { useCallback } from "react";

export function FilterBar({ categories }: { categories: string[] }) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();

  const updateParam = useCallback(
    (key: string, value: string | null) => {
      const params = new URLSearchParams(searchParams.toString());
      if (value === null) {
        params.delete(key);
      } else {
        params.set(key, value);
      }
      params.delete("page"); // reset to page 1 on filter change
      router.push(`${pathname}?${params.toString()}`);
    },
    [pathname, router, searchParams]
  );

  return (
    <div className="flex gap-4 flex-wrap">
      <select
        value={searchParams.get("category") ?? ""}
        onChange={(e) => updateParam("category", e.target.value || null)}
      >
        <option value="">All Categories</option>
        {categories.map((c) => <option key={c} value={c}>{c}</option>)}
      </select>

      <select
        value={searchParams.get("sort") ?? "newest"}
        onChange={(e) => updateParam("sort", e.target.value)}
      >
        <option value="newest">Newest</option>
        <option value="price-asc">Price: Low to High</option>
        <option value="price-desc">Price: High to Low</option>
      </select>
    </div>
  );
}
```

---

## Wishlist Pattern

```typescript
// store/wishlist.ts (Zustand + persist)
interface WishlistStore {
  items: string[];  // product IDs
  toggle: (productId: string) => void;
  has: (productId: string) => boolean;
}

export const useWishlistStore = create<WishlistStore>()(
  persist(
    (set, get) => ({
      items: [],
      toggle: (productId) =>
        set((state) => ({
          items: state.items.includes(productId)
            ? state.items.filter((id) => id !== productId)
            : [...state.items, productId],
        })),
      has: (productId) => get().items.includes(productId),
    }),
    { name: "wishlist-storage" }
  )
);
```

```tsx
// components/WishlistButton.tsx
"use client";
import { useWishlistStore } from "@/store/wishlist";
import { Heart } from "lucide-react";

export function WishlistButton({ productId }: { productId: string }) {
  const { toggle, has } = useWishlistStore();
  const isWishlisted = has(productId);

  return (
    <button onClick={() => toggle(productId)} aria-label="Toggle wishlist">
      <Heart
        className={isWishlisted ? "fill-red-500 stroke-red-500" : "stroke-gray-400"}
      />
    </button>
  );
}
```

---

## Pagination Component

```tsx
// components/Pagination.tsx
import Link from "next/link";

export function Pagination({
  page,
  totalPages,
}: {
  page: number;
  totalPages: number;
}) {
  if (totalPages <= 1) return null;

  return (
    <div className="flex justify-center gap-2 mt-8">
      {page > 1 && (
        <Link href={`?page=${page - 1}`} className="btn">Previous</Link>
      )}
      <span className="flex items-center px-4">
        Page {page} of {totalPages}
      </span>
      {page < totalPages && (
        <Link href={`?page=${page + 1}`} className="btn">Next</Link>
      )}
    </div>
  );
}
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/business/ecommerce-patterns/.gitnexus
Last indexed: 2026-05-23
