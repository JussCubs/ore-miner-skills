# Building APK/AAB and dApp Store Publishing

Complete guide for building production apps and publishing to Solana dApp Store and traditional app stores.

## Production Build Setup

### Android Build Configuration

#### Signing Key Generation

Create a signing key for production releases:

```bash
# Generate keystore
keytool -genkeypair -v -keystore my-app-key.keystore -alias my-app-alias \
  -keyalg RSA -keysize 2048 -validity 10000

# Store keystore securely - you'll need this for all future updates
```

#### Gradle Configuration

Update `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.yourcompany.yourapp"
        minSdkVersion 23
        targetSdkVersion 34
        versionCode 1
        versionName "1.0.0"
        multiDexEnabled true
    }

    signingConfigs {
        release {
            if (project.hasProperty('MYAPP_UPLOAD_STORE_FILE')) {
                storeFile file(MYAPP_UPLOAD_STORE_FILE)
                storePassword MYAPP_UPLOAD_STORE_PASSWORD
                keyAlias MYAPP_UPLOAD_KEY_ALIAS
                keyPassword MYAPP_UPLOAD_KEY_PASSWORD
            }
        }
    }

    buildTypes {
        debug {
            debuggable true
        }
        release {
            minifyEnabled true
            proguardFiles getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro"
            signingConfig signingConfigs.release
        }
    }

    // Enable bundle for Google Play
    bundle {
        language {
            enableSplit = false
        }
        density {
            enableSplit = true
        }
        abi {
            enableSplit = true
        }
    }
}
```

#### Gradle Properties

Create `android/gradle.properties` (add to .gitignore):

```properties
MYAPP_UPLOAD_STORE_FILE=my-app-key.keystore
MYAPP_UPLOAD_KEY_ALIAS=my-app-alias
MYAPP_UPLOAD_STORE_PASSWORD=****
MYAPP_UPLOAD_KEY_PASSWORD=****

# Performance optimizations
org.gradle.jvmargs=-Xmx4096m -XX:MaxPermSize=512m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
org.gradle.parallel=true
org.gradle.configureondemand=true
org.gradle.daemon=true

android.useAndroidX=true
android.enableJetifier=true
```

### ProGuard Configuration

Create/update `android/app/proguard-rules.pro`:

```proguard
# Solana Mobile Wallet Adapter
-keep class com.solanamobile.mobilewalletadapter.** { *; }
-keep interface com.solanamobile.mobilewalletadapter.** { *; }

# Solana Web3.js
-keep class com.solana.** { *; }

# React Native
-keep,allowobfuscation @interface com.facebook.proguard.annotations.DoNotStrip
-keep,allowobfuscation @interface com.facebook.proguard.annotations.KeepGettersAndSetters
-keep,allowobfuscation @interface com.facebook.common.internal.DoNotStrip

# Hermes
-keep class com.facebook.hermes.unicode.** { *; }
-keep class com.facebook.jni.** { *; }

# WebSocket (for MWA)
-keepclassmembers class * extends java.lang.Enum {
    <fields>;
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# JSON parsing
-keepattributes *Annotation*
-keepclassmembers class ** {
    @com.fasterxml.jackson.annotation.JsonCreator <init>(...);
    @com.fasterxml.jackson.annotation.JsonProperty <fields>;
}
```

### Environment Configuration

#### Development vs Production

Create environment-specific configurations:

```typescript
// src/config/environment.ts
interface AppConfig {
  apiEndpoint: string;
  solanaNetwork: 'devnet' | 'mainnet-beta';
  isDevelopment: boolean;
}

const development: AppConfig = {
  apiEndpoint: 'https://api.devnet.solana.com',
  solanaNetwork: 'devnet',
  isDevelopment: true,
};

const production: AppConfig = {
  apiEndpoint: 'https://solana-api.projectserum.com',
  solanaNetwork: 'mainnet-beta',
  isDevelopment: false,
};

export const CONFIG = __DEV__ ? development : production;
```

#### App Identity for Production

```typescript
// src/config/app-identity.ts
export const APP_IDENTITY = {
  name: 'Your App Name',
  uri: 'https://yourdomain.com',
  icon: 'favicon.ico',
};

// Verify this matches your actual domain and app store listing
```

## Building Release Packages

### APK Build (Solana dApp Store)

```bash
# Navigate to android directory
cd android

# Clean previous builds
./gradlew clean

# Build release APK
./gradlew assembleRelease

# APK location: android/app/build/outputs/apk/release/app-release.apk
```

### AAB Build (Google Play Store)

```bash
# Build Android App Bundle
./gradlew bundleRelease

# AAB location: android/app/build/outputs/bundle/release/app-release.aab
```

### Expo EAS Build

For Expo projects:

```bash
# Install EAS CLI
npm install -g eas-cli

# Configure EAS
eas build:configure

# Build for production
eas build --platform android --profile production
```

EAS build configuration (`eas.json`):

```json
{
  "cli": {
    "version": ">= 3.0.0"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal"
    },
    "preview": {
      "android": {
        "buildType": "apk"
      }
    },
    "production": {
      "android": {
        "buildType": "aab"
      }
    }
  },
  "submit": {
    "production": {}
  }
}
```

## Solana dApp Store Submission

### dApp Store Requirements

**Technical Requirements:**
- Android APK (not AAB)
- Minimum API 23 (Android 6.0)
- Must integrate Mobile Wallet Adapter
- Must be a functional Solana application
- Proper error handling and user feedback

**Content Requirements:**
- Clear app description
- Screenshots (at least 3)
- App icon (512x512 PNG)
- Privacy policy URL
- Support/contact information

### Submission Process

1. **Prepare Assets**

```bash
# Create required assets directory
mkdir -p assets/store
cd assets/store

# App icon (512x512)
# Screenshots (16:9 or 9:16 aspect ratio)
# Feature graphic (1024x500, optional)
```

2. **Test APK Thoroughly**

```typescript
// Pre-submission testing checklist
const testChecklist = {
  walletConnection: 'Can connect to Phantom, Solflare, Backpack',
  transactions: 'Can send SOL and SPL tokens',
  errorHandling: 'Graceful error messages',
  permissions: 'Only necessary permissions requested',
  orientation: 'Works in portrait and landscape',
  performance: 'No crashes, smooth UX',
  network: 'Handles network failures gracefully'
};
```

3. **Submit to Solana dApp Store**

Visit [dApp Store Publisher Portal](https://dapp-store.solanamobile.com/publish):

```bash
# Required information for submission:
- App name and description
- Category (DeFi, Gaming, NFT, etc.)
- APK file
- Screenshots
- App icon
- Privacy policy URL
- Website URL
- Contact email
```

### dApp Store Guidelines

**User Experience:**
- Wallet connection should be prominent and easy
- Clear indication when transactions are in progress
- Meaningful error messages for failed transactions
- Offline mode handling (where applicable)

**Security:**
- Never request private keys or seed phrases
- Use MWA for all signing operations
- Validate all user inputs
- Secure API endpoints

**Performance:**
- App launch time < 3 seconds
- Wallet connection time < 5 seconds
- Smooth scrolling and animations
- Proper loading states

```typescript
// Example: Good UX patterns
const WalletConnectButton = () => {
  const [connecting, setConnecting] = useState(false);
  const { authorize } = useAuthorization();

  const handleConnect = async () => {
    setConnecting(true);
    try {
      await authorize();
    } catch (error) {
      if (error.message.includes('User declined')) {
        Alert.alert('Connection Cancelled', 'You declined the wallet connection.');
      } else {
        Alert.alert('Connection Failed', 'Please ensure you have a compatible wallet installed.');
      }
    } finally {
      setConnecting(false);
    }
  };

  return (
    <TouchableOpacity 
      onPress={handleConnect}
      disabled={connecting}
      style={styles.connectButton}
    >
      {connecting ? (
        <ActivityIndicator color="white" />
      ) : (
        <Text style={styles.buttonText}>Connect Wallet</Text>
      )}
    </TouchableOpacity>
  );
};
```

## Google Play Store Submission

### Play Console Setup

1. **Create Developer Account**
   - Pay $25 registration fee
   - Verify identity and contact information

2. **Create App Listing**

```javascript
// App store listing information
const playStoreListing = {
  title: "Your App Name (max 50 characters)",
  shortDescription: "Brief description (max 80 characters)",
  fullDescription: `
    Detailed app description explaining:
    - What your app does
    - Key features
    - How to use it
    - Solana/crypto functionality
    - Why users should download it
    
    Keywords: Solana, DeFi, Crypto, Blockchain, Mobile Wallet
  `,
  category: "Finance", // or appropriate category
  contentRating: "Everyone", // or appropriate rating
  targetAudience: "Primary: 18-34 years old",
};
```

3. **Prepare Store Assets**

```bash
# Required Play Store assets:
- High-res icon: 512 x 512 PNG
- Feature graphic: 1024 x 500 JPG/PNG
- Screenshots: 
  - Phone: 16:9 or 9:16 ratio, 320dp min width
  - Tablet: 16:10 or 10:16 ratio, 600dp min width
- Privacy policy URL (required for apps with sensitive permissions)
```

### Play Store Policies for Crypto Apps

**Important Considerations:**

1. **Financial Services Policy**
   - Clearly disclose crypto/blockchain functionality
   - Include risk warnings
   - Provide proper disclaimers

2. **Permitted Content**
   - Educational crypto content ✅
   - Wallet functionality ✅
   - DeFi applications ✅
   - NFT marketplaces ✅

3. **Prohibited Content**
   - Crypto mining ❌
   - ICO promotion ❌
   - Misleading financial advice ❌

### Play Store Submission

```bash
# Upload AAB to Play Console
# 1. Go to Play Console
# 2. Select your app
# 3. Go to "Production" release
# 4. Upload AAB file
# 5. Fill out release notes
# 6. Submit for review
```

**Release Notes Template:**

```
Version 1.0.0
- Initial release
- Connect to Solana mobile wallets
- Send and receive SOL and SPL tokens
- View transaction history
- Secure transaction signing via Mobile Wallet Adapter

This app requires a compatible Solana mobile wallet (Phantom, Solflare, or Backpack).
```

## App Store Optimization (ASO)

### Keyword Strategy

```javascript
const asoKeywords = {
  primary: ['Solana', 'crypto', 'blockchain', 'DeFi'],
  secondary: ['wallet', 'tokens', 'NFT', 'Web3'],
  long_tail: [
    'Solana mobile wallet',
    'crypto portfolio tracker',
    'DeFi mobile app',
    'NFT collection viewer'
  ]
};
```

### Screenshots Best Practices

```typescript
// Screenshot content ideas
const screenshotPlans = [
  {
    screen: 'Wallet Connection',
    caption: 'Connect Securely with Mobile Wallet Adapter'
  },
  {
    screen: 'Portfolio View',
    caption: 'Track Your Solana Tokens and NFTs'
  },
  {
    screen: 'Send Transaction',
    caption: 'Send SOL and SPL Tokens Easily'
  },
  {
    screen: 'Transaction History',
    caption: 'View Complete Transaction History'
  },
  {
    screen: 'Settings/Security',
    caption: 'Secure and User-Friendly Design'
  }
];
```

## App Updates and Maintenance

### Version Management

```gradle
// android/app/build.gradle
android {
    defaultConfig {
        versionCode 2    // Increment for each release
        versionName "1.1.0"  // Semantic versioning
    }
}
```

### Update Strategy

```typescript
// In-app update handling
const checkForUpdates = async () => {
  try {
    // Check current version against server
    const currentVersion = DeviceInfo.getVersion();
    const latestVersion = await fetchLatestVersion();
    
    if (shouldUpdate(currentVersion, latestVersion)) {
      showUpdateDialog(latestVersion);
    }
  } catch (error) {
    console.log('Update check failed:', error);
  }
};
```

### Release Notes Template

```markdown
## Version 1.1.0

### New Features
- Added support for NFT viewing
- Improved transaction speed
- New token swap functionality

### Improvements
- Better error handling for failed transactions
- Improved wallet connection reliability
- Updated UI for better accessibility

### Bug Fixes
- Fixed crash when switching between wallets
- Resolved issue with large token transfers
- Fixed display issues on older Android devices
```

## Monitoring and Analytics

### Crash Reporting

```bash
# Add crash reporting
yarn add @bugsnag/react-native
# or
yarn add @sentry/react-native
```

```typescript
// Initialize crash reporting
import Bugsnag from '@bugsnag/react-native';

Bugsnag.start();

// Log MWA errors
const logMWAError = (error: any, context: string) => {
  Bugsnag.leaveBreadcrumb(`MWA Error: ${context}`);
  Bugsnag.notify(error, event => {
    event.context = context;
    event.addMetadata('mwa', {
      walletConnected: !!selectedAccount,
      network: CONFIG.solanaNetwork,
    });
  });
};
```

### Usage Analytics

```typescript
// Track key events
const analytics = {
  walletConnected: (walletType: string) => {
    // Track successful wallet connections
  },
  
  transactionSent: (type: 'SOL' | 'SPL' | 'NFT', amount?: number) => {
    // Track transaction types and volumes
  },
  
  errorOccurred: (errorType: string, screen: string) => {
    // Track where errors happen most
  }
};
```

## Distribution Strategy

### Multi-Store Distribution

```typescript
// Store-specific configurations
const storeConfig = {
  'solana-dapp-store': {
    buildType: 'apk',
    features: ['mwa-native', 'solana-optimized'],
  },
  'google-play': {
    buildType: 'aab',
    features: ['play-billing', 'play-services'],
  },
  'samsung-galaxy': {
    buildType: 'apk',
    features: ['samsung-knox', 'samsung-pay'],
  }
};
```

### Marketing Considerations

1. **Target Audience**
   - Crypto enthusiasts
   - Solana ecosystem users
   - Mobile-first users
   - DeFi participants

2. **Marketing Channels**
   - Solana community forums
   - Crypto Twitter
   - DeFi Discord servers
   - Mobile crypto groups

3. **Launch Strategy**
   - Beta test with community
   - Influencer partnerships
   - Educational content
   - Community rewards

This completes the comprehensive publishing guide. Following these steps will ensure your Solana mobile app meets all requirements for successful distribution across multiple app stores.