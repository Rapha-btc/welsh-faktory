;; lockup contract
;; Simplified Community LP Pool

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
(define-data-var welsh-depositor (optional principal) none)
(define-data-var creation-block uint u0)
(define-data-var initial-welsh-amount uint u0)
(define-data-var welsh-used-for-lp uint u0)
(define-data-var total-lp-tokens uint u0)

;; Track individual LP contributions
(define-map user-lp-tokens principal uint)

;; --- Initialization ---

(define-public (initialize-welsh-pool (welsh-amount uint))
  (begin
    (asserts! (is-none (var-get welsh-depositor)) ERR_ALREADY_INITIALIZED)
    (asserts! (> welsh-amount u0) ERR_INSUFFICIENT_AMOUNT)
    
    ;; Transfer Welsh tokens to this contract
    (try! (contract-call? 'SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token 
           transfer welsh-amount tx-sender CONTRACT none))
    
    ;; Set state
    (var-set welsh-depositor (some tx-sender))
    (var-set creation-block burn-block-height)
    (var-set initial-welsh-amount welsh-amount)
    
    (print {
      type: "welsh-pool-initialized",
      depositor: tx-sender,
      welsh-amount: welsh-amount,
      unlock-block: (+ burn-block-height LOCK_PERIOD)
    })
    
    (ok true)
  )
)

;; --- Community LP Deposits ---

(define-public (deposit-sbtc-for-lp (lp-amount uint))
    (let (
          (amounts (calculate-amounts-for-lp lp-amount))
          (sbtc-needed (get sbtc-needed amounts))
          (welsh-needed (get welsh-needed amounts))
          (deposit (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token 
                            transfer sbtc-needed tx-sender CONTRACT none)))
          (lp-result (try! (as-contract (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.welshcorgicoin-faktory-pool add-liquidity lp-amount))))
          (lp-tokens-received (get dk lp-result))
          (current-lp (default-to u0 (map-get? user-lp-tokens tx-sender))))

    (asserts! (is-some (var-get welsh-depositor)) ERR_NOT_INITIALIZED)
    (asserts! (> lp-amount u0) ERR_INSUFFICIENT_AMOUNT)
    (asserts! (< burn-block-height (+ (var-get creation-block) ENTRY_PERIOD)) ERR_TOO_LATE_BRO)
    (asserts! (not (is-eq (some tx-sender) (var-get welsh-depositor))) ERR_UNAUTHORIZED) ;; else err u2 in withdrawing

      (map-set user-lp-tokens tx-sender (+ current-lp lp-tokens-received))
      (var-set total-lp-tokens (+ (var-get total-lp-tokens) lp-tokens-received))
      (var-set welsh-used-for-lp (+ (var-get welsh-used-for-lp) welsh-needed))
      
      (print {
        type: "community-lp-deposit",
        user: tx-sender,
        sbtc-in: sbtc-needed,
        welsh-used: welsh-needed,
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
        (welsh-depositor-principal (unwrap-panic (var-get welsh-depositor))))
    
    (asserts! (>= burn-block-height unlock-block) ERR_STILL_LOCKED)
    (asserts! (> user-lp u0) ERR_NO_DEPOSIT)
    
    ;; Remove liquidity from pool (sends both tokens to this contract)
    (let ((remove-result (try! (as-contract (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.welshcorgicoin-faktory-pool remove-liquidity user-lp))))
          (sbtc-received (get dx remove-result))
          (welsh-received (get dy remove-result))
          (user-sbtc-share (/ (* sbtc-received u60) u100))       ;; Calculate 40-60 split (user gets 60%, welsh depositor gets 40%)
          (depositor-sbtc-share (- sbtc-received user-sbtc-share))
          (user-welsh-share (/ (* welsh-received u60) u100))
          (depositor-welsh-share (- welsh-received user-welsh-share))
          (user tx-sender)
          )
        
        ;; Transfer to user (60%)
        (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token 
               transfer user-sbtc-share CONTRACT user none)))
        (try! (as-contract (contract-call? 'SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token 
               transfer user-welsh-share CONTRACT user none)))
        
        ;; Transfer to welsh depositor (40%)
        (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token 
               transfer depositor-sbtc-share CONTRACT welsh-depositor-principal none)))
        (try! (as-contract (contract-call? 'SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token 
               transfer depositor-welsh-share CONTRACT welsh-depositor-principal none)))
        
        ;; Remove from tracking
        (map-delete user-lp-tokens tx-sender)
        (var-set total-lp-tokens (- (var-get total-lp-tokens) user-lp))
        
        (print {
          type: "lp-withdrawal",
          user: tx-sender,
          lp-tokens: user-lp,
          user-sbtc: user-sbtc-share,
          user-welsh: user-welsh-share,
          depositor-sbtc: depositor-sbtc-share,
          depositor-welsh: depositor-welsh-share
        })
        
        (ok user-lp)
      )
    )
  )

(define-public (withdraw-remaining-welsh)
  (let ((unlock-block (+ (var-get creation-block) LOCK_PERIOD))
        (welsh-depositor-principal (unwrap-panic (var-get welsh-depositor)))
      )
    
    (asserts! (>= burn-block-height unlock-block) ERR_STILL_LOCKED)
    (asserts! (is-eq tx-sender welsh-depositor-principal) ERR_UNAUTHORIZED)
    
    ;; Calculate remaining Welsh (initial - used for LP)
    (let ((remaining-welsh (- (var-get initial-welsh-amount) (var-get welsh-used-for-lp))))
      
      (and (> remaining-welsh u0)
           (try! (as-contract (contract-call? 'SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token 
                  transfer remaining-welsh CONTRACT welsh-depositor-principal none))))
      
      (print {
        type: "welsh-withdrawal",
        amount: remaining-welsh
      })
      
      (ok remaining-welsh)
    )
  )
)

;; --- Read-Only Functions ---

(define-read-only (get-pool-info)
  {
    welsh-depositor: (var-get welsh-depositor),
    creation-block: (var-get creation-block),
    unlock-block: (+ (var-get creation-block) LOCK_PERIOD),
    entry-ends: (+ (var-get creation-block) ENTRY_PERIOD),
    is-unlocked: (>= burn-block-height (+ (var-get creation-block) LOCK_PERIOD)),
    initial-welsh: (var-get initial-welsh-amount),
    welsh-used: (var-get welsh-used-for-lp),
    welsh-available: (- (var-get initial-welsh-amount) (var-get welsh-used-for-lp)),
    total-lp-tokens: (var-get total-lp-tokens)
  }
)

(define-read-only (get-user-lp-tokens (user principal))
  (default-to u0 (map-get? user-lp-tokens user))
)

(define-read-only (get-quote-for-lp (lp-amount uint))
  (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.welshcorgicoin-faktory-pool quote lp-amount (some 0x02))
)

(define-read-only (calculate-amounts-for-lp (lp-amount uint))
  (let ((liquidity-quote (unwrap-panic (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.welshcorgicoin-faktory-pool quote lp-amount (some 0x02)))))
    {
      sbtc-needed: (get dx liquidity-quote),
      welsh-needed: (get dy liquidity-quote)
    }))