---
name: sol-mobile
description: Build production Solana mobile apps with React Native. Setup, Mobile Wallet Adapter, transactions, tokens, NFTs, and dApp Store publishing.
metadata: {"openclaw":{"requires":{"bins":["npx","node"]}}}
---

# Sol Mobile — Solana Mobile Development

You are an expert Solana mobile developer who builds production-ready React Native apps that connect to Solana wallets and interact with the blockchain.

## What You Build

Native mobile dApps for Android (and iOS) using React Native that:
- Connect securely to mobile wallets via Mobile Wallet Adapter (MWA)
- Send transactions, transfer tokens, mint NFTs, interact with programs
- Work with both Expo and bare React Native workflows
- Deploy to Solana dApp Store and traditional app stores

## Core Architecture

**Mobile Wallet Adapter (MWA)** is the foundation. Unlike web wallets that inject into browser context, mobile wallets run as separate, isolated apps. MWA creates encrypted communication channels between your dApp and wallet apps.

### Key Differences from Web

| Web Wallets | Mobile Wallets (MWA) |
|-------------|---------------------|
| Persistent connection | Session-based |
| Browser extensions | Standalone apps |
| Direct function calls | Inter-app messaging |
| Connect once → sign many | Open session → authorize → sign → close |

### Session Lifecycle

Every wallet interaction follows this pattern:

```typescript
import { transact } from '@solana-mobile/mobile-wallet-adapter-protocol-web3js';

await transact(async (wallet) => {
  // 1. SESSION OPENS - wallet app comes to foreground
  
  // 2. AUTHORIZE - get user approval + accounts
  const { accounts, auth_token } = await wallet.authorize({
    identity: APP_IDENTITY,
    chain: 'solana:devnet',
  });

  // 3. SIGN/SEND - perform operations
  const signatures = await wallet.signAndSendTransactions({
    transactions: [transaction],
  });

  // 4. SESSION CLOSES - automatically when callback ends
});
```

## Environment Setup

### Dependencies

Add the core MWA packages:

```bash
yarn add @solana-mobile/mobile-wallet-adapter-protocol-web3js \
         @solana-mobile/mobile-wallet-adapter-protocol \
         @solana/web3.js \
         react-native-quick-base64
```

### React Native Polyfills

Mobile environments lack browser APIs. Add these polyfills to your `index.js` (before App import):

```javascript
import 'react-native-get-random-values';
import { Buffer } from 'buffer';

global.Buffer = global.Buffer || Buffer;
```

### Expo Configuration

For Expo projects, you need a custom development build:

```json
// app.json
{
  "expo": {
    "plugins": [
      [
        "expo-build-properties",
        {
          "android": {
            "minSdkVersion": 23
          }
        }
      ]
    ]
  }
}
```

### Bare React Native Setup

Add to `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34
    defaultConfig {
        minSdkVersion 23
        targetSdkVersion 34
    }
}
```

## App Identity

Every dApp must define its identity for wallet display:

```typescript
export const APP_IDENTITY = {
  name: 'MyDApp',
  uri: 'https://mydapp.com',
  icon: 'favicon.ico', // Relative to uri
};
```

Wallets show this to users during authorization. On Android, wallets can cryptographically verify the requesting app matches this identity.

## Authorization Patterns

### First-Time Connection

```typescript
const authorizeWallet = async () => {
  const authResult = await transact(async (wallet) => {
    return await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet', // or 'solana:mainnet-beta'
    });
  });
  
  // Store for silent re-auth
  await AsyncStorage.setItem('auth_token', authResult.auth_token);
  
  return authResult.accounts[0].address;
};
```

### Silent Re-Authorization

```typescript
const connectWithToken = async () => {
  const savedToken = await AsyncStorage.getItem('auth_token');
  
  return await transact(async (wallet) => {
    return await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
      auth_token: savedToken || undefined, // Skip prompt if valid
    });
  });
};
```

### Deauthorization

```typescript
const disconnectWallet = async () => {
  const savedToken = await AsyncStorage.getItem('auth_token');
  
  await transact(async (wallet) => {
    await wallet.deauthorize({
      auth_token: savedToken,
    });
  });
  
  await AsyncStorage.removeItem('auth_token');
};
```

## Transaction Operations

### Sign and Send (Recommended)

Wallet handles both signing and network submission:

```typescript
const sendTransaction = async (instruction) => {
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const fromPubkey = new PublicKey(toByteArray(accounts[0].address));
    
    // Build transaction
    const txMessage = new TransactionMessage({
      payerKey: fromPubkey,
      recentBlockhash: (await connection.getLatestBlockhash()).blockhash,
      instructions: [instruction],
    }).compileToV0Message();

    const transaction = new VersionedTransaction(txMessage);

    // Wallet signs and submits
    const signatures = await wallet.signAndSendTransactions({
      transactions: [transaction],
    });

    return signatures[0];
  });
};
```

### Sign Only

For custom submission logic:

```typescript
const signTransaction = async (transaction) => {
  return await transact(async (wallet) => {
    await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const signedTxs = await wallet.signTransactions({
      transactions: [transaction],
    });

    return signedTxs[0];
  });
};

// Submit yourself
const signedTx = await signTransaction(transaction);
await connection.sendTransaction(signedTx);
```

## Token Operations

### SOL Transfer

```typescript
import { SystemProgram, LAMPORTS_PER_SOL } from '@solana/web3.js';

const transferSOL = async (toPubkey, amount) => {
  const instruction = SystemProgram.transfer({
    fromPubkey: authorizedPubkey,
    toPubkey,
    lamports: amount * LAMPORTS_PER_SOL,
  });

  return await sendTransaction(instruction);
};
```

### SPL Token Transfer

```typescript
import { getAssociatedTokenAddress, createTransferInstruction } from '@solana/spl-token';

const transferToken = async (mintAddress, toPubkey, amount, decimals) => {
  const fromTokenAccount = await getAssociatedTokenAddress(
    new PublicKey(mintAddress),
    authorizedPubkey
  );
  
  const toTokenAccount = await getAssociatedTokenAddress(
    new PublicKey(mintAddress),
    new PublicKey(toPubkey)
  );

  const instruction = createTransferInstruction(
    fromTokenAccount,
    toTokenAccount,
    authorizedPubkey,
    amount * (10 ** decimals)
  );

  return await sendTransaction(instruction);
};
```

### Get Token Balance

```typescript
const getTokenBalance = async (mintAddress, ownerAddress) => {
  const tokenAccount = await getAssociatedTokenAddress(
    new PublicKey(mintAddress),
    new PublicKey(ownerAddress)
  );

  try {
    const balance = await connection.getTokenAccountBalance(tokenAccount);
    return balance.value.uiAmount;
  } catch (error) {
    return 0; // Account doesn't exist
  }
};
```

## Message Signing

### Sign Arbitrary Messages

```typescript
const signMessage = async (message) => {
  const messageBuffer = new Uint8Array(
    message.split('').map(c => c.charCodeAt(0))
  );

  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const signedMessages = await wallet.signMessages({
      addresses: [accounts[0].address],
      payloads: [messageBuffer],
    });

    return signedMessages[0];
  });
};
```

### Sign in with Solana (SIWS)

```typescript
const signInWithSolana = async () => {
  return await transact(async (wallet) => {
    const authResult = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
      sign_in_payload: {
        domain: 'mydapp.com',
        statement: 'Sign in to MyDApp',
        uri: 'https://mydapp.com',
      },
    });

    return authResult.sign_in_result;
  });
};

// Verify the signature
import { verifySignIn } from '@solana/wallet-standard-util';

const isValid = verifySignIn(input, signInResult);
```

## State Management

### Authorization Provider

Create a context for wallet state:

```typescript
// contexts/AuthorizationProvider.tsx
import React, { createContext, useContext, useState } from 'react';

interface AuthContextType {
  selectedAccount: string | null;
  isAuthorized: boolean;
  authorize: () => Promise<void>;
  deauthorize: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export const AuthorizationProvider = ({ children }) => {
  const [selectedAccount, setSelectedAccount] = useState<string | null>(null);
  
  const authorize = async () => {
    try {
      const authResult = await transact(async (wallet) => {
        return await wallet.authorize({
          identity: APP_IDENTITY,
          chain: 'solana:devnet',
        });
      });
      
      setSelectedAccount(authResult.accounts[0].address);
      await AsyncStorage.setItem('auth_token', authResult.auth_token);
    } catch (error) {
      console.error('Authorization failed:', error);
    }
  };

  const deauthorize = async () => {
    const savedToken = await AsyncStorage.getItem('auth_token');
    
    await transact(async (wallet) => {
      await wallet.deauthorize({ auth_token: savedToken });
    });
    
    setSelectedAccount(null);
    await AsyncStorage.removeItem('auth_token');
  };

  return (
    <AuthContext.Provider value={{
      selectedAccount,
      isAuthorized: !!selectedAccount,
      authorize,
      deauthorize,
    }}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuthorization = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuthorization must be used within AuthorizationProvider');
  }
  return context;
};
```

### Usage in Components

```typescript
const WalletScreen = () => {
  const { selectedAccount, isAuthorized, authorize, deauthorize } = useAuthorization();

  if (!isAuthorized) {
    return (
      <View style={styles.container}>
        <Button title="Connect Wallet" onPress={authorize} />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text>Connected: {selectedAccount}</Text>
      <Button title="Disconnect" onPress={deauthorize} />
    </View>
  );
};
```

## Error Handling

### Common Errors and Solutions

```typescript
const handleTransactionError = async (operation) => {
  try {
    return await operation();
  } catch (error) {
    if (error instanceof Error) {
      switch (true) {
        case error.message.includes('User declined'):
          Alert.alert('Transaction Cancelled', 'You declined the transaction.');
          break;
          
        case error.message.includes('Insufficient funds'):
          Alert.alert('Insufficient Funds', 'Not enough SOL for this transaction.');
          break;
          
        case error.message.includes('Blockhash not found'):
          Alert.alert('Network Error', 'Transaction expired. Please try again.');
          break;
          
        default:
          Alert.alert('Transaction Failed', error.message);
      }
    }
    throw error;
  }
};
```

### Retry Logic

```typescript
const withRetry = async (operation, maxRetries = 3) => {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await operation();
    } catch (error) {
      if (i === maxRetries - 1) throw error;
      await new Promise(resolve => setTimeout(resolve, 1000 * (i + 1)));
    }
  }
};
```

## Testing and Development

### Testing on Device

MWA requires a real Android device with a Solana wallet installed. Popular options:
- **Phantom Mobile** (most widely used)
- **Solflare Mobile**
- **Backpack** (xNFT support)

### Development Workflow

1. **Install wallet app** on test device
2. **Enable USB debugging** on Android
3. **Run dev build** on device: `npx react-native run-android`
4. **Test wallet interactions** with real wallet app

### Debugging Tips

```typescript
// Add extensive logging
await transact(async (wallet) => {
  console.log('Starting wallet session');
  
  const authResult = await wallet.authorize({
    identity: APP_IDENTITY,
    chain: 'solana:devnet',
  });
  
  console.log('Authorized accounts:', authResult.accounts);
  console.log('Auth token received:', !!authResult.auth_token);
  
  // ... rest of operations
});

// Monitor network calls
const connection = new Connection(
  clusterApiUrl('devnet'),
  'confirmed',
  {
    commitment: 'confirmed',
    disableRetryOnRateLimit: false,
  }
);
```

## Building for Production

### Android Build

```bash
# Generate signed APK
cd android
./gradlew assembleRelease

# Generate AAB (preferred)
./gradlew bundleRelease
```

### iOS Build (if supported)

```bash
# iOS builds require Xcode
npx react-native run-ios --configuration Release
```

### Solana dApp Store Submission

1. **Build signed APK/AAB** with proper signing keys
2. **Submit to Solana dApp Store** via [publisher portal](https://dapp-store.solanamobile.com/)
3. **Follow guidelines** for Solana app requirements
4. **Include wallet connection** prominently in app flow

### Traditional App Store Submission

- **Google Play Store**: Standard Android app submission
- **Apple App Store**: Follow standard iOS guidelines

## Program Interactions

### Anchor Program Calls

```typescript
import * as anchor from '@project-serum/anchor';

const callProgram = async (programId, instruction) => {
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const provider = new anchor.AnchorProvider(
      connection,
      {
        publicKey: new PublicKey(toByteArray(accounts[0].address)),
        signTransaction: async (tx) => {
          const signed = await wallet.signTransactions({
            transactions: [tx],
          });
          return signed[0];
        },
        signAllTransactions: async (txs) => {
          return await wallet.signTransactions({
            transactions: txs,
          });
        },
      },
      { commitment: 'confirmed' }
    );

    const program = new anchor.Program(idl, programId, provider);
    return await program.methods[instruction]().rpc();
  });
};
```

## Performance Optimization

### Connection Caching

```typescript
// Singleton connection instance
class SolanaConnection {
  private static instance: Connection;

  static getInstance() {
    if (!this.instance) {
      this.instance = new Connection(
        clusterApiUrl('devnet'),
        'confirmed'
      );
    }
    return this.instance;
  }
}
```

### Batch Transactions

```typescript
const sendBatchTransactions = async (instructions) => {
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const transactions = instructions.map(ix => {
      const txMessage = new TransactionMessage({
        payerKey: new PublicKey(toByteArray(accounts[0].address)),
        recentBlockhash: latestBlockhash.blockhash,
        instructions: [ix],
      }).compileToV0Message();

      return new VersionedTransaction(txMessage);
    });

    return await wallet.signAndSendTransactions({
      transactions,
    });
  });
};
```

## Security Best Practices

### Validate All Inputs

```typescript
const validateAddress = (address: string): boolean => {
  try {
    new PublicKey(address);
    return true;
  } catch {
    return false;
  }
};
```

### Use Versioned Transactions

```typescript
// Preferred: Versioned transactions with address lookup tables
const buildVersionedTransaction = async (instructions) => {
  const txMessage = new TransactionMessage({
    payerKey: authorizedPubkey,
    recentBlockhash: latestBlockhash.blockhash,
    instructions,
  }).compileToV0Message();

  return new VersionedTransaction(txMessage);
};
```

### Environment-Specific Configuration

```typescript
const getCluster = () => {
  return __DEV__ ? 'devnet' : 'mainnet-beta';
};

const getRPCEndpoint = () => {
  return __DEV__ 
    ? clusterApiUrl('devnet')
    : 'https://your-mainnet-rpc.com';
};
```

## Advanced Features

### Multiple Wallet Support

```typescript
const getAvailableWallets = async () => {
  // MWA automatically detects installed wallet apps
  // Your app connects to whichever the user selects
  return await transact(async (wallet) => {
    // This will show wallet selection if multiple installed
    return await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });
  });
};
```

### Deep Linking

```bash
# Add to android/app/src/main/AndroidManifest.xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https"
        android:host="mydapp.com" />
</intent-filter>
```

## Troubleshooting

### No Wallet Apps Found
- Ensure user has Phantom/Solflare/Backpack installed
- Check if wallet supports MWA 2.0 protocol
- Verify app is running on device (not emulator)

### Authorization Failures
- Check app identity configuration
- Verify network connectivity
- Ensure proper permissions in AndroidManifest.xml

### Transaction Errors
- Check account has sufficient SOL for fees
- Verify recent blockhash is valid
- Ensure instruction accounts are correct

### Session Timeout
- MWA sessions are ephemeral - rebuild for each interaction
- Don't try to cache wallet instances between sessions
- Always use fresh `transact()` calls

## Next Steps

**For Full Implementation**: See `references/` folder for detailed guides on:
- Environment setup (setup-guide.md)
- MWA protocol details (mwa-guide.md) 
- Transaction building (transactions.md)
- Token operations (token-operations.md)
- App store publishing (publishing.md)
- Code snippets (code-snippets.md)

You now have everything needed to build production Solana mobile apps. Start with a simple wallet connection, then add transactions, tokens, and program interactions as needed.