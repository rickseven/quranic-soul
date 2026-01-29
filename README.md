# Quranic Soul

A Flutter app for soothing Quran recitations designed to foster inner peace, stress relief, and better sleep.

## Architecture

Clean Architecture + Riverpod state management.

```
lib/
├── core/
│   ├── config/         # App configurations (AdMob, env, pro)
│   ├── providers/      # Riverpod service providers
│   ├── services/       # Singleton services (audio, download, ads)
│   └── theme/          # App theme
├── data/
│   ├── datasources/    # Remote data sources
│   ├── models/         # Data models
│   └── repositories/   # Repository implementations
├── domain/
│   ├── entities/       # Business entities
│   └── repositories/   # Repository interfaces
├── features/
│   ├── home/           # Home page + provider
│   ├── favorite/       # Library page + provider
│   ├── player/         # Player page + provider
│   ├── settings/       # Settings page
│   ├── main_navigation/
│   ├── splash/
│   └── subscription/
└── main.dart
```

## Quick Start

```bash
# 1. Setup environment
cp .env.example .env

# 2. Install dependencies
flutter pub get

# 3. Run
flutter run
```

## Environment Variables

Edit `.env`:
```
QURAN_AUDIO_BASE_URL=https://rickseven.github.io/quran-audio
```

## Features

- Streaming audio dengan background playback
- Full-featured audio player (play/pause, skip, repeat, speed control)
- Sleep timer & sound effects
- Favorites & downloads (PRO)
- Dark/Light theme
- AdMob integration
- In-app purchase (PRO subscription)
- Firebase Analytics & Crashlytics

## Building for Release

### Setup Keystore (first time)
```bash
cp android/key.properties.example android/key.properties
# Edit dengan keystore details
```

### Build APK
```bash
flutter build apk --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

### Build App Bundle (Play Store)
```bash
flutter build appbundle --release --obfuscate --split-debug-info=build/app/outputs/symbols
```

## Google Play Console Setup

### 1. Create Subscription Products

1. Go to **Google Play Console** → Your App → **Monetize** → **Subscriptions**
2. Click **Create subscription**
3. Fill in the details:

#### Monthly Subscription
- **Product ID**: `quranic_soul_pro_monthly`
- **Name**: Quranic Soul PRO - Monthly
- **Description**: Unlock all premium features
- **Billing period**: 1 month
- **Price**: $0.89 (or equivalent in local currency)
- **Free trial**: Optional (e.g., 7 days)

#### Annual Subscription
- **Product ID**: `quranic_soul_pro_annual`
- **Name**: Quranic Soul PRO - Annual
- **Description**: Unlock all premium features (Save 16%)
- **Billing period**: 1 year
- **Price**: $8.99 (or equivalent in local currency)
- **Free trial**: Optional (e.g., 7 days)

#### Lifetime (One-time Purchase)
- **Product ID**: `quranic_soul_pro_lifetime`
- **Name**: Quranic Soul PRO - Lifetime
- **Description**: Unlock all premium features forever
- **Type**: One-time product (not subscription)
- **Purchase option ID**: `quranic-soul-pro-lifetime` (created after product)
- **Price**: $26.99 (or equivalent in local currency)

4. Click **Save** and **Activate**

### 2. Configure Base Plan (for Subscriptions)

For Monthly and Annual subscriptions:
1. Click **Add base plan**
2. Set **Base plan ID**: `base-plan`
3. Set **Billing period**: Monthly or Yearly
4. Set **Price**: Your chosen price
5. Click **Save**

### 3. Create Lifetime Product (One-time Purchase)

1. Go to **Google Play Console** → Your App → **Monetize** → **One-time products**
2. Click **Create one-time product**
3. Fill in the **Product details** section:
   - **Product ID**: `quranic_soul_pro_lifetime`
   - **Name**: Quranic Soul PRO - Lifetime
   - **Description**: Unlock all premium features forever
4. Click **Create** to create the product
5. Now add **Purchase option**:
   - Click **Add purchase option**
   - **Purchase option ID**: `quranic-soul-pro-lifetime` (use dash, not underscore)
   - **Purchase type**: `Buy`
   - **Tags**: (optional, can leave empty or add "lifetime")
6. Set **Pricing**:
   - Click **Add pricing**
   - Set price: $26.99 (or set for all countries)
   - Click **Apply**
7. Set **Tax and compliance**:
   - **Product tax category**: Digital app sales
   - **Compliance settings**: Service
8. Click **Save** and **Activate**

**Important**: 
- Product ID (step 3) can use underscores
- Purchase option ID (step 5) must use dashes, not underscores
- The Purchase option ID is what you use in your code

### 4. Test Subscription (Optional)

1. Go to **Setup** → **License testing**
2. Add test Gmail accounts
3. These accounts can test subscriptions without being charged

### 5. Important Notes

- Product IDs must match exactly with code in `lib/core/services/subscription_service.dart`
- Subscriptions take ~24 hours to be available after activation
- Test with real Google account before production release
- Make sure app is published (at least in Internal Testing) for subscriptions to work

## App Icon

```bash
flutter pub run flutter_launcher_icons
```

## Color Palette

- Primary: #D4AF37 (Gold)
- Secondary: #B8860B (Dark Gold)
- Background Dark: #121212
- Background Light: #F8F5F1
