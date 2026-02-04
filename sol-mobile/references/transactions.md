# Building, Signing, and Sending Transactions on Mobile

Comprehensive guide to handling Solana transactions in React Native mobile apps.

## Transaction Fundamentals

### Solana Transaction Types

**Legacy Transactions:**
- Older format with limited account space
- All account keys in transaction message
- 1232 byte size limit

**Versioned Transactions (Recommended):**
- Uses Address Lookup Tables (ALTs) 
- More efficient for complex transactions
- Better for mobile due to size constraints

```typescript
import {
  VersionedTransaction,
  TransactionMessage,
  SystemProgram,
  PublicKey,
} from '@solana/web3.js';

// Versioned transaction example
const buildVersionedTx = async () => {
  const txMessage = new TransactionMessage({
    payerKey: senderPubkey,
    recentBlockhash: latestBlockhash.blockhash,
    instructions: [instruction],
  }).compileToV0Message();

  return new VersionedTransaction(txMessage);
};
```

## Basic Transaction Flow

### 1. Build Transaction

```typescript
const buildTransaction = async (
  fromPubkey: PublicKey,
  instruction: TransactionInstruction
): Promise<VersionedTransaction> => {
  
  // Get recent blockhash
  const connection = new Connection(clusterApiUrl('devnet'), 'confirmed');
  const { blockhash } = await connection.getLatestBlockhash('confirmed');

  // Create transaction message
  const txMessage = new TransactionMessage({
    payerKey: fromPubkey,
    recentBlockhash: blockhash,
    instructions: [instruction],
  }).compileToV0Message();

  // Create versioned transaction
  return new VersionedTransaction(txMessage);
};
```

### 2. Sign and Send via MWA

```typescript
const signAndSend = async (transaction: VersionedTransaction) => {
  return await transact(async (wallet) => {
    // Authorize wallet
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    // Wallet signs and submits to network
    const signatures = await wallet.signAndSendTransactions({
      transactions: [transaction],
    });

    return signatures[0];
  });
};
```

### 3. Confirm Transaction

```typescript
const confirmTransaction = async (
  signature: string,
  connection: Connection
): Promise<boolean> => {
  
  try {
    const confirmation = await connection.confirmTransaction(
      signature,
      'confirmed'
    );
    
    if (confirmation.value.err) {
      console.error('Transaction failed:', confirmation.value.err);
      return false;
    }
    
    return true;
  } catch (error) {
    console.error('Confirmation error:', error);
    return false;
  }
};
```

## SOL Transfers

### Simple SOL Transfer

```typescript
import { SystemProgram, LAMPORTS_PER_SOL } from '@solana/web3.js';

const transferSOL = async (
  toPubkey: PublicKey, 
  amount: number // in SOL
): Promise<string> => {
  
  return await transact(async (wallet) => {
    // Authorize
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const fromPubkey = new PublicKey(toByteArray(accounts[0].address));

    // Create transfer instruction
    const instruction = SystemProgram.transfer({
      fromPubkey,
      toPubkey,
      lamports: amount * LAMPORTS_PER_SOL,
    });

    // Build transaction
    const transaction = await buildTransaction(fromPubkey, instruction);

    // Sign and send
    const signatures = await wallet.signAndSendTransactions({
      transactions: [transaction],
    });

    return signatures[0];
  });
};
```

### SOL Transfer with Memo

```typescript
import { TransactionInstruction } from '@solana/web3.js';

const MEMO_PROGRAM_ID = new PublicKey('MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr');

const transferSOLWithMemo = async (
  toPubkey: PublicKey,
  amount: number,
  memo: string
): Promise<string> => {
  
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const fromPubkey = new PublicKey(toByteArray(accounts[0].address));

    const instructions = [
      // Transfer instruction
      SystemProgram.transfer({
        fromPubkey,
        toPubkey,
        lamports: amount * LAMPORTS_PER_SOL,
      }),
      
      // Memo instruction
      new TransactionInstruction({
        keys: [{ pubkey: fromPubkey, isSigner: true, isWritable: false }],
        data: Buffer.from(memo, 'utf-8'),
        programId: MEMO_PROGRAM_ID,
      }),
    ];

    // Build transaction with multiple instructions
    const { blockhash } = await connection.getLatestBlockhash('confirmed');
    
    const txMessage = new TransactionMessage({
      payerKey: fromPubkey,
      recentBlockhash: blockhash,
      instructions,
    }).compileToV0Message();

    const transaction = new VersionedTransaction(txMessage);

    const signatures = await wallet.signAndSendTransactions({
      transactions: [transaction],
    });

    return signatures[0];
  });
};
```

## Account Creation

### Create New Account

```typescript
import { Keypair, SystemProgram } from '@solana/web3.js';

const createAccount = async (
  space: number,
  programId: PublicKey
): Promise<{ signature: string; newAccount: PublicKey }> => {
  
  // Generate new account keypair
  const newAccount = Keypair.generate();
  
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const payer = new PublicKey(toByteArray(accounts[0].address));

    // Calculate rent exemption
    const rentExemptLamports = await connection.getMinimumBalanceForRentExemption(space);

    // Create account instruction
    const instruction = SystemProgram.createAccount({
      fromPubkey: payer,
      newAccountPubkey: newAccount.publicKey,
      lamports: rentExemptLamports,
      space,
      programId,
    });

    const transaction = await buildTransaction(payer, instruction);

    // Add the new account as a signer
    transaction.sign([newAccount]);

    // Sign remaining signatures via wallet
    const signatures = await wallet.signAndSendTransactions({
      transactions: [transaction],
    });

    return {
      signature: signatures[0],
      newAccount: newAccount.publicKey,
    };
  });
};
```

### Create Associated Token Account

```typescript
import { 
  getAssociatedTokenAddress,
  createAssociatedTokenAccountInstruction,
  TOKEN_PROGRAM_ID,
  ASSOCIATED_TOKEN_PROGRAM_ID,
} from '@solana/spl-token';

const createTokenAccount = async (
  mintAddress: PublicKey,
  ownerAddress: PublicKey
): Promise<string> => {
  
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const payer = new PublicKey(toByteArray(accounts[0].address));

    // Get associated token account address
    const tokenAccount = await getAssociatedTokenAddress(
      mintAddress,
      ownerAddress,
      false,
      TOKEN_PROGRAM_ID,
      ASSOCIATED_TOKEN_PROGRAM_ID
    );

    // Check if account already exists
    const accountInfo = await connection.getAccountInfo(tokenAccount);
    if (accountInfo) {
      throw new Error('Token account already exists');
    }

    // Create instruction
    const instruction = createAssociatedTokenAccountInstruction(
      payer,        // payer
      tokenAccount, // associated token account
      ownerAddress, // owner
      mintAddress,  // mint
      TOKEN_PROGRAM_ID,
      ASSOCIATED_TOKEN_PROGRAM_ID
    );

    const transaction = await buildTransaction(payer, instruction);

    const signatures = await wallet.signAndSendTransactions({
      transactions: [transaction],
    });

    return signatures[0];
  });
};
```

## Complex Transactions

### Multi-Instruction Transaction

```typescript
const complexTransaction = async () => {
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const signer = new PublicKey(toByteArray(accounts[0].address));
    const { blockhash } = await connection.getLatestBlockhash('confirmed');

    const instructions = [
      // Instruction 1: Transfer SOL
      SystemProgram.transfer({
        fromPubkey: signer,
        toPubkey: new PublicKey('11111111111111111111111111111111'),
        lamports: 1000000,
      }),

      // Instruction 2: Create memo
      new TransactionInstruction({
        keys: [{ pubkey: signer, isSigner: true, isWritable: false }],
        data: Buffer.from('Complex transaction', 'utf-8'),
        programId: MEMO_PROGRAM_ID,
      }),

      // Add more instructions as needed...
    ];

    const txMessage = new TransactionMessage({
      payerKey: signer,
      recentBlockhash: blockhash,
      instructions,
    }).compileToV0Message();

    const transaction = new VersionedTransaction(txMessage);

    const signatures = await wallet.signAndSendTransactions({
      transactions: [transaction],
    });

    return signatures[0];
  });
};
```

### Batch Transactions

```typescript
const batchTransactions = async (
  instructions: TransactionInstruction[][]
): Promise<string[]> => {
  
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const signer = new PublicKey(toByteArray(accounts[0].address));
    const { blockhash } = await connection.getLatestBlockhash('confirmed');

    // Build multiple transactions
    const transactions = instructions.map(txInstructions => {
      const txMessage = new TransactionMessage({
        payerKey: signer,
        recentBlockhash: blockhash,
        instructions: txInstructions,
      }).compileToV0Message();

      return new VersionedTransaction(txMessage);
    });

    // Sign and send all transactions
    const signatures = await wallet.signAndSendTransactions({
      transactions,
    });

    return signatures;
  });
};
```

## Transaction Simulation

### Simulate Before Sending

```typescript
const simulateTransaction = async (
  transaction: VersionedTransaction
): Promise<{ success: boolean; logs: string[]; error?: string }> => {
  
  try {
    const simulation = await connection.simulateTransaction(transaction, {
      sigVerify: false,
      commitment: 'confirmed',
    });

    if (simulation.value.err) {
      return {
        success: false,
        logs: simulation.value.logs || [],
        error: JSON.stringify(simulation.value.err),
      };
    }

    return {
      success: true,
      logs: simulation.value.logs || [],
    };
  } catch (error) {
    return {
      success: false,
      logs: [],
      error: error.message,
    };
  }
};

// Usage
const safeTransfer = async (toPubkey: PublicKey, amount: number) => {
  // Build transaction
  const transaction = await buildSOLTransferTx(toPubkey, amount);
  
  // Simulate first
  const simulation = await simulateTransaction(transaction);
  
  if (!simulation.success) {
    throw new Error(`Simulation failed: ${simulation.error}`);
  }
  
  // If simulation passes, send for real
  return await signAndSend(transaction);
};
```

## Transaction Status and Monitoring

### Monitor Transaction Status

```typescript
class TransactionMonitor {
  private connection: Connection;
  
  constructor(connection: Connection) {
    this.connection = connection;
  }

  async waitForConfirmation(
    signature: string,
    timeout = 60000
  ): Promise<boolean> {
    
    const start = Date.now();
    
    while (Date.now() - start < timeout) {
      try {
        const status = await this.connection.getSignatureStatus(signature);
        
        if (status.value?.confirmationStatus === 'confirmed' || 
            status.value?.confirmationStatus === 'finalized') {
          return !status.value.err;
        }
        
        // Wait before next check
        await new Promise(resolve => setTimeout(resolve, 1000));
      } catch (error) {
        console.log('Status check error:', error);
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
    }
    
    throw new Error('Transaction confirmation timeout');
  }

  async getTransactionDetails(signature: string) {
    try {
      const tx = await this.connection.getParsedTransaction(signature, {
        maxSupportedTransactionVersion: 0,
      });
      
      if (!tx) {
        throw new Error('Transaction not found');
      }
      
      return {
        slot: tx.slot,
        blockTime: tx.blockTime,
        fee: tx.meta?.fee,
        success: !tx.meta?.err,
        error: tx.meta?.err,
        logs: tx.meta?.logMessages,
        balanceChanges: tx.meta?.preBalances.map((pre, i) => ({
          account: tx.transaction.message.accountKeys[i].pubkey.toString(),
          before: pre,
          after: tx.meta?.postBalances[i],
          change: (tx.meta?.postBalances[i] || 0) - pre,
        })),
      };
    } catch (error) {
      throw new Error(`Failed to get transaction details: ${error.message}`);
    }
  }
}

// Usage
const monitor = new TransactionMonitor(connection);

const sendAndTrack = async (transaction: VersionedTransaction) => {
  const signature = await signAndSend(transaction);
  
  console.log('Transaction sent:', signature);
  
  const confirmed = await monitor.waitForConfirmation(signature);
  
  if (confirmed) {
    const details = await monitor.getTransactionDetails(signature);
    console.log('Transaction details:', details);
  }
  
  return { signature, confirmed };
};
```

## Error Handling

### Transaction Error Types

```typescript
class TransactionError extends Error {
  public code: string;
  public signature?: string;
  
  constructor(message: string, code: string, signature?: string) {
    super(message);
    this.name = 'TransactionError';
    this.code = code;
    this.signature = signature;
  }
}

const handleTransactionError = (error: any): TransactionError => {
  // Parse common Solana errors
  if (error.message?.includes('insufficient funds')) {
    return new TransactionError(
      'Insufficient funds for transaction',
      'INSUFFICIENT_FUNDS'
    );
  }
  
  if (error.message?.includes('Blockhash not found')) {
    return new TransactionError(
      'Transaction expired (blockhash too old)',
      'BLOCKHASH_EXPIRED'
    );
  }
  
  if (error.message?.includes('User declined')) {
    return new TransactionError(
      'User cancelled transaction',
      'USER_CANCELLED'
    );
  }
  
  if (error.message?.includes('Attempt to debit an account but found no record')) {
    return new TransactionError(
      'Account does not exist',
      'ACCOUNT_NOT_FOUND'
    );
  }
  
  return new TransactionError(
    error.message || 'Unknown transaction error',
    'UNKNOWN_ERROR'
  );
};
```

### Retry Logic

```typescript
const retryableTransfer = async (
  toPubkey: PublicKey,
  amount: number,
  maxRetries = 3
): Promise<string> => {
  
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await transferSOL(toPubkey, amount);
    } catch (error) {
      const txError = handleTransactionError(error);
      
      // Don't retry user cancellations or permanent errors
      if (txError.code === 'USER_CANCELLED' || 
          txError.code === 'INSUFFICIENT_FUNDS') {
        throw txError;
      }
      
      // Retry blockhash expired and network errors
      if (attempt === maxRetries) {
        throw txError;
      }
      
      console.log(`Attempt ${attempt} failed, retrying...`);
      
      // Exponential backoff
      await new Promise(resolve => 
        setTimeout(resolve, 1000 * Math.pow(2, attempt - 1))
      );
    }
  }
  
  throw new Error('Max retries exceeded');
};
```

## Fee Management

### Priority Fees

```typescript
import { ComputeBudgetProgram } from '@solana/web3.js';

const buildTransactionWithPriorityFee = async (
  instruction: TransactionInstruction,
  microLamports: number // priority fee
): Promise<VersionedTransaction> => {
  
  const instructions = [
    // Set compute unit price (priority fee)
    ComputeBudgetProgram.setComputeUnitPrice({
      microLamports,
    }),
    
    // Set compute unit limit (optional)
    ComputeBudgetProgram.setComputeUnitLimit({
      units: 300000,
    }),
    
    // Your actual instruction
    instruction,
  ];

  const { blockhash } = await connection.getLatestBlockhash('confirmed');
  
  const txMessage = new TransactionMessage({
    payerKey: payerPubkey,
    recentBlockhash: blockhash,
    instructions,
  }).compileToV0Message();

  return new VersionedTransaction(txMessage);
};
```

### Fee Estimation

```typescript
const estimateTransactionFee = async (
  transaction: VersionedTransaction
): Promise<number> => {
  
  try {
    const response = await connection.getFeeForMessage(
      transaction.message,
      'confirmed'
    );
    
    return response.value || 5000; // fallback to 5000 lamports
  } catch (error) {
    console.log('Fee estimation failed:', error);
    return 5000; // fallback fee
  }
};
```

## Best Practices

### 1. Transaction Size Optimization

```typescript
// Prefer versioned transactions for better space efficiency
const optimizedTransaction = async () => {
  // Use address lookup tables for repeated accounts
  // Combine compatible instructions
  // Minimize instruction data size
};
```

### 2. Blockhash Management

```typescript
class BlockhashManager {
  private latestBlockhash: { blockhash: string; lastValidBlockHeight: number } | null = null;
  private fetchTime = 0;
  private readonly CACHE_TTL = 30000; // 30 seconds
  
  async getRecentBlockhash(): Promise<string> {
    const now = Date.now();
    
    if (!this.latestBlockhash || (now - this.fetchTime) > this.CACHE_TTL) {
      this.latestBlockhash = await connection.getLatestBlockhash('confirmed');
      this.fetchTime = now;
    }
    
    return this.latestBlockhash.blockhash;
  }
}
```

### 3. Connection Management

```typescript
// Singleton connection with retry logic
class SolanaConnectionManager {
  private static instance: Connection;
  
  static getInstance(): Connection {
    if (!this.instance) {
      this.instance = new Connection(
        process.env.RPC_ENDPOINT || clusterApiUrl('devnet'),
        {
          commitment: 'confirmed',
          confirmTransactionInitialTimeout: 60000,
        }
      );
    }
    return this.instance;
  }
}
```

This covers the complete transaction handling for Solana mobile apps, from basic transfers to complex multi-instruction transactions with proper error handling and monitoring.