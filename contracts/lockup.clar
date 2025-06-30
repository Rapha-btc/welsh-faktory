;; SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.welshcorgicoin-community-pool
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

;; Lock period (12 months = ~52,560 blocks)
(define-constant LOCK_PERIOD u52560)

;; Data vars
(define-data-var welsh-depositor (optional principal) none)
(define-data-var creation-block uint u0)
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

(define-public (deposit-sbtc-for-lp (sbtc-amount uint))
  (begin
    (asserts! (is-some (var-get welsh-depositor)) ERR_NOT_INITIALIZED)
    (asserts! (> sbtc-amount u0) ERR_INSUFFICIENT_AMOUNT)
    
    ;; Get quote to determine Welsh needed
    (let ((lp-quote (unwrap-panic (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.welshcorgicoin-faktory-pool quote sbtc-amount (some 0x02))))
          (welsh-needed (get dy lp-quote))
          (lp-result (try! (as-contract (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.welshcorgicoin-faktory-pool add-liquidity sbtc-amount))))
          (lp-tokens-received (get dk lp-result))
          (current-lp (default-to u0 (map-get? user-lp-tokens tx-sender)))
          )
        
          (map-set user-lp-tokens tx-sender (+ current-lp lp-tokens-received))
          (var-set total-lp-tokens (+ (var-get total-lp-tokens) lp-tokens-received))
          
          (print {
            type: "community-lp-deposit",
            user: tx-sender,
            sbtc-in: sbtc-amount,
            welsh-used: welsh-needed,
            lp-tokens: lp-tokens-received,
            unlock-block: (+ (var-get creation-block) LOCK_PERIOD)
          })
          
          (ok lp-tokens-received)
        )
      )
    )

;; --- Withdrawals (after lock period) ---

(define-public (withdraw-lp-tokens)
  (let ((unlock-block (+ (var-get creation-block) LOCK_PERIOD))
        (user-lp (default-to u0 (map-get? user-lp-tokens tx-sender))))
    
    (asserts! (>= burn-block-height unlock-block) ERR_STILL_LOCKED)
    (asserts! (> user-lp u0) ERR_NO_DEPOSIT)
    
    ;; Transfer LP tokens to user
    (try! (as-contract (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.welshcorgicoin-faktory-pool transfer user-lp CONTRACT tx-sender none)))
    
    ;; Remove from tracking
    (map-delete user-lp-tokens tx-sender)
    (var-set total-lp-tokens (- (var-get total-lp-tokens) user-lp))
    
    (print {
      type: "lp-withdrawal",
      user: tx-sender,
      lp-tokens: user-lp
    })
    
    (ok user-lp)
  )
)

(define-public (withdraw-remaining-welsh)
  (let ((unlock-block (+ (var-get creation-block) LOCK_PERIOD)))
    
    (asserts! (>= burn-block-height unlock-block) ERR_STILL_LOCKED)
    (asserts! (is-eq (some tx-sender) (var-get welsh-depositor)) ERR_UNAUTHORIZED)
    
    ;; Transfer any remaining Welsh to depositor
    (let ((remaining-welsh (unwrap-panic (contract-call? 'SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token get-balance CONTRACT))))
      
      (and (> remaining-welsh u0)
           (try! (as-contract (contract-call? 'SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token 
                  transfer remaining-welsh CONTRACT tx-sender none))))
      
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
    is-unlocked: (>= burn-block-height (+ (var-get creation-block) LOCK_PERIOD)),
    total-lp-tokens: (var-get total-lp-tokens),
    remaining-welsh: (default-to u0 (contract-call? 'SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token get-balance CONTRACT))
  }
)

(define-read-only (get-user-lp-tokens (user principal))
  (default-to u0 (map-get? user-lp-tokens user))
)

(define-read-only (get-lp-quote-for-sbtc (sbtc-amount uint))
  (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.welshcorgicoin-faktory-pool quote sbtc-amount (some 0x02))
)