# Ready-to-Use Code Patterns

Collection of production-ready code snippets for common Solana mobile app patterns.

## Project Setup

### Complete Index.js Setup

```javascript
// index.js
import 'react-native-get-random-values';
import { Buffer } from 'buffer';

global.Buffer = global.Buffer || Buffer;

import { AppRegistry } from 'react-native';
import App from './src/App';
import { name as appName } from './app.json';

AppRegistry.registerComponent(appName, () => App);
```

### App.tsx with Authorization Provider

```typescript
// src/App.tsx
import React from 'react';
import { StatusBar } from 'react-native';
import { AuthorizationProvider } from './contexts/AuthorizationProvider';
import { MainNavigator } from './navigation/MainNavigator';

const App = () => {
  return (
    <>
      <StatusBar barStyle="dark-content" backgroundColor="#ffffff" />
      <AuthorizationProvider>
        <MainNavigator />
      </AuthorizationProvider>
    </>
  );
};

export default App;
```

## Authorization Provider

### Complete Authorization Context

```typescript
// src/contexts/AuthorizationProvider.tsx
import React, { createContext, useContext, useState, useEffect, ReactNode } from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { PublicKey } from '@solana/web3.js';
import { transact } from '@solana-mobile/mobile-wallet-adapter-protocol-web3js';
import { toByteArray } from 'react-native-quick-base64';

const APP_IDENTITY = {
  name: 'Your Solana App',
  uri: 'https://yourapp.com',
  icon: 'favicon.ico',
};

interface AuthContextType {
  selectedAccount: PublicKey | null;
  isAuthorized: boolean;
  isLoading: boolean;
  authorize: () => Promise<void>;
  deauthorize: () => Promise<void>;
  reauthorize: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

interface Props {
  children: ReactNode;
}

export const AuthorizationProvider = ({ children }: Props) => {
  const [selectedAccount, setSelectedAccount] = useState<PublicKey | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    // Try to reauthorize on app start
    handleAppStart();
  }, []);

  const handleAppStart = async () => {
    setIsLoading(true);
    try {
      await reauthorize();
    } catch (error) {
      console.log('Auto-reauthorization failed:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const authorize = async () => {
    setIsLoading(true);
    try {
      const authResult = await transact(async (wallet) => {
        return await wallet.authorize({
          identity: APP_IDENTITY,
          chain: 'solana:devnet',
        });
      });

      const publicKey = new PublicKey(toByteArray(authResult.accounts[0].address));
      setSelectedAccount(publicKey);

      // Store auth token for silent re-authorization
      await AsyncStorage.setItem('auth_token', authResult.auth_token);
      await AsyncStorage.setItem('wallet_address', publicKey.toString());
    } catch (error) {
      console.error('Authorization failed:', error);
      throw error;
    } finally {
      setIsLoading(false);
    }
  };

  const reauthorize = async () => {
    const savedToken = await AsyncStorage.getItem('auth_token');
    const savedAddress = await AsyncStorage.getItem('wallet_address');

    if (!savedToken || !savedAddress) {
      throw new Error('No saved credentials');
    }

    try {
      const authResult = await transact(async (wallet) => {
        return await wallet.authorize({
          identity: APP_IDENTITY,
          chain: 'solana:devnet',
          auth_token: savedToken,
        });
      });

      const publicKey = new PublicKey(toByteArray(authResult.accounts[0].address));
      setSelectedAccount(publicKey);

      // Update stored token
      await AsyncStorage.setItem('auth_token', authResult.auth_token);
    } catch (error) {
      // Clear invalid credentials
      await AsyncStorage.removeItem('auth_token');
      await AsyncStorage.removeItem('wallet_address');
      throw error;
    }
  };

  const deauthorize = async () => {
    setIsLoading(true);
    try {
      const savedToken = await AsyncStorage.getItem('auth_token');
      
      if (savedToken) {
        await transact(async (wallet) => {
          await wallet.deauthorize({ auth_token: savedToken });
        });
      }

      setSelectedAccount(null);
      await AsyncStorage.removeItem('auth_token');
      await AsyncStorage.removeItem('wallet_address');
    } catch (error) {
      console.error('Deauthorization failed:', error);
      // Clear credentials anyway
      setSelectedAccount(null);
      await AsyncStorage.removeItem('auth_token');
      await AsyncStorage.removeItem('wallet_address');
    } finally {
      setIsLoading(false);
    }
  };

  const value = {
    selectedAccount,
    isAuthorized: !!selectedAccount,
    isLoading,
    authorize,
    deauthorize,
    reauthorize,
  };

  return (
    <AuthContext.Provider value={value}>
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

## Transaction Hook

### Complete Transaction Hook

```typescript
// src/hooks/useTransactions.ts
import { useState } from 'react';
import { Alert } from 'react-native';
import { 
  Connection, 
  PublicKey, 
  SystemProgram, 
  VersionedTransaction,
  TransactionMessage,
  LAMPORTS_PER_SOL,
  clusterApiUrl
} from '@solana/web3.js';
import { transact } from '@solana-mobile/mobile-wallet-adapter-protocol-web3js';
import { toByteArray } from 'react-native-quick-base64';
import { useAuthorization } from '../contexts/AuthorizationProvider';

const APP_IDENTITY = {
  name: 'Your Solana App',
  uri: 'https://yourapp.com',
  icon: 'favicon.ico',
};

const connection = new Connection(clusterApiUrl('devnet'), 'confirmed');

export const useTransactions = () => {
  const [isLoading, setIsLoading] = useState(false);
  const { selectedAccount } = useAuthorization();

  const sendSOL = async (recipient: string, amount: number): Promise<string | null> => {
    if (!selectedAccount) {
      Alert.alert('Error', 'No wallet connected');
      return null;
    }

    setIsLoading(true);
    try {
      const signature = await transact(async (wallet) => {
        // Authorize
        const authResult = await wallet.authorize({
          identity: APP_IDENTITY,
          chain: 'solana:devnet',
        });

        const senderPubkey = new PublicKey(toByteArray(authResult.accounts[0].address));
        const recipientPubkey = new PublicKey(recipient);

        // Create transfer instruction
        const instruction = SystemProgram.transfer({
          fromPubkey: senderPubkey,
          toPubkey: recipientPubkey,
          lamports: amount * LAMPORTS_PER_SOL,
        });

        // Build transaction
        const { blockhash } = await connection.getLatestBlockhash('confirmed');
        const txMessage = new TransactionMessage({
          payerKey: senderPubkey,
          recentBlockhash: blockhash,
          instructions: [instruction],
        }).compileToV0Message();

        const transaction = new VersionedTransaction(txMessage);

        // Sign and send
        const signatures = await wallet.signAndSendTransactions({
          transactions: [transaction],
        });

        return signatures[0];
      });

      Alert.alert('Success', `Transaction sent: ${signature}`);
      return signature;
    } catch (error) {
      console.error('Transaction failed:', error);
      
      let message = 'Transaction failed';
      if (error.message?.includes('User declined')) {
        message = 'Transaction cancelled';
      } else if (error.message?.includes('insufficient funds')) {
        message = 'Insufficient SOL balance';
      }
      
      Alert.alert('Error', message);
      return null;
    } finally {
      setIsLoading(false);
    }
  };

  const getBalance = async (): Promise<number> => {
    if (!selectedAccount) return 0;

    try {
      const balance = await connection.getBalance(selectedAccount);
      return balance / LAMPORTS_PER_SOL;
    } catch (error) {
      console.error('Failed to fetch balance:', error);
      return 0;
    }
  };

  return {
    sendSOL,
    getBalance,
    isLoading,
  };
};
```

## Common Screens

### Wallet Connection Screen

```typescript
// src/screens/WalletScreen.tsx
import React from 'react';
import {
  View,
  Text,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  StyleSheet,
} from 'react-native';
import { useAuthorization } from '../contexts/AuthorizationProvider';

export const WalletScreen = () => {
  const { selectedAccount, isAuthorized, isLoading, authorize, deauthorize } = useAuthorization();

  const handleConnect = async () => {
    try {
      await authorize();
    } catch (error) {
      console.log('Connection failed:', error);
    }
  };

  const handleDisconnect = () => {
    Alert.alert(
      'Disconnect Wallet',
      'Are you sure you want to disconnect?',
      [
        { text: 'Cancel', style: 'cancel' },
        { text: 'Disconnect', onPress: deauthorize },
      ]
    );
  };

  if (isLoading) {
    return (
      <View style={styles.container}>
        <ActivityIndicator size="large" color="#512da8" />
        <Text style={styles.loadingText}>Connecting wallet...</Text>
      </View>
    );
  }

  if (!isAuthorized) {
    return (
      <View style={styles.container}>
        <Text style={styles.title}>Connect Your Wallet</Text>
        <Text style={styles.subtitle}>
          Connect a Solana mobile wallet to get started
        </Text>
        
        <TouchableOpacity
          style={styles.connectButton}
          onPress={handleConnect}
        >
          <Text style={styles.connectButtonText}>Connect Wallet</Text>
        </TouchableOpacity>
        
        <Text style={styles.note}>
          Supported wallets: Phantom, Solflare, Backpack
        </Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Wallet Connected</Text>
      
      <View style={styles.accountInfo}>
        <Text style={styles.label}>Address:</Text>
        <Text style={styles.address}>
          {selectedAccount?.toString().slice(0, 8)}...
          {selectedAccount?.toString().slice(-8)}
        </Text>
      </View>

      <TouchableOpacity
        style={styles.disconnectButton}
        onPress={handleDisconnect}
      >
        <Text style={styles.disconnectButtonText}>Disconnect</Text>
      </TouchableOpacity>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 10,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    marginBottom: 30,
    textAlign: 'center',
  },
  connectButton: {
    backgroundColor: '#512da8',
    paddingHorizontal: 30,
    paddingVertical: 15,
    borderRadius: 10,
    marginBottom: 20,
  },
  connectButtonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
  note: {
    fontSize: 12,
    color: '#888',
    textAlign: 'center',
  },
  loadingText: {
    marginTop: 10,
    fontSize: 16,
    color: '#512da8',
  },
  accountInfo: {
    backgroundColor: 'white',
    padding: 20,
    borderRadius: 10,
    marginBottom: 30,
    width: '100%',
  },
  label: {
    fontSize: 14,
    color: '#666',
    marginBottom: 5,
  },
  address: {
    fontSize: 16,
    fontFamily: 'monospace',
    backgroundColor: '#f0f0f0',
    padding: 10,
    borderRadius: 5,
  },
  disconnectButton: {
    backgroundColor: '#d32f2f',
    paddingHorizontal: 30,
    paddingVertical: 15,
    borderRadius: 10,
  },
  disconnectButtonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
});
```

### Transfer Screen

```typescript
// src/screens/TransferScreen.tsx
import React, { useState, useEffect } from 'react';
import {
  View,
  Text,
  TextInput,
  TouchableOpacity,
  Alert,
  StyleSheet,
  ActivityIndicator,
} from 'react-native';
import { PublicKey } from '@solana/web3.js';
import { useTransactions } from '../hooks/useTransactions';

export const TransferScreen = () => {
  const [recipient, setRecipient] = useState('');
  const [amount, setAmount] = useState('');
  const [balance, setBalance] = useState<number>(0);
  const { sendSOL, getBalance, isLoading } = useTransactions();

  useEffect(() => {
    loadBalance();
  }, []);

  const loadBalance = async () => {
    const bal = await getBalance();
    setBalance(bal);
  };

  const validateInputs = (): boolean => {
    // Validate recipient address
    try {
      new PublicKey(recipient);
    } catch {
      Alert.alert('Error', 'Invalid recipient address');
      return false;
    }

    // Validate amount
    const amountNum = parseFloat(amount);
    if (isNaN(amountNum) || amountNum <= 0) {
      Alert.alert('Error', 'Invalid amount');
      return false;
    }

    if (amountNum > balance) {
      Alert.alert('Error', 'Insufficient balance');
      return false;
    }

    return true;
  };

  const handleTransfer = async () => {
    if (!validateInputs()) return;

    const signature = await sendSOL(recipient, parseFloat(amount));
    
    if (signature) {
      setRecipient('');
      setAmount('');
      loadBalance(); // Refresh balance
    }
  };

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Send SOL</Text>
      
      <View style={styles.balanceContainer}>
        <Text style={styles.balanceLabel}>Available Balance:</Text>
        <Text style={styles.balance}>{balance.toFixed(4)} SOL</Text>
      </View>

      <View style={styles.form}>
        <Text style={styles.label}>Recipient Address:</Text>
        <TextInput
          style={styles.input}
          value={recipient}
          onChangeText={setRecipient}
          placeholder="Enter Solana address"
          autoCapitalize="none"
          autoCorrect={false}
        />

        <Text style={styles.label}>Amount (SOL):</Text>
        <TextInput
          style={styles.input}
          value={amount}
          onChangeText={setAmount}
          placeholder="0.00"
          keyboardType="numeric"
        />

        <TouchableOpacity
          style={[styles.sendButton, isLoading && styles.disabledButton]}
          onPress={handleTransfer}
          disabled={isLoading}
        >
          {isLoading ? (
            <ActivityIndicator color="white" />
          ) : (
            <Text style={styles.sendButtonText}>Send SOL</Text>
          )}
        </TouchableOpacity>
      </View>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    flex: 1,
    padding: 20,
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 24,
    fontWeight: 'bold',
    marginBottom: 20,
    textAlign: 'center',
  },
  balanceContainer: {
    backgroundColor: 'white',
    padding: 15,
    borderRadius: 10,
    marginBottom: 20,
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  balanceLabel: {
    fontSize: 16,
    color: '#666',
  },
  balance: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#512da8',
  },
  form: {
    backgroundColor: 'white',
    padding: 20,
    borderRadius: 10,
  },
  label: {
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 5,
    marginTop: 15,
  },
  input: {
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 5,
    padding: 10,
    fontSize: 16,
  },
  sendButton: {
    backgroundColor: '#512da8',
    padding: 15,
    borderRadius: 5,
    alignItems: 'center',
    marginTop: 20,
  },
  disabledButton: {
    backgroundColor: '#ccc',
  },
  sendButtonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: 'bold',
  },
});
```

## Navigation Setup

### React Navigation Setup

```bash
# Install navigation dependencies
yarn add @react-navigation/native @react-navigation/bottom-tabs @react-navigation/native-stack
yarn add react-native-screens react-native-safe-area-context
```

```typescript
// src/navigation/MainNavigator.tsx
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { WalletScreen } from '../screens/WalletScreen';
import { TransferScreen } from '../screens/TransferScreen';
import { useAuthorization } from '../contexts/AuthorizationProvider';

const Tab = createBottomTabNavigator();
const Stack = createNativeStackNavigator();

const AuthorizedTabs = () => (
  <Tab.Navigator
    screenOptions={{
      tabBarActiveTintColor: '#512da8',
      tabBarInactiveTintColor: '#666',
    }}
  >
    <Tab.Screen
      name="Wallet"
      component={WalletScreen}
      options={{
        title: 'Wallet',
        headerShown: true,
      }}
    />
    <Tab.Screen
      name="Transfer"
      component={TransferScreen}
      options={{
        title: 'Send SOL',
        headerShown: true,
      }}
    />
  </Tab.Navigator>
);

export const MainNavigator = () => {
  const { isAuthorized } = useAuthorization();

  return (
    <NavigationContainer>
      <Stack.Navigator screenOptions={{ headerShown: false }}>
        {isAuthorized ? (
          <Stack.Screen name="AuthorizedApp" component={AuthorizedTabs} />
        ) : (
          <Stack.Screen name="WalletConnect" component={WalletScreen} />
        )}
      </Stack.Navigator>
    </NavigationContainer>
  );
};
```

## Utility Functions

### Common Solana Utilities

```typescript
// src/utils/solana.ts
import { PublicKey, Connection, clusterApiUrl } from '@solana/web3.js';

export const connection = new Connection(clusterApiUrl('devnet'), 'confirmed');

export const validateSolanaAddress = (address: string): boolean => {
  try {
    new PublicKey(address);
    return true;
  } catch {
    return false;
  }
};

export const shortenAddress = (address: string, chars = 4): string => {
  return `${address.slice(0, chars)}...${address.slice(-chars)}`;
};

export const lamportsToSOL = (lamports: number): number => {
  return lamports / 1_000_000_000;
};

export const solToLamports = (sol: number): number => {
  return sol * 1_000_000_000;
};

export const formatSOL = (sol: number, decimals = 4): string => {
  return sol.toFixed(decimals);
};

export const explorerUrl = (signature: string, cluster = 'devnet'): string => {
  return `https://explorer.solana.com/tx/${signature}?cluster=${cluster}`;
};
```

### Error Handling Utilities

```typescript
// src/utils/errors.ts
export class SolanaError extends Error {
  constructor(message: string, public code: string) {
    super(message);
    this.name = 'SolanaError';
  }
}

export const handleMWAError = (error: any): SolanaError => {
  const message = error.message?.toLowerCase() || '';

  if (message.includes('user declined')) {
    return new SolanaError('Transaction was cancelled', 'USER_CANCELLED');
  }

  if (message.includes('insufficient funds')) {
    return new SolanaError('Insufficient funds for transaction', 'INSUFFICIENT_FUNDS');
  }

  if (message.includes('blockhash not found')) {
    return new SolanaError('Transaction expired. Please try again.', 'BLOCKHASH_EXPIRED');
  }

  if (message.includes('no wallet found')) {
    return new SolanaError('No compatible wallet found. Please install Phantom or Solflare.', 'NO_WALLET');
  }

  return new SolanaError(error.message || 'Unknown error occurred', 'UNKNOWN');
};

export const showUserFriendlyError = (error: any, defaultMessage = 'Something went wrong') => {
  const solanaError = handleMWAError(error);
  
  // Don't show error for user cancellations
  if (solanaError.code === 'USER_CANCELLED') {
    return;
  }

  Alert.alert('Error', solanaError.message);
};
```

### Storage Utilities

```typescript
// src/utils/storage.ts
import AsyncStorage from '@react-native-async-storage/async-storage';

export const storage = {
  async setItem(key: string, value: any): Promise<void> {
    try {
      const jsonValue = JSON.stringify(value);
      await AsyncStorage.setItem(key, jsonValue);
    } catch (error) {
      console.error('Storage setItem error:', error);
    }
  },

  async getItem(key: string): Promise<any> {
    try {
      const jsonValue = await AsyncStorage.getItem(key);
      return jsonValue != null ? JSON.parse(jsonValue) : null;
    } catch (error) {
      console.error('Storage getItem error:', error);
      return null;
    }
  },

  async removeItem(key: string): Promise<void> {
    try {
      await AsyncStorage.removeItem(key);
    } catch (error) {
      console.error('Storage removeItem error:', error);
    }
  },

  async clear(): Promise<void> {
    try {
      await AsyncStorage.clear();
    } catch (error) {
      console.error('Storage clear error:', error);
    }
  }
};

// Specific storage keys
export const STORAGE_KEYS = {
  AUTH_TOKEN: 'auth_token',
  WALLET_ADDRESS: 'wallet_address',
  USER_PREFERENCES: 'user_preferences',
} as const;
```

## Testing Utilities

### Test Helpers

```typescript
// src/__tests__/testUtils.tsx
import React from 'react';
import { render } from '@testing-library/react-native';
import { AuthorizationProvider } from '../contexts/AuthorizationProvider';

export const renderWithProvider = (component: React.ReactElement) => {
  return render(
    <AuthorizationProvider>
      {component}
    </AuthorizationProvider>
  );
};

export const mockWallet = {
  authorize: jest.fn(),
  deauthorize: jest.fn(),
  signAndSendTransactions: jest.fn(),
  signTransactions: jest.fn(),
  signMessages: jest.fn(),
};

export const mockTransact = jest.fn((callback) => callback(mockWallet));

// Mock the MWA module
jest.mock('@solana-mobile/mobile-wallet-adapter-protocol-web3js', () => ({
  transact: mockTransact,
}));
```

## Environment Configuration

### Environment Variables

```typescript
// src/config/environment.ts
interface Config {
  isDevelopment: boolean;
  solanaCluster: 'devnet' | 'mainnet-beta';
  rpcEndpoint: string;
  appIdentity: {
    name: string;
    uri: string;
    icon: string;
  };
}

const development: Config = {
  isDevelopment: true,
  solanaCluster: 'devnet',
  rpcEndpoint: 'https://api.devnet.solana.com',
  appIdentity: {
    name: 'Your App (Dev)',
    uri: 'https://dev.yourapp.com',
    icon: 'favicon.ico',
  },
};

const production: Config = {
  isDevelopment: false,
  solanaCluster: 'mainnet-beta',
  rpcEndpoint: 'https://solana-api.projectserum.com',
  appIdentity: {
    name: 'Your App',
    uri: 'https://yourapp.com',
    icon: 'favicon.ico',
  },
};

export const CONFIG = __DEV__ ? development : production;
```

This completes the comprehensive collection of ready-to-use code patterns for Solana mobile development. These snippets provide a solid foundation for building production-ready Solana mobile apps.