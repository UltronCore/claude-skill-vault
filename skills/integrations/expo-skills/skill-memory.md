# Skill Memory: Expo Skills

## Purpose
Provides an opinionated, comprehensive guide for scaffolding and developing Expo React Native mobile applications. Enforces a specific technology stack including NativeTabs navigation, RevenueCat for subscriptions, Google AdMob for advertising, i18next for localization, and expo-sqlite for local storage. Defines mandatory screens (onboarding with video, paywall, settings), forbidden patterns (AsyncStorage, lineHeight, expo-av), and required post-creation cleanup steps to ensure consistent, production-ready app output.

## Category notes
Belongs in integrations because it integrates multiple third-party services and libraries (RevenueCat, AdMob, Expo ecosystem) into a cohesive React Native development workflow.

## Relationships
- Complementary to sentry-and-otel-setup for adding observability to mobile apps
- Standalone for mobile projects; the Supabase skills address web (Next.js) use cases

## Maintenance notes
Monitor for Expo SDK version changes, NativeTabs API stability (currently marked unstable), RevenueCat SDK updates, and AdMob configuration changes. The Turkish localization section is domain-specific and may indicate the skill was originally authored for a Turkish-market app — treat as general best practice guidance.
