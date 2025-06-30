This contract implements the community LP pool concept you described:

**Key Features:**

1. **Philip (Welsh Depositor):**

   - Calls `initialize-pool` with 100M Welsh tokens
   - Locks tokens for 12 months (52,560 blocks)
   - After unlock, gets 50% back via `withdraw-welsh`

2. **Community (sBTC Depositors):**

   - Multiple users can call `deposit-sbtc` with any amount
   - Each deposit tracked individually in `sbtc-deposits` map
   - After unlock, each gets 50% back via `withdraw-sbtc`

3. **LP Creation:**

   - After unlock period, anyone can call `create-lp-position`
   - Uses remaining 50% of both Welsh and sBTC to create LP in the existing pool
   - LP tokens go to this contract (could be modified to distribute)

4. **Tracking:**
   - Maps track all individual deposits
   - Read-only functions provide pool status
   - Events logged for all major actions

**Usage Flow:**

1. Philip: `initialize-pool(100000000000000)` // 100M Welsh
2. Users: `deposit-sbtc(amount)` // Multiple deposits
3. Wait 12 months...
4. `create-lp-position()` // Creates LP with 50% of each token
5. Users: `withdraw-sbtc()` + Philip: `withdraw-welsh()` // Get 50% back

Would you like me to modify any part of this design?
