# Skill Memory: uni-app Frontend Development

## Purpose
Comprehensive development guide for cross-platform uni-app projects using Vue 3 and TypeScript. Covers CLI project structure, UI library integration (uView Plus, uni-ui, TuniaoUI), SCSS theming with global variable injection via vite.config.ts additionalData, Pinia state management, uni.request API patterns with interceptors, lifecycle hooks, platform detection with conditional compilation directives, and multi-platform build commands.

## Category notes
Belongs in ui-ux because it is entirely focused on frontend component development, theming, and user interface construction for the uni-app cross-platform ecosystem (WeChat Mini Programs, H5, etc.).

## Relationships
None identified — this skill is self-contained for the uni-app ecosystem and does not share components with React/Next.js-focused ui-ux skills.

## Maintenance notes
SCSS preprocessor configuration uses api: "modern-compiler" which requires a compatible sass version. Build command names follow the standard uni-app CLI convention (dev/build:mp-weixin, dev/build:h5, etc.).
