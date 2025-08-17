;; /Users/owner/welsh/welshies/contracts/stx-bfaktory-sso.clar
;; STX-bfaktory Single-Sided Opportunity Contract
;; Community STX + Provider bfaktory = Shared LP rewards

;; Constants
(define-constant CONTRACT (as-contract tx-sender))

;; Errors
(define-constant ERR_UNAUTHORIZED (err u403))
(define-constant ERR_NOT_INITIALIZED (err u404))
(define-constant ERR_ALREADY_INITIALIZED (err u405))
(define-constant ERR_INSUFFICIENT_AMOUNT (err u406))
(define-constant ERR_STILL_LOCKED (err u407))
(define-constant ERR_NO_DEPOSIT (err u408))
(define-constant ERR_TOO_LATE_BRO (err u409))

;; Lock period (12 months = ~52,560 blocks)
(define-constant LOCK_PERIOD u52560)
(define-constant ENTRY_PERIOD u39420)

;; Data vars
(define-data-var bfaktory-depositor (optional principal) none)
(define-data-var creation-block uint u0)
(define-data-var initial-bfaktory-amount uint u0)
(define-data-var bfaktory-used-for-lp uint u0)
(define-data-var total-lp-tokens uint u0)

;; Track individual LP contributions
(define-map user-lp-tokens principal uint)

;; --- Initialization ---

(define-public (initialize-bfaktory-pool (bfaktory-amount uint))
  (begin
    (asserts! (is-none (var-get bfaktory-depositor)) ERR_ALREADY_INITIALIZED)
    (asserts! (> bfaktory-amount u0) ERR_INSUFFICIENT_AMOUNT)
    
    ;; Transfer bfaktory tokens to this contract
    (try! (contract-call? 'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory
           transfer bfaktory-amount tx-sender CONTRACT none))
    
    ;; Set state
    (var-set bfaktory-depositor (some tx-sender))
    (var-set creation-block burn-block-height)
    (var-set initial-bfaktory-amount bfaktory-amount)
    
    (print {
      type: "bfaktory-pool-initialized",
      depositor: tx-sender,
      bfaktory-amount: bfaktory-amount,
      unlock-block: (+ burn-block-height LOCK_PERIOD)
    })
    
    (ok true)
  )
)

;; --- Community STX Deposits ---

(define-public (deposit-stx-for-lp (stx-amount uint))
    (let (
          (amounts (calculate-amounts-for-lp stx-amount))
          (stx-needed (get stx-needed amounts))
          (bfaktory-needed (get bfaktory-needed amounts))
          ;; Transfer STX to contract (wrapped as wSTX)
          (stx-deposit (try! (stx-transfer? stx-needed tx-sender CONTRACT)))
          ;; Add liquidity to Alex pool using factor u100000000 (based on screenshot)
          (lp-result (try! (as-contract (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01 
                            add-to-position 
                            'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
                            'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory
                            u100000000  ;; factor from screenshot
                            (* stx-needed u100)  ;; convert STX to wSTX fixed format -> times 100
                            (some bfaktory-needed)))))  ;; convert to fixed format -> times 1
          (lp-tokens-received (get supply lp-result))
          (current-lp (default-to u0 (map-get? user-lp-tokens tx-sender))))

    (asserts! (is-some (var-get bfaktory-depositor)) ERR_NOT_INITIALIZED)
    (asserts! (> stx-amount u0) ERR_INSUFFICIENT_AMOUNT)
    (asserts! (< burn-block-height (+ (var-get creation-block) ENTRY_PERIOD)) ERR_TOO_LATE_BRO)
    (asserts! (not (is-eq (some tx-sender) (var-get bfaktory-depositor))) ERR_UNAUTHORIZED)

      (map-set user-lp-tokens tx-sender (+ current-lp lp-tokens-received))
      (var-set total-lp-tokens (+ (var-get total-lp-tokens) lp-tokens-received))
      (var-set bfaktory-used-for-lp (+ (var-get bfaktory-used-for-lp) bfaktory-needed))
      
      (print {
        type: "community-stx-deposit",
        user: tx-sender,
        stx-in: stx-needed,
        bfaktory-used: bfaktory-needed,
        lp-tokens: lp-tokens-received,
        unlock-block: (+ (var-get creation-block) LOCK_PERIOD)
      })
      
      (ok lp-tokens-received)
    )
  )

;; --- Withdrawals (after lock period) ---

(define-public (withdraw-lp-tokens)
  (let ((unlock-block (+ (var-get creation-block) LOCK_PERIOD))
        (user-lp (default-to u0 (map-get? user-lp-tokens tx-sender)))
        (bfaktory-depositor-principal (unwrap-panic (var-get bfaktory-depositor))))
    
    (asserts! (>= burn-block-height unlock-block) ERR_STILL_LOCKED)
    (asserts! (> user-lp u0) ERR_NO_DEPOSIT)
    
    ;; Remove liquidity from Alex pool (sends both tokens to this contract)
    (let ((remove-result (try! (as-contract (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01 
                                reduce-position
                                'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
                                'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory
                                u100000000  ;; factor
                                u100000000))))  ;; 100% of position
          ;; Get actual amounts from the position burn calculation
          (position-data (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
                               get-position-given-burn
                               'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
                               'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory
                               u100000000
                               user-lp)))
          (stx-received (get dx position-data))
          (bfaktory-received (get dy position-data))
          ;; Calculate 40-60 split (user gets 60%, bfaktory depositor gets 40%)
          (user-stx-share (/ (* stx-received u60) u100))
          (depositor-stx-share (- stx-received user-stx-share))
          (user-bfaktory-share (/ (* bfaktory-received u60) u100))
          (depositor-bfaktory-share (- bfaktory-received user-bfaktory-share))
          (user tx-sender))
        
        ;; Transfer STX to user (60%) - convert from wSTX back to STX
        (try! (as-contract (stx-transfer? (/ user-stx-share u100) CONTRACT user)))
        
        ;; Transfer bfaktory to user (60%)
        (try! (as-contract (contract-call? 'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory
               transfer user-bfaktory-share CONTRACT user none)))
        
        ;; Transfer STX to bfaktory depositor (40%)
        (try! (as-contract (stx-transfer? (/ depositor-stx-share u100) CONTRACT bfaktory-depositor-principal)))
        
        ;; Transfer bfaktory to depositor (40%)
        (try! (as-contract (contract-call? 'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory
               transfer depositor-bfaktory-share CONTRACT bfaktory-depositor-principal none)))
        
        ;; Remove from tracking
        (map-delete user-lp-tokens tx-sender)
        (var-set total-lp-tokens (- (var-get total-lp-tokens) user-lp))
        
        (print {
          type: "lp-withdrawal",
          user: tx-sender,
          lp-tokens: user-lp,
          user-stx: user-stx-share,
          user-bfaktory: user-bfaktory-share,
          depositor-stx: depositor-stx-share,
          depositor-bfaktory: depositor-bfaktory-share
        })
        
        (ok user-lp)
      )
    )
  )

(define-public (withdraw-remaining-bfaktory)
  (let ((unlock-block (+ (var-get creation-block) LOCK_PERIOD))
        (bfaktory-depositor-principal (unwrap-panic (var-get bfaktory-depositor))))
    
    (asserts! (>= burn-block-height unlock-block) ERR_STILL_LOCKED)
    (asserts! (is-eq tx-sender bfaktory-depositor-principal) ERR_UNAUTHORIZED)
    
    ;; Calculate remaining bfaktory (initial - used for LP)
    (let ((remaining-bfaktory (- (var-get initial-bfaktory-amount) (var-get bfaktory-used-for-lp))))
      
      (and (> remaining-bfaktory u0)
           (try! (as-contract (contract-call? 'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory
                  transfer remaining-bfaktory CONTRACT bfaktory-depositor-principal none))))
      
      (print {
        type: "bfaktory-withdrawal",
        amount: remaining-bfaktory
      })
      
      (ok remaining-bfaktory)
    )
  )
)

;; --- Read-Only Functions ---

(define-read-only (get-pool-info)
  {
    bfaktory-depositor: (var-get bfaktory-depositor),
    creation-block: (var-get creation-block),
    unlock-block: (+ (var-get creation-block) LOCK_PERIOD),
    entry-ends: (+ (var-get creation-block) ENTRY_PERIOD),
    is-unlocked: (>= burn-block-height (+ (var-get creation-block) LOCK_PERIOD)),
    initial-bfaktory: (var-get initial-bfaktory-amount),
    bfaktory-used: (var-get bfaktory-used-for-lp),
    bfaktory-available: (- (var-get initial-bfaktory-amount) (var-get bfaktory-used-for-lp)),
    total-lp-tokens: (var-get total-lp-tokens)
  }
)

(define-read-only (get-user-lp-tokens (user principal))
  (default-to u0 (map-get? user-lp-tokens user))
)

(define-read-only (get-quote-for-lp (stx-amount uint))
  (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01 
    get-token-given-position
    'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
    'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory
    u100000000  ;; factor
    (* stx-amount u100)  ;; convert STX to wSTX fixed
    none))

(define-read-only (calculate-amounts-for-lp (stx-amount uint))
  (let ((liquidity-quote (unwrap-panic (get-quote-for-lp stx-amount))))
    {
      stx-needed: stx-amount,
      bfaktory-needed: (get dy liquidity-quote)
    }))