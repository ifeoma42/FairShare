;; FairShare - Advanced Decentralized Content Royalty Distribution Platform
;; Version 2.0

;; Constants for configuration
(define-constant CONTRACT-OWNER tx-sender)
(define-constant PLATFORM-FEE u2) ;; 2% platform fee
(define-constant MIN-DEPOSIT u1000) ;; Minimum deposit amount in uSTX
(define-constant MAX-STAKEHOLDERS u10) ;; Maximum stakeholders per content

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PERCENTAGE (err u101))
(define-constant ERR-ALREADY-REGISTERED (err u102))
(define-constant ERR-NOT-FOUND (err u103))
(define-constant ERR-TOO-MANY-STAKEHOLDERS (err u104))
(define-constant ERR-INVALID-AMOUNT (err u105))
(define-constant ERR-TOTAL-SHARE-EXCEEDED (err u106))
(define-constant ERR-ZERO-AMOUNT (err u107))
(define-constant ERR-DUPLICATE-STAKEHOLDER (err u108))

;; Data structures
(define-map content-registry
    { content-id: uint }
    {
        creator: principal,
        title: (string-ascii 256),
        description: (string-utf8 1024),
        content-type: (string-ascii 64),
        creation-date: uint,
        total-earnings: uint,
        status: (string-ascii 20),
        stakeholder-count: uint,
        metadata-url: (optional (string-utf8 256))
    }
)

(define-map stakeholder-shares
    { content-id: uint, stakeholder: principal }
    {
        share-percentage: uint,
        added-height: uint,
        last-claim-height: uint,
        total-claimed: uint
    }
)

(define-map earnings-pool
    { content-id: uint }
    {
        balance: uint,
        last-deposit-height: uint,
        total-deposits: uint
    }
)

;; SFT for tracking content ownership
(define-fungible-token content-share)

;; Read-only functions
(define-read-only (get-content-details (content-id uint))
    (map-get? content-registry { content-id: content-id })
)

(define-read-only (get-stakeholder-share (content-id uint) (stakeholder principal))
    (map-get? stakeholder-shares { content-id: content-id, stakeholder: stakeholder })
)

(define-read-only (get-earnings-pool (content-id uint))
    (map-get? earnings-pool { content-id: content-id })
)

(define-read-only (calculate-claimable-amount (content-id uint) (stakeholder principal))
    (let (
        (stakeholder-info (get-stakeholder-share content-id stakeholder))
        (pool (get-earnings-pool content-id))
    )
        (if (and (is-some stakeholder-info) (is-some pool))
            (let (
                (share-percentage (get share-percentage (unwrap! stakeholder-info ERR-NOT-FOUND)))
                (pool-balance (get balance (unwrap! pool ERR-NOT-FOUND)))
            )
                (ok (/ (* pool-balance share-percentage) u100))
            )
            ERR-NOT-FOUND
        )
    )
)

;; Register new content
(define-public (register-content 
    (content-id uint)
    (title (string-ascii 256))
    (description (string-utf8 1024))
    (content-type (string-ascii 64))
    (metadata-url (optional (string-utf8 256))))
    
    (let ((existing-content (get-content-details content-id)))
        (asserts! (is-none existing-content) ERR-ALREADY-REGISTERED)
        
        ;; Initialize content registry
        (map-set content-registry
            { content-id: content-id }
            {
                creator: tx-sender,
                title: title,
                description: description,
                content-type: content-type,
                creation-date: block-height,
                total-earnings: u0,
                status: "active",
                stakeholder-count: u1,
                metadata-url: metadata-url
            }
        )
        
        ;; Initialize creator as first stakeholder
        (map-set stakeholder-shares
            { content-id: content-id, stakeholder: tx-sender }
            {
                share-percentage: u100,
                added-height: block-height,
                last-claim-height: block-height,
                total-claimed: u0
            }
        )
        
        ;; Mint initial content shares
        (try! (ft-mint? content-share u100 tx-sender))
        
        (ok true)
    )
)

;; Add stakeholder with validation
(define-public (add-stakeholder 
    (content-id uint)
    (stakeholder principal)
    (share-percentage uint))
    
    (let (
        (content (unwrap! (get-content-details content-id) ERR-NOT-FOUND))
        (existing-share (get-stakeholder-share content-id stakeholder))
    )
        ;; Validations
        (asserts! (is-eq tx-sender (get creator content)) ERR-NOT-AUTHORIZED)
        (asserts! (is-none existing-share) ERR-DUPLICATE-STAKEHOLDER)
        (asserts! (<= share-percentage u100) ERR-INVALID-PERCENTAGE)
        (asserts! (< (get stakeholder-count content) MAX-STAKEHOLDERS) ERR-TOO-MANY-STAKEHOLDERS)
        
        ;; Calculate total shares after adding new stakeholder
        (let (
            (total-shares (+ share-percentage (get-total-shares content-id)))
        )
            (asserts! (<= total-shares u100) ERR-TOTAL-SHARE-EXCEEDED)
            
            ;; Add stakeholder
            (map-set stakeholder-shares
                { content-id: content-id, stakeholder: stakeholder }
                {
                    share-percentage: share-percentage,
                    added-height: block-height,
                    last-claim-height: block-height,
                    total-claimed: u0
                }
            )
            
            ;; Update content registry
            (map-set content-registry
                { content-id: content-id }
                (merge content { stakeholder-count: (+ (get stakeholder-count content) u1) })
            )
            
            ;; Mint shares for new stakeholder
            (try! (ft-mint? content-share share-percentage stakeholder))
            
            (ok true)
        )
    )
)

;; Deposit earnings with platform fee
(define-public (deposit-earnings (content-id uint) (amount uint))
    (let (
        (content (unwrap! (get-content-details content-id) ERR-NOT-FOUND))
        (current-pool (default-to { balance: u0, last-deposit-height: u0, total-deposits: u0 } 
                                (get-earnings-pool content-id)))
    )
        ;; Validations
        (asserts! (>= amount MIN-DEPOSIT) ERR-INVALID-AMOUNT)
        
        ;; Calculate platform fee
        (let (
            (platform-fee (/ (* amount PLATFORM-FEE) u100))
            (net-amount (- amount platform-fee))
        )
            ;; Transfer platform fee
            (try! (stx-transfer? platform-fee tx-sender CONTRACT-OWNER))
            
            ;; Transfer net amount to contract
            (try! (stx-transfer? net-amount tx-sender (as-contract tx-sender)))
            
            ;; Update earnings pool
            (map-set earnings-pool
                { content-id: content-id }
                {
                    balance: (+ (get balance current-pool) net-amount),
                    last-deposit-height: block-height,
                    total-deposits: (+ (get total-deposits current-pool) net-amount)
                }
            )
            
            (ok true)
        )
    )
)

;; Claim earnings with validation
(define-public (claim-earnings (content-id uint))
    (let (
        (stakeholder-info (unwrap! (get-stakeholder-share content-id tx-sender) ERR-NOT-AUTHORIZED))
        (pool (unwrap! (get-earnings-pool content-id) ERR-NOT-FOUND))
    )
        (let (
            (share-percentage (get share-percentage stakeholder-info))
            (pool-balance (get balance pool))
            (claim-amount (/ (* pool-balance share-percentage) u100))
        )
            ;; Validations
            (asserts! (> claim-amount u0) ERR-ZERO-AMOUNT)
            
            ;; Transfer earnings
            (try! (as-contract (stx-transfer? claim-amount tx-sender tx-sender)))
            
            ;; Update stakeholder info
            (map-set stakeholder-shares
                { content-id: content-id, stakeholder: tx-sender }
                (merge stakeholder-info {
                    last-claim-height: block-height,
                    total-claimed: (+ (get total-claimed stakeholder-info) claim-amount)
                })
            )
            
            ;; Update pool balance
            (map-set earnings-pool
                { content-id: content-id }
                (merge pool { balance: (- pool-balance claim-amount) })
            )
            
            (ok claim-amount)
        )
    )
)

;; Helper functions
(define-private (get-share-percentage (stake { content-id: uint, stakeholder: principal }))
    (default-to u0 (get share-percentage (get-stakeholder-share (get content-id stake) (get stakeholder stake))))
)

(define-private (get-total-shares (content-id uint))
    (let ((share-info (get-stakeholder-share content-id tx-sender)))
        (match share-info
            share-data (get share-percentage share-data)
            u0
        )
    )
)