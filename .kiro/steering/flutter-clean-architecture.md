# Flutter Clean Architecture Standard

This document defines the standard architecture, patterns, and best practices for Flutter projects. Follow these guidelines to maintain consistency across all repositories.

## Project Structure

```
lib/
├── core/                    # Shared utilities across features
│   ├── config/              # App configurations (env, ads, pro features)
│   ├── providers/           # Riverpod service providers
│   ├── services/            # Singleton services (audio, subscription, etc.)
│   ├── theme/               # App theme definitions
│   └── utils/               # Helper functions, error handlers
├── data/                    # Data layer
│   ├── datasources/         # Remote/local data sources
│   ├── models/              # Data models (JSON serialization)
│   └── repositories/        # Repository implementations
├── domain/                  # Domain layer (business logic)
│   ├── entities/            # Business entities (pure Dart classes)
│   └── repositories/        # Repository interfaces (abstract classes)
├── features/                # Feature modules
│   └── {feature_name}/
│       └── presentation/
│           ├── pages/       # Screen widgets
│           └── providers/   # Feature-specific state management
└── main.dart                # App entry point
```

## Architecture Layers

### 1. Domain Layer (Innermost)
- Contains business entities and repository interfaces
- No dependencies on external packages
- Pure Dart classes with `copyWith` methods for immutability

```dart
// domain/entities/user.dart
class User {
  final int id;
  final String name;
  
  const User({required this.id, required this.name});
  
  User copyWith({int? id, String? name}) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }
}

// domain/repositories/user_repository.dart
abstract class UserRepository {
  Future<List<User>> getAll();
  Future<User?> getById(int id);
}
```

### 2. Data Layer
- Implements repository interfaces
- Handles data sources (API, local storage)
- Maps data models to domain entities

```dart
// data/repositories/user_repository_impl.dart
class UserRepositoryImpl implements UserRepository {
  final UserRemoteDataSource remoteDataSource;
  
  UserRepositoryImpl({required this.remoteDataSource});
  
  @override
  Future<List<User>> getAll() async {
    final response = await remoteDataSource.fetchUsers();
    return response.map((m) => m.toEntity()).toList();
  }
}
```

### 3. Presentation Layer
- UI components and state management
- Uses Riverpod for state management
- Feature-based organization

## State Management with Riverpod

### Provider Types
```dart
// Service providers (singletons)
final audioServiceProvider = Provider<AudioService>((ref) {
  return AudioService();
});

// State providers (simple reactive state)
final isProProvider = StateProvider<bool>((ref) {
  return ref.watch(subscriptionServiceProvider).isPro;
});

// StateNotifier providers (complex state)
final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(ref);
});

// Stream providers (reactive streams)
final proStatusProvider = StreamProvider<bool>((ref) async* {
  final service = ref.watch(subscriptionServiceProvider);
  await for (final status in service.proStatusStream) {
    yield status;
  }
});
```

### StateNotifier Pattern
```dart
class FeatureState {
  final List<Item> items;
  final bool isLoading;
  final String? error;
  
  const FeatureState({
    this.items = const [],
    this.isLoading = true,
    this.error,
  });
  
  FeatureState copyWith({...}) => FeatureState(...);
}

class FeatureNotifier extends StateNotifier<FeatureState> {
  final Ref _ref;
  
  FeatureNotifier(this._ref) : super(const FeatureState()) {
    loadData();
  }
  
  Future<void> loadData({bool showLoading = true}) async {
    if (showLoading) {
      state = state.copyWith(isLoading: true, error: null);
    }
    
    try {
      final data = await _ref.read(repositoryProvider).getAll();
      state = state.copyWith(items: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
```

## Service Patterns

### Singleton Service
```dart
class MyService {
  static final MyService _instance = MyService._internal();
  factory MyService() => _instance;
  MyService._internal();
  
  bool _isInitialized = false;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    // initialization logic
    _isInitialized = true;
  }
}
```

### Async Callback with Completer
```dart
Completer<void>? _completer;

Future<void> waitForCallback() async {
  _completer = Completer<void>();
  
  // Trigger async operation that will call callback
  await triggerOperation();
  
  try {
    await _completer!.future.timeout(const Duration(seconds: 3));
    // Callback received
  } catch (_) {
    // Timeout - handle accordingly
  } finally {
    _completer = null;
  }
}

void onCallback() {
  if (_completer != null && !_completer!.isCompleted) {
    _completer!.complete();
  }
}
```

### Stream Broadcasting
```dart
final _controller = StreamController<bool>.broadcast();
Stream<bool> get statusStream => _controller.stream;

void updateStatus(bool value) {
  _controller.add(value);
}

void dispose() {
  _controller.close();
}
```

## Async Best Practices

### Parallel Execution with Future.wait
```dart
// BAD - Sequential execution
for (final item in items) {
  await processItem(item);
}

// GOOD - Parallel execution
final futures = items.map((item) => processItem(item));
await Future.wait(futures);
```

### Avoid Race Conditions
```dart
// Use flags to prevent duplicate operations
bool _isProcessing = false;

Future<void> process() async {
  if (_isProcessing) return;
  _isProcessing = true;
  
  try {
    await doWork();
  } finally {
    _isProcessing = false;
  }
}
```

## Configuration Management

### Environment Config
```dart
// core/config/app_config.dart
class AppConfig {
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  
  // Feature flags
  static bool forceProEnabled = false;  // Set false for production
  static const bool useTestAds = false; // Set false for production
}
```

### Sensitive Data
- Never commit API keys, secrets to git
- Use `.env` files with `flutter_dotenv`
- Add sensitive files to `.gitignore`:
  ```
  .env
  android/app/google-services.json
  ios/Runner/GoogleService-Info.plist
  *.jks
  *.keystore
  key.properties
  ```

## UI Patterns

### Loading States
```dart
@override
Widget build(BuildContext context) {
  final state = ref.watch(featureProvider);
  
  if (state.isLoading) {
    return _buildLoadingState();
  }
  
  if (state.error != null) {
    return _buildErrorState(state.error!);
  }
  
  return _buildContent(state);
}
```

### Pull-to-Refresh
```dart
RefreshIndicator(
  onRefresh: () => ref.read(provider.notifier).loadData(showLoading: false),
  child: ListView(...),
)
```
- Pass `showLoading: false` to avoid replacing entire UI
- Let `RefreshIndicator` handle the loading indicator

### Dialog without Underline Text
```dart
showDialog(
  context: context,
  builder: (context) => Material(
    color: Colors.transparent,
    child: YourDialogContent(),
  ),
);
```

## Data Persistence

### SharedPreferences Pattern
```dart
class StorageKeys {
  static const String isDarkMode = 'is_dark_mode';
  static const String subscriptionType = 'subscription_type';
}

Future<void> saveValue(String key, dynamic value) async {
  final prefs = await SharedPreferences.getInstance();
  if (value is bool) {
    await prefs.setBool(key, value);
  } else if (value is int) {
    await prefs.setInt(key, value);
  } else if (value is String) {
    await prefs.setString(key, value);
  }
}
```

## In-App Purchase

### Subscription Service Pattern
```dart
enum SubscriptionType { none, monthly, annual, lifetime }

class SubscriptionService {
  SubscriptionType _currentSubscription = SubscriptionType.none;
  
  bool get isPro => 
    AppConfig.forceProEnabled || 
    _currentSubscription != SubscriptionType.none;
  
  Future<void> restorePurchases() async {
    // Use Completer pattern for callback-based APIs
    // Clear subscription first, restore if valid
    // Timeout after 3 seconds if no callback
  }
}
```

## Error Handling

```dart
// core/utils/error_handler.dart
class ErrorHandler {
  static String getUserFriendlyMessage(dynamic error) {
    if (error is SocketException) {
      return 'No internet connection';
    }
    if (error is TimeoutException) {
      return 'Request timed out';
    }
    return 'Something went wrong';
  }
}
```

## Testing Considerations

### Debug-only Features
```dart
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  // Debug-only code
}
```

### Remove Before Production
- All `debugPrint` and `print` statements
- Test API keys and URLs
- Force-enabled features (`forceProEnabled = false`)

## File Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | snake_case | `user_repository.dart` |
| Classes | PascalCase | `UserRepository` |
| Variables | camelCase | `currentUser` |
| Constants | camelCase | `maxRetries` |
| Providers | camelCase + Provider | `userProvider` |

## Dependencies (Recommended)

```yaml
dependencies:
  # State Management
  flutter_riverpod: ^2.6.1
  
  # HTTP
  http: ^1.4.0
  
  # Local Storage
  shared_preferences: ^2.5.3
  path_provider: ^2.1.5
  
  # Environment
  flutter_dotenv: ^5.2.1
  
  # Firebase (optional)
  firebase_core: ^3.15.2
  firebase_analytics: ^11.6.0
  firebase_crashlytics: ^4.3.10
  
  # Monetization (optional)
  google_mobile_ads: ^5.3.1
  in_app_purchase: ^3.2.0
```

## Checklist Before Release

- [ ] `forceProEnabled = false`
- [ ] `useTestAds = false`
- [ ] No `debugPrint` or `print` statements
- [ ] Sensitive files in `.gitignore`
- [ ] API keys not committed
- [ ] `flutter analyze` passes
- [ ] Version number updated in `pubspec.yaml`
