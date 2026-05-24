---
name: framer-motion
description: >
  Framer Motion animations for React: layout animations, gesture-based animations, shared layout, and exit animations. Triggers on: framer-motion, motion., AnimatePresence, layoutId, useMotionValue, useSpring, useTransform, whileHover, whileTap.
---

# Framer Motion

## When to Use

Use Framer Motion for any animation in a React/Next.js app: entrance/exit transitions, layout shifts, drag gestures, scroll-driven effects, and page transitions. Always respect `prefers-reduced-motion`.

---

## Installation

```bash
npm install framer-motion
```

---

## `motion.div` Basics

```typescript
import { motion } from 'framer-motion'

// Animate on mount
<motion.div
  initial={{ opacity: 0, y: 20 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{ duration: 0.4, ease: 'easeOut' }}
>
  Hello world
</motion.div>

// Shorthand with variants
const cardVariants = {
  hidden: { opacity: 0, scale: 0.95, y: 20 },
  visible: {
    opacity: 1,
    scale: 1,
    y: 0,
    transition: { duration: 0.3, ease: [0.25, 0.46, 0.45, 0.94] },
  },
  exit: { opacity: 0, scale: 0.95, transition: { duration: 0.2 } },
}

<motion.div
  variants={cardVariants}
  initial="hidden"
  animate="visible"
  exit="exit"
>
  Card content
</motion.div>
```

---

## AnimatePresence + Exit Animations

```typescript
import { AnimatePresence, motion } from 'framer-motion'
import { useState } from 'react'

// AnimatePresence lets components animate out before unmounting
function NotificationStack() {
  const [notifications, setNotifications] = useState<Notification[]>([])

  return (
    <div className="fixed bottom-4 right-4 flex flex-col gap-2">
      <AnimatePresence mode="popLayout">  {/* mode="popLayout" prevents layout flash */}
        {notifications.map(n => (
          <motion.div
            key={n.id}
            layout                             // animate layout changes
            initial={{ opacity: 0, x: 50, scale: 0.9 }}
            animate={{ opacity: 1, x: 0, scale: 1 }}
            exit={{ opacity: 0, x: 50, scale: 0.9 }}
            transition={{ type: 'spring', stiffness: 300, damping: 25 }}
            className="bg-white rounded-lg shadow-lg p-4"
          >
            {n.message}
          </motion.div>
        ))}
      </AnimatePresence>
    </div>
  )
}

// Modal with AnimatePresence
function Modal({ isOpen, onClose, children }: ModalProps) {
  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Backdrop */}
          <motion.div
            key="backdrop"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 bg-black/50"
            onClick={onClose}
          />
          {/* Panel */}
          <motion.div
            key="modal"
            initial={{ opacity: 0, scale: 0.95, y: 10 }}
            animate={{ opacity: 1, scale: 1, y: 0 }}
            exit={{ opacity: 0, scale: 0.95, y: 10 }}
            transition={{ type: 'spring', stiffness: 400, damping: 30 }}
            className="fixed inset-0 flex items-center justify-center pointer-events-none"
          >
            <div className="pointer-events-auto bg-white rounded-xl p-6 max-w-md w-full">
              {children}
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  )
}
```

---

## Layout Animations

```typescript
// layout prop — automatically animates layout changes (size, position)
function AccordionItem({ title, children }: AccordionItemProps) {
  const [isOpen, setIsOpen] = useState(false)

  return (
    <motion.div layout className="border rounded-lg overflow-hidden">
      <motion.button
        layout
        onClick={() => setIsOpen(v => !v)}
        className="w-full p-4 text-left font-medium flex justify-between"
      >
        {title}
        <motion.span animate={{ rotate: isOpen ? 180 : 0 }}>▼</motion.span>
      </motion.button>

      <AnimatePresence initial={false}>
        {isOpen && (
          <motion.div
            key="content"
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: 'auto', opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.3, ease: 'easeInOut' }}
            className="overflow-hidden"
          >
            <div className="p-4">{children}</div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  )
}

// Animated list reordering
function SortableList({ items }: { items: Item[] }) {
  return (
    <ul>
      {items.map(item => (
        <motion.li
          key={item.id}
          layout                           // animates when order changes
          transition={{ type: 'spring', stiffness: 300, damping: 30 }}
          className="p-4 mb-2 bg-white rounded-lg shadow"
        >
          {item.title}
        </motion.li>
      ))}
    </ul>
  )
}
```

---

## Shared Layout (`layoutId`)

```typescript
// layoutId — animate between two separate elements that share an ID
// Perfect for: selected tabs, image galleries, card-to-detail transitions

function TabBar({ tabs, activeTab, onSelect }: TabBarProps) {
  return (
    <div className="flex gap-2 relative">
      {tabs.map(tab => (
        <button
          key={tab.id}
          onClick={() => onSelect(tab.id)}
          className="relative px-4 py-2 text-sm font-medium"
        >
          {tab.id === activeTab && (
            <motion.div
              layoutId="tab-indicator"     // same ID — animates between positions
              className="absolute inset-0 bg-blue-100 rounded-full"
              transition={{ type: 'spring', stiffness: 400, damping: 30 }}
            />
          )}
          <span className="relative z-10">{tab.label}</span>
        </button>
      ))}
    </div>
  )
}

// Card → Detail transition
function GalleryItem({ item }: { item: GalleryItem }) {
  const [isExpanded, setIsExpanded] = useState(false)

  return (
    <>
      <motion.div
        layoutId={`card-${item.id}`}
        onClick={() => setIsExpanded(true)}
        className="cursor-pointer rounded-xl overflow-hidden"
      >
        <motion.img layoutId={`image-${item.id}`} src={item.src} alt={item.title} />
        <motion.h3 layoutId={`title-${item.id}`}>{item.title}</motion.h3>
      </motion.div>

      <AnimatePresence>
        {isExpanded && (
          <motion.div
            layoutId={`card-${item.id}`}
            className="fixed inset-4 z-50 rounded-xl overflow-hidden"
            onClick={() => setIsExpanded(false)}
          >
            <motion.img layoutId={`image-${item.id}`} src={item.src} alt={item.title} />
            <motion.h3 layoutId={`title-${item.id}`}>{item.title}</motion.h3>
            <p>{item.description}</p>
          </motion.div>
        )}
      </AnimatePresence>
    </>
  )
}
```

---

## Gesture Animations (whileHover, whileTap, drag)

```typescript
// whileHover and whileTap — declarative gesture states
<motion.button
  whileHover={{ scale: 1.05, boxShadow: '0 8px 20px rgba(0,0,0,0.15)' }}
  whileTap={{ scale: 0.97 }}
  transition={{ type: 'spring', stiffness: 400, damping: 25 }}
  className="px-6 py-3 bg-blue-600 text-white rounded-xl font-medium"
>
  Click me
</motion.button>

// Draggable element with constraints
function DraggableCard() {
  const constraintsRef = useRef(null)

  return (
    <div ref={constraintsRef} className="relative h-64 w-full border rounded-xl">
      <motion.div
        drag
        dragConstraints={constraintsRef}  // constrain within parent
        dragElastic={0.1}                 // bounciness when hitting constraints
        dragTransition={{ bounceStiffness: 300, bounceDamping: 20 }}
        whileDrag={{ scale: 1.05, cursor: 'grabbing' }}
        className="absolute top-4 left-4 w-32 h-32 bg-blue-500 rounded-xl cursor-grab"
      />
    </div>
  )
}

// Drag-to-dismiss (swipe away)
function SwipeDismiss({ onDismiss, children }: SwipeDismissProps) {
  const x = useMotionValue(0)
  const opacity = useTransform(x, [-150, 0, 150], [0, 1, 0])

  function handleDragEnd(_: Event, info: PanInfo) {
    if (Math.abs(info.offset.x) > 100) onDismiss()
  }

  return (
    <motion.div
      style={{ x, opacity }}
      drag="x"
      dragConstraints={{ left: 0, right: 0 }}
      onDragEnd={handleDragEnd}
    >
      {children}
    </motion.div>
  )
}
```

---

## Scroll-Driven Animations (`useScroll`)

```typescript
import { useScroll, useTransform, useSpring, motion } from 'framer-motion'
import { useRef } from 'react'

// Parallax effect
function ParallaxSection() {
  const ref = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ['start end', 'end start'],  // when element enters/exits viewport
  })

  const y = useTransform(scrollYProgress, [0, 1], ['0%', '-20%'])

  return (
    <div ref={ref} className="relative h-screen overflow-hidden">
      <motion.div style={{ y }} className="absolute inset-0">
        <img src="/hero.jpg" alt="" className="w-full h-full object-cover" />
      </motion.div>
    </div>
  )
}

// Scroll progress indicator
function ScrollProgress() {
  const { scrollYProgress } = useScroll()
  const scaleX = useSpring(scrollYProgress, { stiffness: 100, damping: 30 })

  return (
    <motion.div
      style={{ scaleX, transformOrigin: 'left' }}
      className="fixed top-0 left-0 right-0 h-1 bg-blue-500 z-50"
    />
  )
}

// Fade in on scroll
function FadeInOnScroll({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLDivElement>(null)
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ['start 0.9', 'start 0.5'],  // triggers as element enters viewport
  })
  const opacity = useTransform(scrollYProgress, [0, 1], [0, 1])
  const y = useTransform(scrollYProgress, [0, 1], [30, 0])

  return (
    <motion.div ref={ref} style={{ opacity, y }}>
      {children}
    </motion.div>
  )
}
```

---

## `useMotionValue`, `useTransform`, `useSpring`

```typescript
import { useMotionValue, useTransform, useSpring, motion } from 'framer-motion'

// useMotionValue — imperative animated value (no re-renders)
function MagneticButton() {
  const x = useMotionValue(0)
  const y = useMotionValue(0)

  // useSpring — adds physical spring behavior to any motion value
  const springX = useSpring(x, { stiffness: 150, damping: 15 })
  const springY = useSpring(y, { stiffness: 150, damping: 15 })

  function handleMouseMove(e: React.MouseEvent) {
    const rect = e.currentTarget.getBoundingClientRect()
    const centerX = rect.left + rect.width / 2
    const centerY = rect.top + rect.height / 2
    x.set((e.clientX - centerX) * 0.3)
    y.set((e.clientY - centerY) * 0.3)
  }

  function handleMouseLeave() {
    x.set(0)
    y.set(0)
  }

  return (
    <motion.button
      style={{ x: springX, y: springY }}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      whileHover={{ scale: 1.1 }}
      className="px-8 py-4 bg-black text-white rounded-full"
    >
      Hover me
    </motion.button>
  )
}

// useTransform — map one motion value to another
function RotatingCard() {
  const x = useMotionValue(0)
  // Map x position to rotation: -20px → -15deg, 0 → 0deg, 20px → 15deg
  const rotateY = useTransform(x, [-100, 100], [-15, 15])
  const brightness = useTransform(x, [-100, 0, 100], [0.7, 1, 1.3])

  return (
    <motion.div
      style={{ x, rotateY, filter: useTransform(brightness, v => `brightness(${v})`) }}
      drag="x"
      dragConstraints={{ left: -100, right: 100 }}
      className="w-48 h-64 bg-gradient-to-br from-blue-500 to-purple-600 rounded-xl"
    />
  )
}
```

---

## Reduced Motion

```typescript
import { useReducedMotion, motion } from 'framer-motion'

// Always respect prefers-reduced-motion
function AnimatedCard({ children }: { children: React.ReactNode }) {
  const shouldReduce = useReducedMotion()

  return (
    <motion.div
      initial={{ opacity: 0, y: shouldReduce ? 0 : 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: shouldReduce ? 0 : 0.4 }}
    >
      {children}
    </motion.div>
  )
}

// Global variant-based approach
function useAnimationConfig() {
  const shouldReduce = useReducedMotion()
  return {
    initial: { opacity: 0, y: shouldReduce ? 0 : 24 },
    animate: { opacity: 1, y: 0 },
    transition: { duration: shouldReduce ? 0 : 0.5 },
  }
}
```

---

## Page Transitions (Next.js App Router)

```typescript
// components/page-transition.tsx
'use client'
import { motion, AnimatePresence } from 'framer-motion'
import { usePathname } from 'next/navigation'

const pageVariants = {
  hidden: { opacity: 0, y: 8 },
  enter: { opacity: 1, y: 0, transition: { duration: 0.35, ease: 'easeOut' } },
  exit: { opacity: 0, y: -8, transition: { duration: 0.2 } },
}

export function PageTransition({ children }: { children: React.ReactNode }) {
  const pathname = usePathname()

  return (
    <AnimatePresence mode="wait" initial={false}>
      <motion.main
        key={pathname}
        variants={pageVariants}
        initial="hidden"
        animate="enter"
        exit="exit"
      >
        {children}
      </motion.main>
    </AnimatePresence>
  )
}

// Use in app/layout.tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        <PageTransition>{children}</PageTransition>
      </body>
    </html>
  )
}
```

---

## Stagger Children Pattern

```typescript
const containerVariants = {
  hidden: {},
  visible: {
    transition: {
      staggerChildren: 0.08,    // delay between each child
      delayChildren: 0.1,       // delay before first child
    },
  },
}

const itemVariants = {
  hidden: { opacity: 0, y: 20 },
  visible: { opacity: 1, y: 0, transition: { type: 'spring', stiffness: 300, damping: 24 } },
}

function StaggeredList({ items }: { items: string[] }) {
  return (
    <motion.ul
      variants={containerVariants}
      initial="hidden"
      animate="visible"
    >
      {items.map((item, i) => (
        <motion.li key={i} variants={itemVariants}>
          {item}
        </motion.li>
      ))}
    </motion.ul>
  )
}
```

## GitNexus Index
This skill is indexed by GitNexus for knowledge graph traversal.
Index path: /Users/localuser/claude-skill-vault/skills/ui-ux/framer-motion/.gitnexus
Last indexed: 2026-05-23
