---
name: design-tokens
description: Create, manage, and distribute design tokens across platforms (web, iOS, Android, React Native). Covers W3C token format, Style Dictionary, Figma token sync, and multi-theme support.
version: 1.0.0
tags: [design-tokens, design-system, css-variables, style-dictionary, figma, theming, cross-platform]
---

# Design Tokens

## Overview

This skill covers the complete design token workflow: defining tokens in the W3C Design Token Community Group format, transforming them for multiple platforms (CSS custom properties, Swift UIColor, Android XML, React Native StyleSheet) using Style Dictionary, syncing with Figma, and managing themes (light/dark, brand variants). Design tokens are the single source of truth for visual decisions.

## When to Use

- Building or scaling a design system that needs cross-platform consistency
- Adding dark mode to an existing application
- Managing multiple brand themes from one token set
- Syncing design decisions from Figma to code automatically
- Replacing hardcoded hex colors and spacing values with semantic tokens

## Step-by-Step Workflow

### 1. Token Taxonomy (Three-Tier System)
```
Tier 1: PRIMITIVE (raw values — never use directly in components)
  color.red.500 = #EF4444
  spacing.4 = 16px
  font.size.md = 16px

Tier 2: SEMANTIC (meaning-based — these are what code and design use)
  color.surface.error = {color.red.500}
  color.text.primary = {color.gray.900}
  spacing.component.padding.md = {spacing.4}

Tier 3: COMPONENT (specific component overrides — use sparingly)
  button.primary.background = {color.surface.brand}
  button.primary.padding.x = {spacing.component.padding.md}
```

### 2. Token Definition (W3C Format)
```json
// tokens/base/colors.json
{
  "color": {
    "brand": {
      "50":  { "$value": "#EFF6FF", "$type": "color" },
      "500": { "$value": "#3B82F6", "$type": "color" },
      "900": { "$value": "#1E3A8A", "$type": "color" }
    },
    "neutral": {
      "0":   { "$value": "#FFFFFF", "$type": "color" },
      "900": { "$value": "#111827", "$type": "color" },
      "950": { "$value": "#030712", "$type": "color" }
    },
    "red": {
      "500": { "$value": "#EF4444", "$type": "color" }
    },
    "green": {
      "500": { "$value": "#22C55E", "$type": "color" }
    }
  }
}
```

```json
// tokens/semantic/light.json — References primitives
{
  "color": {
    "surface": {
      "primary":   { "$value": "{color.neutral.0}", "$type": "color" },
      "secondary": { "$value": "#F9FAFB", "$type": "color" },
      "brand":     { "$value": "{color.brand.500}", "$type": "color" },
      "error":     { "$value": "{color.red.500}", "$type": "color" },
      "success":   { "$value": "{color.green.500}", "$type": "color" }
    },
    "text": {
      "primary":   { "$value": "{color.neutral.900}", "$type": "color" },
      "secondary": { "$value": "#6B7280", "$type": "color" },
      "inverse":   { "$value": "{color.neutral.0}", "$type": "color" },
      "error":     { "$value": "{color.red.500}", "$type": "color" }
    },
    "border": {
      "default": { "$value": "#E5E7EB", "$type": "color" },
      "focus":   { "$value": "{color.brand.500}", "$type": "color" }
    }
  },
  "spacing": {
    "1": { "$value": "4px", "$type": "dimension" },
    "2": { "$value": "8px", "$type": "dimension" },
    "4": { "$value": "16px", "$type": "dimension" },
    "6": { "$value": "24px", "$type": "dimension" },
    "8": { "$value": "32px", "$type": "dimension" }
  },
  "border-radius": {
    "sm": { "$value": "4px", "$type": "dimension" },
    "md": { "$value": "8px", "$type": "dimension" },
    "lg": { "$value": "16px", "$type": "dimension" },
    "full": { "$value": "9999px", "$type": "dimension" }
  }
}
```

### 3. Style Dictionary Configuration
```bash
npm install -D style-dictionary
```

```javascript
// style-dictionary.config.js
const StyleDictionary = require('style-dictionary');

// Custom transform: px to rem
StyleDictionary.registerTransform({
  name: 'size/pxToRem',
  type: 'value',
  matcher: token => token.$type === 'dimension',
  transformer: token => {
    const value = parseFloat(token.$value);
    return `${value / 16}rem`;
  },
});

module.exports = {
  source: ['tokens/**/*.json'],
  platforms: {
    css: {
      transformGroup: 'css',
      transforms: ['name/cti/kebab', 'color/hsl', 'size/pxToRem'],
      prefix: 'ds',
      buildPath: 'dist/css/',
      files: [{
        destination: 'tokens.css',
        format: 'css/variables',
        options: { outputReferences: true },
      }],
    },
    js: {
      transformGroup: 'js',
      buildPath: 'dist/js/',
      files: [{
        destination: 'tokens.js',
        format: 'javascript/es6',
      }, {
        destination: 'tokens.d.ts',
        format: 'typescript/es6-declarations',
      }],
    },
    ios: {
      transformGroup: 'ios-swift',
      buildPath: 'dist/ios/',
      files: [{
        destination: 'DesignTokens.swift',
        format: 'ios-swift/class.swift',
        className: 'DesignTokens',
      }],
    },
    android: {
      transformGroup: 'android',
      buildPath: 'dist/android/',
      files: [{
        destination: 'tokens.xml',
        format: 'android/resources',
      }],
    },
  },
};
```

```bash
npx style-dictionary build --config style-dictionary.config.js
```

### 4. Generated CSS Output
```css
/* dist/css/tokens.css */
:root {
  --ds-color-surface-primary: hsl(0, 0%, 100%);
  --ds-color-surface-brand: hsl(217, 91%, 60%);
  --ds-color-text-primary: hsl(220, 26%, 14%);
  --ds-spacing-1: 0.25rem;
  --ds-spacing-4: 1rem;
  --ds-border-radius-md: 0.5rem;
}

/* Dark theme override */
[data-theme="dark"] {
  --ds-color-surface-primary: hsl(222, 47%, 7%);
  --ds-color-text-primary: hsl(0, 0%, 98%);
}
```

### 5. React Usage
```tsx
// Using CSS custom properties
const Button = styled.button`
  background: var(--ds-color-surface-brand);
  color: var(--ds-color-text-inverse);
  padding: var(--ds-spacing-2) var(--ds-spacing-4);
  border-radius: var(--ds-border-radius-md);
  border: 2px solid transparent;
  
  &:focus-visible {
    outline: 2px solid var(--ds-color-border-focus);
  }
`;

// Or with JS tokens for dynamic theming
import tokens from '../dist/js/tokens';
const style = {
  background: tokens.colorSurfaceBrand,
  padding: `${tokens.spacing2} ${tokens.spacing4}`,
};
```

### 6. Dark Mode Switch
```tsx
function ThemeProvider({ children }) {
  const [theme, setTheme] = useState<'light' | 'dark'>('light');
  
  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme);
  }, [theme]);
  
  const toggleTheme = () => setTheme(t => t === 'light' ? 'dark' : 'light');
  
  return (
    <ThemeContext.Provider value={{ theme, toggleTheme }}>
      {children}
    </ThemeContext.Provider>
  );
}
```

## Key Commands Reference

```bash
# Build all platforms
npx style-dictionary build

# Build specific platform
npx style-dictionary build --platform css

# Watch mode for development
npx style-dictionary build --watch

# Validate token format
npx token-validator tokens/

# Figma Tokens plugin export → import
# In Figma: Plugins → Tokens Studio → Export → JSON (W3C format)
# Then run: npx style-dictionary build

# Check for token references that don't resolve
npx style-dictionary build 2>&1 | grep "Reference"
```

## Common Patterns

### Pattern 1: Multi-Brand Theming
```json
// tokens/brands/acme/overrides.json
{
  "color": {
    "brand": {
      "500": { "$value": "#FF6B00", "$type": "color" }
    }
  }
}
```
```javascript
// style-dictionary.config.js — per-brand build
['default', 'acme', 'enterprise'].forEach(brand => {
  StyleDictionary.extend({
    source: ['tokens/base/**/*.json', 'tokens/semantic/light.json'],
    include: brand !== 'default' ? [`tokens/brands/${brand}/**/*.json`] : [],
    platforms: {
      css: {
        buildPath: `dist/${brand}/css/`,
        files: [{ destination: 'tokens.css', format: 'css/variables' }],
      }
    }
  }).buildAllPlatforms();
});
```

### Pattern 2: iOS Swift Tokens
```swift
// Generated DesignTokens.swift
import UIKit

public class DesignTokens: NSObject {
  public static let colorSurfacePrimary = UIColor(named: "color.surface.primary") ?? .white
  public static let colorSurfaceBrand = UIColor(red: 0.235, green: 0.510, blue: 0.961, alpha: 1.0)
  public static let spacing4: CGFloat = 16.0
  public static let borderRadiusMd: CGFloat = 8.0
}

// Usage in SwiftUI
Text("Hello").padding(DesignTokens.spacing4)
```

### Pattern 3: Figma ↔ Code Sync Workflow
```bash
# 1. Export from Figma Tokens Studio → JSON
# 2. Place in tokens/ directory
# 3. Run Style Dictionary build
# 4. Commit generated files
# 5. Optional: GitHub Action to auto-build on token changes
```

## Pitfalls to Avoid

1. **Using primitive tokens directly in components**: Using `color.red.500` in a button instead of `color.surface.error` means you can't change the error color globally or support themes. Always go through semantic tokens in component code — primitives are for building semantic tokens only.

2. **Too many token tiers**: More than 3 tiers (primitive → semantic → component) becomes hard to reason about. Component tokens should be rare exceptions for specific overrides. Most components should only reference semantic tokens.

3. **Not versioning the generated output**: Generated CSS/Swift/Android files should be committed to the repo or published to a package. Don't make platform teams run the build tool themselves — it creates drift. Use a CI step to build and publish tokens as a versioned artifact.

## Related Skills

- `tailwind-shadcn-ui-setup` — Integrating design tokens with Tailwind CSS
- `frontend-design` — Using tokens in component libraries
- `ios-swiftui-expert` — SwiftUI design token integration
- `theme-factory` — Advanced theming patterns

## GitNexus Index

```json
{
  "skill": "design-tokens",
  "category": "ui-ux",
  "triggers": ["design tokens", "style dictionary", "css variables", "theming", "dark mode tokens", "figma tokens", "cross-platform design"],
  "outputs": ["token JSON", "CSS variables", "Swift tokens", "Android XML", "JS tokens"],
  "complexity": "medium",
  "tools": ["style-dictionary", "figma-tokens", "tokens-studio", "tailwind"]
}
```
