# Welsh Community Pool

A 12-month locked liquidity pool that allows a Welsh token holder to team up with the Bitcoin & Stacks community to create LP positions.

## How It Works

### 1. Welsh Holder Initialization

- Welsh holder calls `initialize-welsh-pool(amount)` with their Welsh tokens
- Tokens are locked for 12 months (~52,560 Bitcoin blocks)
- Pool is now ready for community participation

### 2. Community sBTC Deposits

- Anyone can call `deposit-sbtc-for-lp(amount)` with sBTC
- Contract automatically:
  - Gets quote for required Welsh amount
  - Uses Welsh from pool + user's sBTC to create LP position
  - Tracks user's LP contribution
  - LP tokens are held in contract during lock period

### 3. Post-Lock Withdrawals (After 12 Months)

**Community Users:**

- Call `withdraw-lp-tokens()` to exit their LP position
- Receives 60% of both sBTC and Welsh from their LP
- Welsh depositor automatically gets 40% of both tokens

**Welsh Depositor:**

- Call `withdraw-remaining-welsh()` to get unused Welsh back
- Receives any Welsh not used for LP positions
- Also receives 40% of all LP proceeds when users withdraw

## Contract Functions

### Public Functions

- `initialize-welsh-pool(welsh-amount)` - Welsh holder locks tokens
- `deposit-sbtc-for-lp(sbtc-amount)` - Community creates LP with sBTC
- `withdraw-lp-tokens()` - Users exit after lock period (60/40 split)
- `withdraw-remaining-welsh()` - Welsh depositor gets unused tokens

### Read-Only Functions

- `get-pool-info()` - Pool status and metrics
- `get-user-lp-tokens(user)` - User's LP token balance
- `get-lp-quote-for-sbtc(amount)` - Preview Welsh needed for sBTC amount

## Example Flow

1. **Alice (Welsh holder):** `initialize-welsh-pool(100M Welsh)`
2. **Bob:** `deposit-sbtc-for-lp(0.1 sBTC)` → Creates LP, gets tracked
3. **Carol:** `deposit-sbtc-for-lp(0.05 sBTC)` → Creates LP, gets tracked
4. **Wait 12 months...**
5. **Bob:** `withdraw-lp-tokens()` → Gets 60% of his LP proceeds, Alice gets 40%
6. **Carol:** `withdraw-lp-tokens()` → Gets 60% of her LP proceeds, Alice gets 40%
7. **Alice:** `withdraw-remaining-welsh()` → Gets unused Welsh back

## Benefits

- **Welsh Holders:** Earn yield on large bags without needing sBTC
- **Bitcoin Community:** Access to Welsh liquidity for LP positions
- **Automatic Splitting:** 60/40 revenue share built into withdrawals
- **Time-Locked:** 12-month commitment ensures long-term liquidity

## Contract Address

`SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.welshcorgicoin-community-pool`
