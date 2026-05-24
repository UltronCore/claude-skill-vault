---
name: flutter-development
description: Build cross-platform mobile and web apps with Flutter and Dart. Covers widget composition, state management with Riverpod, navigation, platform channels, testing, and deployment.
version: 1.0.0
tags: [flutter, dart, cross-platform, mobile, riverpod, state-management, ios, android]
---

# Flutter Development

## Overview

This skill covers building production Flutter apps for iOS, Android, and web from a single codebase. It addresses Dart fundamentals, Flutter widget composition, state management with Riverpod 2.x, navigation with GoRouter, platform channels for native code, testing strategies, and publishing to the App Store and Google Play. Targets developers coming from React Native, SwiftUI, or web backgrounds.

## When to Use

- Building a new mobile app that needs to support iOS and Android simultaneously
- Migrating from React Native to Flutter for better performance and tooling
- Adding web support to an existing Flutter mobile app
- Building internal tools that need desktop + mobile (Flutter's strength)
- When pixel-perfect custom UI is required across both platforms

## Step-by-Step Workflow

### 1. Project Setup
```bash
flutter create my_app --org com.example --platforms ios,android,web
cd my_app
flutter pub get
flutter run  # Picks connected device/emulator

# Enable all platforms
flutter config --enable-web
flutter config --enable-macos-desktop

# Analyze and format
flutter analyze
dart format .
```

### 2. Widget Composition
```dart
// lib/features/product/widgets/product_card.dart
import 'package:flutter/material.dart';
import '../models/product.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.showBadge = false,
  });

  final Product product;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : const Center(child: CircularProgressIndicator()),
                    errorBuilder: (_, __, ___) => 
                        const Icon(Icons.broken_image, size: 48),
                  ),
                ),
                if (showBadge && product.isNew)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('NEW',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text('\$${product.price.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### 3. State Management with Riverpod 2.x
```dart
// lib/features/product/providers/product_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/product.dart';
import '../repositories/product_repository.dart';

part 'product_provider.g.dart';

// Async provider — fetch products
@riverpod
Future<List<Product>> products(ProductsRef ref, {String? categoryId}) async {
  final repo = ref.watch(productRepositoryProvider);
  return repo.fetchProducts(categoryId: categoryId);
}

// Notifier for cart state
@riverpod
class CartNotifier extends _$CartNotifier {
  @override
  Map<String, int> build() => {}; // productId -> quantity

  void addItem(String productId) {
    state = {...state, productId: (state[productId] ?? 0) + 1};
  }

  void removeItem(String productId) {
    if ((state[productId] ?? 0) <= 1) {
      final newState = Map<String, int>.from(state);
      newState.remove(productId);
      state = newState;
    } else {
      state = {...state, productId: state[productId]! - 1};
    }
  }

  int get totalItems => state.values.fold(0, (a, b) => a + b);
}

// Usage in widget
class ProductListPage extends ConsumerWidget {
  const ProductListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider());
    final cartNotifier = ref.read(cartNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          Badge(
            label: Text('${ref.watch(cartNotifierProvider).values.fold(0, (a, b) => a + b)}'),
            child: IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () => context.push('/cart'),
            ),
          ),
        ],
      ),
      body: productsAsync.when(
        data: (products) => GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: products.length,
          itemBuilder: (_, i) => ProductCard(
            product: products[i],
            onTap: () => context.push('/product/${products[i].id}'),
            showBadge: true,
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
```

### 4. Navigation with GoRouter
```dart
// lib/app/router.dart
import 'package:go_router/go_router.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isAuthenticated = ref.read(authProvider).isAuthenticated;
    if (!isAuthenticated && !state.matchedLocation.startsWith('/auth')) {
      return '/auth/login?redirect=${state.matchedLocation}';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const HomePage(),
    ),
    GoRoute(
      path: '/product/:id',
      builder: (_, state) => ProductDetailPage(id: state.pathParameters['id']!),
    ),
    ShellRoute(
      builder: (_, __, child) => MainShell(child: child),
      routes: [
        GoRoute(path: '/cart', builder: (_, __) => const CartPage()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      ],
    ),
    GoRoute(
      path: '/auth/login',
      builder: (context, state) => LoginPage(
        redirect: state.uri.queryParameters['redirect'],
      ),
    ),
  ],
);
```

### 5. Testing
```dart
// test/features/product/product_card_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('ProductCard shows product name and price', (tester) async {
    final product = Product(id: '1', name: 'Test Product', price: 29.99, imageUrl: '');
    
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: ProductCard(product: product, onTap: () {})),
        ),
      ),
    );

    expect(find.text('Test Product'), findsOneWidget);
    expect(find.text('\$29.99'), findsOneWidget);
  });

  // Riverpod provider test
  test('CartNotifier adds and removes items', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    
    final notifier = container.read(cartNotifierProvider.notifier);
    
    notifier.addItem('prod-1');
    expect(container.read(cartNotifierProvider), {'prod-1': 1});
    
    notifier.addItem('prod-1');
    expect(container.read(cartNotifierProvider), {'prod-1': 2});
    
    notifier.removeItem('prod-1');
    expect(container.read(cartNotifierProvider), {'prod-1': 1});
  });
}
```

## Key Commands Reference

```bash
# Development
flutter run -d ios           # Run on iOS
flutter run -d android       # Run on Android
flutter run -d chrome        # Run in browser
flutter run --flavor prod    # Run with flavor

# Build
flutter build apk --release         # Android APK
flutter build appbundle --release   # Android AAB (Play Store)
flutter build ipa --release         # iOS IPA
flutter build web --release         # Web

# Code generation (Riverpod, Freezed)
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch  # Auto-regenerate on save

# Testing
flutter test
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Update packages
flutter pub outdated
flutter pub upgrade
```

## Common Patterns

### Pattern 1: Freezed for Immutable Models
```dart
// lib/features/product/models/product.dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'product.freezed.dart';
part 'product.g.dart';

@freezed
class Product with _$Product {
  const factory Product({
    required String id,
    required String name,
    required double price,
    required String imageUrl,
    @Default(false) bool isNew,
    @Default([]) List<String> tags,
  }) = _Product;

  factory Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);
}
```

### Pattern 2: Platform Channel for Native Features
```dart
// lib/platform/biometric_auth.dart
import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  final _auth = LocalAuthentication();
  
  Future<bool> authenticate() async {
    final canAuth = await _auth.canCheckBiometrics;
    if (!canAuth) return false;
    
    return _auth.authenticate(
      localizedReason: 'Authenticate to access your account',
      options: const AuthenticationOptions(biometricOnly: true),
    );
  }
}
```

### Pattern 3: Responsive Layout
```dart
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        if (constraints.maxWidth >= 1200 && desktop != null) return desktop!;
        if (constraints.maxWidth >= 600 && tablet != null) return tablet!;
        return mobile;
      },
    );
  }
}
```

## Pitfalls to Avoid

1. **Rebuilding the entire widget tree on state change**: Using `Consumer` or `ref.watch` at the widget level triggers rebuilds. Minimize rebuild scope by watching providers in the smallest possible widget, or use `select` to watch only a field: `ref.watch(cartProvider.select((c) => c.itemCount))`.

2. **Not using `const` constructors**: Every widget that doesn't change should use `const`. Without `const`, Flutter has to compare widget trees on every build. Run `flutter analyze` — it flags missing `const` constructors. This is a free performance win.

3. **Platform-specific code in the UI layer**: Never call `Platform.isIOS` in widgets. Use dependency injection or platform-aware providers. This breaks web builds and makes testing hard. Abstract platform behavior behind interfaces and provide platform-specific implementations via Riverpod.

## Related Skills

- `ios-swiftui-expert` — When pure native iOS is preferred
- `react-native-best-practices` — React Native alternative
- `mobile-ci-cd` — Flutter integration test and CI/CD strategies
- `app-store-connect` — Publishing Flutter apps to App Store

## GitNexus Index

```json
{
  "skill": "flutter-development",
  "category": "ios-mobile",
  "triggers": ["flutter", "dart", "cross-platform mobile", "riverpod", "go_router", "flutter ios android"],
  "outputs": ["flutter widget", "riverpod provider", "flutter test", "flutter build"],
  "complexity": "medium",
  "tools": ["flutter", "dart", "riverpod", "go_router", "freezed", "build_runner"]
}
```
