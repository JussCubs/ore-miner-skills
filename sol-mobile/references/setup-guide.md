# React Native + Solana Environment Setup

Complete guide for setting up React Native development environment for Solana Mobile apps.

## Prerequisites

### System Requirements
- **Node.js 18+** (LTS recommended)
- **Java 17** (JDK 17)
- **Android Studio** with Android SDK
- **Android device** with wallet app (Phantom, Solflare, etc.)

### Platform-Specific Setup

#### macOS
```bash
# Install Node via Homebrew
brew install node@18
brew install openjdk@17

# Set JAVA_HOME
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v 17)' >> ~/.zshrc
source ~/.zshrc
```

#### Windows
```bash
# Install via Chocolatey
choco install nodejs-lts
choco install openjdk17

# Set JAVA_HOME in environment variables
setx JAVA_HOME "C:\Program Files\OpenJDK\openjdk-17"
```

#### Linux (Ubuntu/Debian)
```bash
# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install OpenJDK 17
sudo apt install openjdk-17-jdk

# Set JAVA_HOME
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc
source ~/.bashrc
```

## Android Studio Setup

### Installation
1. Download [Android Studio](https://developer.android.com/studio)
2. Install with default settings
3. Open Android Studio → More Actions → SDK Manager

### SDK Configuration
Install these SDK platforms and tools:

**SDK Platforms:**
- Android 14 (API 34) - Target SDK
- Android 6.0 (API 23) - Minimum SDK for MWA

**SDK Tools:**
- Android SDK Build-Tools 34.0.0
- Android Emulator
- Android SDK Platform-Tools
- Intel x86 Emulator Accelerator (HAXM installer)

### Environment Variables
Add to your shell profile (~/.bashrc, ~/.zshrc, etc.):

```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

## Project Creation

### Option 1: Expo (Recommended for Beginners)

```bash
npx create-expo-app@latest MySolanaApp --template
cd MySolanaApp
```

Add development build configuration:

```json
// app.json
{
  "expo": {
    "name": "MySolanaApp",
    "slug": "my-solana-app",
    "version": "1.0.0",
    "orientation": "portrait",
    "icon": "./assets/icon.png",
    "userInterfaceStyle": "light",
    "splash": {
      "image": "./assets/splash.png",
      "resizeMode": "contain",
      "backgroundColor": "#ffffff"
    },
    "assetBundlePatterns": ["**/*"],
    "ios": {
      "supportsTablet": true
    },
    "android": {
      "adaptiveIcon": {
        "foregroundImage": "./assets/adaptive-icon.png",
        "backgroundColor": "#ffffff"
      }
    },
    "web": {
      "favicon": "./assets/favicon.png"
    },
    "plugins": [
      [
        "expo-build-properties",
        {
          "android": {
            "minSdkVersion": 23,
            "targetSdkVersion": 34,
            "compileSdkVersion": 34
          }
        }
      ]
    ]
  }
}
```

### Option 2: Bare React Native

```bash
npx react-native@latest init MySolanaApp --version 0.73.0
cd MySolanaApp
```

Configure Android settings:

```gradle
// android/app/build.gradle
android {
    compileSdkVersion 34

    defaultConfig {
        applicationId "com.mysolanaapp"
        minSdkVersion 23
        targetSdkVersion 34
        versionCode 1
        versionName "1.0"
        multiDexEnabled true
    }

    buildTypes {
        release {
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

## Core Dependencies

### Solana Mobile Dependencies

```bash
# Core MWA packages
yarn add @solana-mobile/mobile-wallet-adapter-protocol-web3js
yarn add @solana-mobile/mobile-wallet-adapter-protocol

# Solana Web3 packages
yarn add @solana/web3.js
yarn add @solana/spl-token

# React Native dependencies
yarn add react-native-quick-base64
yarn add react-native-get-random-values
yarn add @react-native-async-storage/async-storage
```

### Polyfill Configuration

Create or update `index.js` (project root):

```javascript
import 'react-native-get-random-values';
import { Buffer } from 'buffer';

global.Buffer = global.Buffer || Buffer;

import { AppRegistry } from 'react-native';
import App from './App';
import { name as appName } from './app.json';

AppRegistry.registerComponent(appName, () => App);
```

### Metro Configuration

Update `metro.config.js`:

```javascript
const { getDefaultConfig } = require('metro-config');

module.exports = (async () => {
  const {
    resolver: { sourceExts, assetExts },
  } = await getDefaultConfig();
  
  return {
    resolver: {
      sourceExts,
      assetExts: [...assetExts, 'bin'],
    },
    transformer: {
      getTransformOptions: async () => ({
        transform: {
          experimentalImportSupport: false,
          inlineRequires: true,
        },
      }),
    },
  };
})();
```

## Expo Development Build Setup

### Create Development Build

```bash
# Install EAS CLI
npm install -g @expo/cli
npm install -g eas-cli

# Configure EAS
eas build:configure

# Build for development
eas build --platform android --profile development
```

### EAS Configuration

Create `eas.json`:

```json
{
  "cli": {
    "version": ">= 3.0.0"
  },
  "build": {
    "development": {
      "developmentClient": true,
      "distribution": "internal",
      "android": {
        "gradleCommand": ":app:assembleDebug"
      }
    },
    "preview": {
      "android": {
        "buildType": "apk"
      }
    },
    "production": {}
  },
  "submit": {
    "production": {}
  }
}
```

## Device Setup

### Android Device Configuration

1. **Enable Developer Options:**
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times
   - Developer options will appear in Settings

2. **Enable USB Debugging:**
   - Settings → Developer Options → USB Debugging

3. **Install Wallet App:**
   - Install Phantom, Solflare, or Backpack from Play Store
   - Create/import a wallet
   - Fund with devnet SOL using [solfaucet.com](https://solfaucet.com)

### Connect Device

```bash
# Check device connection
adb devices

# Should show your device:
# List of devices attached
# ABC123DEF456    device
```

## Running the App

### Expo Development Build

```bash
# Start development server
npx expo start --dev-client

# Scan QR code with Expo Go or development build app
```

### Bare React Native

```bash
# Start Metro bundler
npx react-native start

# In another terminal, install on device
npx react-native run-android
```

## Verification Test

Create a minimal test to verify setup:

```typescript
// App.tsx
import React from 'react';
import { View, Text, Button, Alert } from 'react-native';
import { transact } from '@solana-mobile/mobile-wallet-adapter-protocol-web3js';

const APP_IDENTITY = {
  name: 'Setup Test App',
  uri: 'https://test.com',
  icon: 'favicon.ico',
};

const App = () => {
  const testWalletConnection = async () => {
    try {
      const result = await transact(async (wallet) => {
        return await wallet.authorize({
          identity: APP_IDENTITY,
          chain: 'solana:devnet',
        });
      });
      
      Alert.alert(
        'Success!',
        `Connected to wallet: ${result.accounts[0].address.slice(0, 8)}...`
      );
    } catch (error) {
      Alert.alert('Error', error.message);
    }
  };

  return (
    <View style={{ flex: 1, justifyContent: 'center', padding: 20 }}>
      <Text style={{ fontSize: 24, textAlign: 'center', marginBottom: 30 }}>
        Solana Mobile Setup Test
      </Text>
      
      <Button 
        title="Test Wallet Connection" 
        onPress={testWalletConnection}
      />
      
      <Text style={{ marginTop: 20, textAlign: 'center', color: '#666' }}>
        This should open your wallet app and request authorization.
      </Text>
    </View>
  );
};

export default App;
```

## Common Setup Issues

### Build Failures

**Issue:** `JAVA_HOME not set`
**Solution:** Verify JAVA_HOME points to JDK 17:
```bash
echo $JAVA_HOME
java -version
```

**Issue:** `Android SDK not found`
**Solution:** Set ANDROID_HOME environment variable:
```bash
export ANDROID_HOME=$HOME/Android/Sdk
```

### Runtime Errors

**Issue:** `Buffer is not defined`
**Solution:** Ensure polyfills are imported in index.js:
```javascript
import 'react-native-get-random-values';
import { Buffer } from 'buffer';
global.Buffer = global.Buffer || Buffer;
```

**Issue:** `No MWA wallet found`
**Solution:** 
- Install Phantom/Solflare on device
- Ensure running on real device (not emulator)
- Verify wallet app supports MWA 2.0

### Network Issues

**Issue:** Metro bundler connection failed
**Solution:** Check device and computer are on same network:
```bash
# On device, check Settings → Wi-Fi → Network Details
# Computer IP should match Metro bundler IP
```

**Issue:** RPC connection timeout
**Solution:** Use reliable RPC endpoints:
```typescript
// For devnet
const connection = new Connection('https://api.devnet.solana.com', 'confirmed');

// For mainnet (production)
const connection = new Connection('https://solana-api.projectserum.com', 'confirmed');
```

## Next Steps

Once your environment is set up:

1. **Test wallet connection** with the verification app
2. **Add AuthorizationProvider** for state management
3. **Implement basic transactions** (SOL transfer)
4. **Add token operations** (SPL tokens, NFTs)
5. **Build production features** for your specific use case

Your Solana Mobile development environment is now ready for building production dApps!