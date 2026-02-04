# SPL Tokens, NFTs, and Token Operations on Mobile

Complete guide for working with tokens and NFTs in Solana mobile apps.

## SPL Token Fundamentals

### Token Architecture

```
Mint Account (Token Definition)
└── Associated Token Accounts (User Balances)
    ├── User A's Token Account
    ├── User B's Token Account  
    └── User C's Token Account
```

**Mint Account**: Defines the token (supply, decimals, authority)
**Token Account**: Holds a user's balance of a specific token
**Associated Token Account (ATA)**: Deterministic token account address per user/mint

### Key Dependencies

```bash
yarn add @solana/spl-token
```

```typescript
import {
  getAssociatedTokenAddress,
  createAssociatedTokenAccountInstruction,
  createTransferInstruction,
  createMintToInstruction,
  TOKEN_PROGRAM_ID,
  ASSOCIATED_TOKEN_PROGRAM_ID,
} from '@solana/spl-token';
```

## Token Account Management

### Check Token Account Exists

```typescript
const getTokenAccountInfo = async (
  mintAddress: PublicKey,
  ownerAddress: PublicKey
): Promise<{ exists: boolean; balance?: number; address?: PublicKey }> => {
  
  try {
    const tokenAccount = await getAssociatedTokenAddress(
      mintAddress,
      ownerAddress,
      false, // allowOwnerOffCurve
      TOKEN_PROGRAM_ID,
      ASSOCIATED_TOKEN_PROGRAM_ID
    );

    const accountInfo = await connection.getTokenAccountBalance(tokenAccount);
    
    return {
      exists: true,
      balance: accountInfo.value.uiAmount || 0,
      address: tokenAccount,
    };
  } catch (error) {
    return { exists: false };
  }
};
```

### Create Associated Token Account

```typescript
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

    const tokenAccount = await getAssociatedTokenAddress(
      mintAddress,
      ownerAddress,
      false,
      TOKEN_PROGRAM_ID,
      ASSOCIATED_TOKEN_PROGRAM_ID
    );

    // Check if already exists
    const accountInfo = await getTokenAccountInfo(mintAddress, ownerAddress);
    if (accountInfo.exists) {
      throw new Error('Token account already exists');
    }

    const instruction = createAssociatedTokenAccountInstruction(
      payer,        // payer
      tokenAccount, // ata
      ownerAddress, // owner
      mintAddress,  // mint
      TOKEN_PROGRAM_ID,
      ASSOCIATED_TOKEN_PROGRAM_ID
    );

    const { blockhash } = await connection.getLatestBlockhash('confirmed');
    
    const txMessage = new TransactionMessage({
      payerKey: payer,
      recentBlockhash: blockhash,
      instructions: [instruction],
    }).compileToV0Message();

    const transaction = new VersionedTransaction(txMessage);

    const signatures = await wallet.signAndSendTransactions({
      transactions: [transaction],
    });

    return signatures[0];
  });
};
```

## Token Transfers

### Basic SPL Token Transfer

```typescript
const transferTokens = async (
  mintAddress: PublicKey,
  recipientAddress: PublicKey,
  amount: number,
  decimals: number
): Promise<string> => {
  
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const senderAddress = new PublicKey(toByteArray(accounts[0].address));

    // Get token accounts
    const senderTokenAccount = await getAssociatedTokenAddress(
      mintAddress,
      senderAddress
    );

    const recipientTokenAccount = await getAssociatedTokenAddress(
      mintAddress,
      recipientAddress
    );

    const instructions = [];

    // Check if recipient token account exists, create if not
    const recipientAccountInfo = await getTokenAccountInfo(mintAddress, recipientAddress);
    if (!recipientAccountInfo.exists) {
      instructions.push(
        createAssociatedTokenAccountInstruction(
          senderAddress,          // payer
          recipientTokenAccount,  // ata
          recipientAddress,       // owner
          mintAddress,           // mint
          TOKEN_PROGRAM_ID,
          ASSOCIATED_TOKEN_PROGRAM_ID
        )
      );
    }

    // Add transfer instruction
    const transferAmount = amount * Math.pow(10, decimals);
    instructions.push(
      createTransferInstruction(
        senderTokenAccount,     // source
        recipientTokenAccount,  // destination
        senderAddress,          // owner
        transferAmount,         // amount
        [],                     // multiSigners
        TOKEN_PROGRAM_ID
      )
    );

    const { blockhash } = await connection.getLatestBlockhash('confirmed');
    
    const txMessage = new TransactionMessage({
      payerKey: senderAddress,
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

### Transfer with Memo

```typescript
const transferTokensWithMemo = async (
  mintAddress: PublicKey,
  recipientAddress: PublicKey,
  amount: number,
  decimals: number,
  memo: string
): Promise<string> => {
  
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const senderAddress = new PublicKey(toByteArray(accounts[0].address));

    const senderTokenAccount = await getAssociatedTokenAddress(
      mintAddress,
      senderAddress
    );

    const recipientTokenAccount = await getAssociatedTokenAddress(
      mintAddress,
      recipientAddress
    );

    const instructions = [];

    // Create recipient account if needed
    const recipientAccountInfo = await getTokenAccountInfo(mintAddress, recipientAddress);
    if (!recipientAccountInfo.exists) {
      instructions.push(
        createAssociatedTokenAccountInstruction(
          senderAddress,
          recipientTokenAccount,
          recipientAddress,
          mintAddress
        )
      );
    }

    // Transfer instruction
    const transferAmount = amount * Math.pow(10, decimals);
    instructions.push(
      createTransferInstruction(
        senderTokenAccount,
        recipientTokenAccount,
        senderAddress,
        transferAmount
      )
    );

    // Memo instruction
    const MEMO_PROGRAM_ID = new PublicKey('MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr');
    instructions.push(
      new TransactionInstruction({
        keys: [{ pubkey: senderAddress, isSigner: true, isWritable: false }],
        data: Buffer.from(memo, 'utf-8'),
        programId: MEMO_PROGRAM_ID,
      })
    );

    const { blockhash } = await connection.getLatestBlockhash('confirmed');
    
    const txMessage = new TransactionMessage({
      payerKey: senderAddress,
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

## Token Information and Balances

### Get All Token Balances

```typescript
interface TokenBalance {
  mint: string;
  amount: number;
  decimals: number;
  uiAmount: number;
  tokenAccount: string;
}

const getAllTokenBalances = async (
  ownerAddress: PublicKey
): Promise<TokenBalance[]> => {
  
  try {
    const tokenAccounts = await connection.getParsedTokenAccountsByOwner(
      ownerAddress,
      {
        programId: TOKEN_PROGRAM_ID,
      }
    );

    return tokenAccounts.value
      .filter(account => {
        const data = account.account.data.parsed.info;
        return data.tokenAmount.uiAmount > 0;
      })
      .map(account => {
        const data = account.account.data.parsed.info;
        return {
          mint: data.mint,
          amount: parseInt(data.tokenAmount.amount),
          decimals: data.tokenAmount.decimals,
          uiAmount: data.tokenAmount.uiAmount,
          tokenAccount: account.pubkey.toString(),
        };
      });
  } catch (error) {
    console.error('Error fetching token balances:', error);
    return [];
  }
};
```

### Get Token Metadata

```typescript
interface TokenMetadata {
  name: string;
  symbol: string;
  image?: string;
  description?: string;
  decimals: number;
}

const getTokenMetadata = async (mintAddress: PublicKey): Promise<TokenMetadata | null> => {
  try {
    // Try to get mint info first
    const mintInfo = await connection.getParsedAccountInfo(mintAddress);
    
    if (!mintInfo.value?.data || !('parsed' in mintInfo.value.data)) {
      return null;
    }

    const decimals = mintInfo.value.data.parsed.info.decimals;

    // Try to get metadata from Metaplex (for tokens with metadata)
    try {
      const metadataPDA = await PublicKey.findProgramAddress(
        [
          Buffer.from('metadata'),
          new PublicKey('metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s').toBuffer(),
          mintAddress.toBuffer(),
        ],
        new PublicKey('metaqbxxUerdq28cj1RbAWkYQm3ybzjb6a8bt518x1s')
      );

      const metadataAccount = await connection.getAccountInfo(metadataPDA[0]);
      
      if (metadataAccount) {
        // Parse metadata (simplified - you may want to use @metaplex-foundation/mpl-token-metadata)
        // This is a basic implementation
        return {
          name: `Token ${mintAddress.toString().slice(0, 8)}`,
          symbol: `TKN`,
          decimals,
          description: 'SPL Token',
        };
      }
    } catch (metadataError) {
      // Metadata doesn't exist or parsing failed
    }

    // Return basic info if metadata not available
    return {
      name: `Token ${mintAddress.toString().slice(0, 8)}`,
      symbol: 'TKN',
      decimals,
    };
  } catch (error) {
    console.error('Error fetching token metadata:', error);
    return null;
  }
};
```

## Token Minting

### Create New Token Mint

```typescript
import { createInitializeMintInstruction, MintLayout } from '@solana/spl-token';

const createTokenMint = async (
  decimals: number,
  mintAuthority?: PublicKey,
  freezeAuthority?: PublicKey
): Promise<{ signature: string; mintAddress: PublicKey }> => {
  
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const payer = new PublicKey(toByteArray(accounts[0].address));
    const mintKeypair = Keypair.generate();

    // Default authorities to payer if not specified
    const mintAuth = mintAuthority || payer;
    const freezeAuth = freezeAuthority || null;

    const rentExemptLamports = await connection.getMinimumBalanceForRentExemption(
      MintLayout.span
    );

    const instructions = [
      // Create mint account
      SystemProgram.createAccount({
        fromPubkey: payer,
        newAccountPubkey: mintKeypair.publicKey,
        lamports: rentExemptLamports,
        space: MintLayout.span,
        programId: TOKEN_PROGRAM_ID,
      }),

      // Initialize mint
      createInitializeMintInstruction(
        mintKeypair.publicKey, // mint
        decimals,              // decimals
        mintAuth,              // mint authority
        freezeAuth,            // freeze authority
        TOKEN_PROGRAM_ID
      ),
    ];

    const { blockhash } = await connection.getLatestBlockhash('confirmed');
    
    const txMessage = new TransactionMessage({
      payerKey: payer,
      recentBlockhash: blockhash,
      instructions,
    }).compileToV0Message();

    const transaction = new VersionedTransaction(txMessage);

    // Sign with mint keypair
    transaction.sign([mintKeypair]);

    const signatures = await wallet.signAndSendTransactions({
      transactions: [transaction],
    });

    return {
      signature: signatures[0],
      mintAddress: mintKeypair.publicKey,
    };
  });
};
```

### Mint Tokens to Account

```typescript
const mintTokens = async (
  mintAddress: PublicKey,
  recipientAddress: PublicKey,
  amount: number,
  decimals: number
): Promise<string> => {
  
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const mintAuthority = new PublicKey(toByteArray(accounts[0].address));

    // Get or create recipient token account
    const recipientTokenAccount = await getAssociatedTokenAddress(
      mintAddress,
      recipientAddress
    );

    const instructions = [];

    // Create token account if it doesn't exist
    const accountInfo = await getTokenAccountInfo(mintAddress, recipientAddress);
    if (!accountInfo.exists) {
      instructions.push(
        createAssociatedTokenAccountInstruction(
          mintAuthority,         // payer
          recipientTokenAccount, // ata
          recipientAddress,      // owner
          mintAddress           // mint
        )
      );
    }

    // Mint tokens
    const mintAmount = amount * Math.pow(10, decimals);
    instructions.push(
      createMintToInstruction(
        mintAddress,           // mint
        recipientTokenAccount, // destination
        mintAuthority,         // mint authority
        mintAmount            // amount
      )
    );

    const { blockhash } = await connection.getLatestBlockhash('confirmed');
    
    const txMessage = new TransactionMessage({
      payerKey: mintAuthority,
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

## NFT Operations

### NFT Fundamentals

NFTs on Solana are SPL tokens with:
- **Supply**: 1 (unique)
- **Decimals**: 0 (non-divisible)  
- **Metadata**: JSON with image, attributes, etc.

### Create NFT

```typescript
interface NFTMetadata {
  name: string;
  symbol: string;
  description: string;
  image: string;
  attributes?: Array<{ trait_type: string; value: string }>;
}

const createNFT = async (
  metadata: NFTMetadata,
  recipientAddress: PublicKey
): Promise<{ signature: string; mintAddress: PublicKey; metadataUri: string }> => {
  
  // First, upload metadata to IPFS/Arweave
  const metadataUri = await uploadMetadata(metadata);
  
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const payer = new PublicKey(toByteArray(accounts[0].address));
    const mintKeypair = Keypair.generate();

    const rentExemptLamports = await connection.getMinimumBalanceForRentExemption(
      MintLayout.span
    );

    // Get recipient token account
    const recipientTokenAccount = await getAssociatedTokenAddress(
      mintKeypair.publicKey,
      recipientAddress
    );

    const instructions = [
      // Create mint account
      SystemProgram.createAccount({
        fromPubkey: payer,
        newAccountPubkey: mintKeypair.publicKey,
        lamports: rentExemptLamports,
        space: MintLayout.span,
        programId: TOKEN_PROGRAM_ID,
      }),

      // Initialize mint (NFT: decimals=0, supply=1)
      createInitializeMintInstruction(
        mintKeypair.publicKey,
        0,        // decimals
        payer,    // mint authority
        payer,    // freeze authority
        TOKEN_PROGRAM_ID
      ),

      // Create recipient token account
      createAssociatedTokenAccountInstruction(
        payer,
        recipientTokenAccount,
        recipientAddress,
        mintKeypair.publicKey
      ),

      // Mint 1 NFT to recipient
      createMintToInstruction(
        mintKeypair.publicKey,
        recipientTokenAccount,
        payer,
        1 // amount (1 for NFT)
      ),
    ];

    const { blockhash } = await connection.getLatestBlockhash('confirmed');
    
    const txMessage = new TransactionMessage({
      payerKey: payer,
      recentBlockhash: blockhash,
      instructions,
    }).compileToV0Message();

    const transaction = new VersionedTransaction(txMessage);
    transaction.sign([mintKeypair]);

    const signatures = await wallet.signAndSendTransactions({
      transactions: [transaction],
    });

    return {
      signature: signatures[0],
      mintAddress: mintKeypair.publicKey,
      metadataUri,
    };
  });
};

// Helper function to upload metadata (implement with your preferred storage)
const uploadMetadata = async (metadata: NFTMetadata): Promise<string> => {
  // Upload to IPFS, Arweave, or other decentralized storage
  // For demo purposes, return a placeholder
  return `https://example.com/metadata/${Date.now()}.json`;
};
```

### Transfer NFT

```typescript
const transferNFT = async (
  mintAddress: PublicKey,
  recipientAddress: PublicKey
): Promise<string> => {
  
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const senderAddress = new PublicKey(toByteArray(accounts[0].address));

    const senderTokenAccount = await getAssociatedTokenAddress(
      mintAddress,
      senderAddress
    );

    const recipientTokenAccount = await getAssociatedTokenAddress(
      mintAddress,
      recipientAddress
    );

    const instructions = [];

    // Create recipient token account if doesn't exist
    const recipientAccountInfo = await getTokenAccountInfo(mintAddress, recipientAddress);
    if (!recipientAccountInfo.exists) {
      instructions.push(
        createAssociatedTokenAccountInstruction(
          senderAddress,
          recipientTokenAccount,
          recipientAddress,
          mintAddress
        )
      );
    }

    // Transfer NFT (amount = 1)
    instructions.push(
      createTransferInstruction(
        senderTokenAccount,
        recipientTokenAccount,
        senderAddress,
        1 // NFT amount is always 1
      )
    );

    const { blockhash } = await connection.getLatestBlockhash('confirmed');
    
    const txMessage = new TransactionMessage({
      payerKey: senderAddress,
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

### Get User's NFTs

```typescript
interface UserNFT {
  mintAddress: string;
  tokenAccount: string;
  metadata?: any;
  image?: string;
  name?: string;
}

const getUserNFTs = async (ownerAddress: PublicKey): Promise<UserNFT[]> => {
  try {
    // Get all token accounts with balance = 1 and decimals = 0 (NFTs)
    const tokenAccounts = await connection.getParsedTokenAccountsByOwner(
      ownerAddress,
      { programId: TOKEN_PROGRAM_ID }
    );

    const nfts = tokenAccounts.value.filter(account => {
      const data = account.account.data.parsed.info;
      return data.tokenAmount.amount === '1' && data.tokenAmount.decimals === 0;
    });

    // Fetch metadata for each NFT
    const nftPromises = nfts.map(async (account) => {
      const data = account.account.data.parsed.info;
      const mintAddress = data.mint;
      
      try {
        const metadata = await getTokenMetadata(new PublicKey(mintAddress));
        
        return {
          mintAddress,
          tokenAccount: account.pubkey.toString(),
          metadata,
          name: metadata?.name,
          image: metadata?.image,
        };
      } catch (error) {
        return {
          mintAddress,
          tokenAccount: account.pubkey.toString(),
          name: `NFT ${mintAddress.slice(0, 8)}`,
        };
      }
    });

    return await Promise.all(nftPromises);
  } catch (error) {
    console.error('Error fetching NFTs:', error);
    return [];
  }
};
```

## Token Swaps

### Basic Token Swap (Manual)

```typescript
// Simple 1:1 token swap (for demo purposes)
const swapTokens = async (
  fromMint: PublicKey,
  toMint: PublicKey,
  amount: number,
  swapAuthority: PublicKey // The account that holds both token types
): Promise<string> => {
  
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const userAddress = new PublicKey(toByteArray(accounts[0].address));

    // User token accounts
    const userFromAccount = await getAssociatedTokenAddress(fromMint, userAddress);
    const userToAccount = await getAssociatedTokenAddress(toMint, userAddress);

    // Swap authority token accounts  
    const swapFromAccount = await getAssociatedTokenAddress(fromMint, swapAuthority);
    const swapToAccount = await getAssociatedTokenAddress(toMint, swapAuthority);

    const instructions = [];

    // Create user's "to" token account if needed
    const userToAccountInfo = await getTokenAccountInfo(toMint, userAddress);
    if (!userToAccountInfo.exists) {
      instructions.push(
        createAssociatedTokenAccountInstruction(
          userAddress,
          userToAccount,
          userAddress,
          toMint
        )
      );
    }

    // Transfer user's tokens to swap authority
    instructions.push(
      createTransferInstruction(
        userFromAccount,
        swapFromAccount,
        userAddress,
        amount
      )
    );

    // This would require the swap authority to sign
    // In practice, you'd use a proper swap protocol like Jupiter or Raydium
    
    const { blockhash } = await connection.getLatestBlockhash('confirmed');
    
    const txMessage = new TransactionMessage({
      payerKey: userAddress,
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

### Jupiter Swap Integration

```typescript
// Integration with Jupiter for real token swaps
const jupiterSwap = async (
  inputMint: string,
  outputMint: string,
  amount: number,
  slippageBps = 50 // 0.5%
): Promise<string> => {
  
  return await transact(async (wallet) => {
    const { accounts } = await wallet.authorize({
      identity: APP_IDENTITY,
      chain: 'solana:devnet',
    });

    const userAddress = new PublicKey(toByteArray(accounts[0].address));

    // Get quote from Jupiter API
    const quoteResponse = await fetch(
      `https://quote-api.jup.ag/v6/quote?inputMint=${inputMint}&outputMint=${outputMint}&amount=${amount}&slippageBps=${slippageBps}`
    );
    
    if (!quoteResponse.ok) {
      throw new Error('Failed to get quote');
    }
    
    const quote = await quoteResponse.json();

    // Get swap transaction from Jupiter
    const swapResponse = await fetch('https://quote-api.jup.ag/v6/swap', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        quoteResponse: quote,
        userPublicKey: userAddress.toString(),
        wrapAndUnwrapSol: true,
      }),
    });

    if (!swapResponse.ok) {
      throw new Error('Failed to get swap transaction');
    }

    const { swapTransaction } = await swapResponse.json();
    
    // Deserialize the transaction
    const transaction = VersionedTransaction.deserialize(
      Buffer.from(swapTransaction, 'base64')
    );

    const signatures = await wallet.signAndSendTransactions({
      transactions: [transaction],
    });

    return signatures[0];
  });
};
```

## Token Program Security

### Validate Token Accounts

```typescript
const validateTokenTransfer = async (
  mintAddress: PublicKey,
  fromAccount: PublicKey,
  toAccount: PublicKey,
  amount: number
): Promise<{ valid: boolean; error?: string }> => {
  
  try {
    // Check if accounts exist
    const fromInfo = await connection.getTokenAccountBalance(fromAccount);
    const toInfo = await connection.getTokenAccountBalance(toAccount);
    
    // Validate mint matches
    const fromAccountInfo = await connection.getParsedAccountInfo(fromAccount);
    const toAccountInfo = await connection.getParsedAccountInfo(toAccount);
    
    if (!fromAccountInfo.value?.data || !('parsed' in fromAccountInfo.value.data) ||
        !toAccountInfo.value?.data || !('parsed' in toAccountInfo.value.data)) {
      return { valid: false, error: 'Invalid account data' };
    }
    
    const fromMint = fromAccountInfo.value.data.parsed.info.mint;
    const toMint = toAccountInfo.value.data.parsed.info.mint;
    
    if (fromMint !== mintAddress.toString() || toMint !== mintAddress.toString()) {
      return { valid: false, error: 'Token mint mismatch' };
    }
    
    // Check sufficient balance
    if (fromInfo.value.uiAmount === null || fromInfo.value.uiAmount < amount) {
      return { valid: false, error: 'Insufficient balance' };
    }
    
    return { valid: true };
  } catch (error) {
    return { valid: false, error: error.message };
  }
};
```

### Safe Token Operations

```typescript
class SafeTokenManager {
  private connection: Connection;
  
  constructor(connection: Connection) {
    this.connection = connection;
  }

  async safeTransfer(
    mintAddress: PublicKey,
    recipientAddress: PublicKey,
    amount: number,
    decimals: number
  ): Promise<string> {
    
    // Validate inputs
    if (amount <= 0) {
      throw new Error('Amount must be positive');
    }
    
    if (!PublicKey.isOnCurve(recipientAddress)) {
      throw new Error('Invalid recipient address');
    }
    
    return await transact(async (wallet) => {
      const { accounts } = await wallet.authorize({
        identity: APP_IDENTITY,
        chain: 'solana:devnet',
      });

      const senderAddress = new PublicKey(toByteArray(accounts[0].address));

      // Validate sender has sufficient balance
      const senderBalance = await this.getTokenBalance(mintAddress, senderAddress);
      
      if (senderBalance < amount) {
        throw new Error(`Insufficient balance: ${senderBalance} < ${amount}`);
      }

      // Proceed with transfer
      return await transferTokens(mintAddress, recipientAddress, amount, decimals);
    });
  }

  private async getTokenBalance(
    mintAddress: PublicKey,
    ownerAddress: PublicKey
  ): Promise<number> {
    
    try {
      const tokenAccount = await getAssociatedTokenAddress(mintAddress, ownerAddress);
      const balance = await this.connection.getTokenAccountBalance(tokenAccount);
      return balance.value.uiAmount || 0;
    } catch {
      return 0;
    }
  }
}
```

## Error Handling

### Token-Specific Errors

```typescript
const handleTokenError = (error: any): string => {
  const message = error.message?.toLowerCase() || '';
  
  if (message.includes('insufficient funds')) {
    return 'Insufficient SOL for transaction fees';
  }
  
  if (message.includes('invalid account owner')) {
    return 'Invalid token account';
  }
  
  if (message.includes('account not found')) {
    return 'Token account does not exist';
  }
  
  if (message.includes('insufficient lamports')) {
    return 'Insufficient token balance';
  }
  
  if (message.includes('invalid mint')) {
    return 'Invalid token mint address';
  }
  
  return error.message || 'Token operation failed';
};
```

This comprehensive guide covers all major token operations in Solana mobile apps, from basic SPL token transfers to NFT creation and advanced swap integration.