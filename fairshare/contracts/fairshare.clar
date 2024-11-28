;; FairShare - Content Royalty Distribution Platform
;; Version 1.1 with Multi-Signature Support

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant PLATFORM-FEE u2) ;; 2% platform fee
(define-constant MIN-DEPOSIT u1000)
(define-constant MAX-STAKEHOLDERS u10)
(define-constant REQUIRED-APPROVALS u2) ;; Minimum approvals needed for changes

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
(define-constant ERR-ALREADY-APPROVED (err u109))
(define-constant ERR-INSUFFICIENT-APPROVALS (err u110))
(define-constant ERR-PROPOSAL-EXPIRED (err u111))

;; Data structures
(define-map content-registry
    { content-id: uint }
    {
        creator: principal,
        title: (string-ascii 256),
        stakeholder-count: uint,
        total-earnings: uint,
        status: (string-ascii 20)
    }
)

(define-map stakeholder-shares
    { content-id: uint, stakeholder: principal }
    {
        share-percentage: uint,
        total-claimed: uint
    }
)

(define-map earnings-pool
    { content-id: uint }
    {
        balance: uint,
        total-deposits: uint
    }
)

;; New data structures for multi-sig
(define-map share-change-proposals
    { proposal-id: uint }
    {
        content-id: uint,
        stakeholder: principal,
        new-share-percentage: uint,
        proposer: principal,
        approval-count: uint,
        expiry-block: uint,
        executed: bool
    }
)

(define-map proposal-approvals
    { proposal-id: uint, approver: principal }
    { approved: bool }
)

(define-data-var proposal-nonce uint u0)

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

(define-read-only (get-proposal (proposal-id uint))
    (map-get? share-change-proposals { proposal-id: proposal-id })
)

(define-read-only (get-approval-status (proposal-id uint) (approver principal))
    (map-get? proposal-approvals { proposal-id: proposal-id, approver: approver })
)

;; Register new content
(define-public (register-content 
    (content-id uint)
    (title (string-ascii 256)))
    
    (let ((existing-content (get-content-details content-id)))
        (asserts! (is-none existing-content) ERR-ALREADY-REGISTERED)
        
        (map-set content-registry
            { content-id: content-id }
            {
                creator: tx-sender,
                title: title,
                stakeholder-count: u1,
                total-earnings: u0,
                status: "active"
            }
        )
        
        (map-set stakeholder-shares
            { content-id: content-id, stakeholder: tx-sender }
            {
                share-percentage: u100,
                total-claimed: u0
            }
        )
        
        (ok true)
    )
)

;; Propose stakeholder share change
(define-public (propose-share-change 
    (content-id uint)
    (stakeholder principal)
    (new-share-percentage uint))
    
    (let (
        (content (unwrap! (get-content-details content-id) ERR-NOT-FOUND))
        (proposal-id (+ (var-get proposal-nonce) u1))
    )
        ;; Validations
        (asserts! (is-eq tx-sender (get creator content)) ERR-NOT-AUTHORIZED)
        (asserts! (<= new-share-percentage u100) ERR-INVALID-PERCENTAGE)
        
        ;; Create proposal
        (map-set share-change-proposals
            { proposal-id: proposal-id }
            {
                content-id: content-id,
                stakeholder: stakeholder,
                new-share-percentage: new-share-percentage,
                proposer: tx-sender,
                approval-count: u1,  ;; Proposer's approval counted
                expiry-block: (+ block-height u144), ;; 24 hour expiry (144 blocks)
                executed: false
            }
        )
        
        ;; Record proposer's approval
        (map-set proposal-approvals
            { proposal-id: proposal-id, approver: tx-sender }
            { approved: true }
        )
        
        ;; Increment proposal nonce
        (var-set proposal-nonce proposal-id)
        
        (ok proposal-id)
    )
)

;; Approve share change proposal
(define-public (approve-share-change (proposal-id uint))
    (let (
        (proposal (unwrap! (get-proposal proposal-id) ERR-NOT-FOUND))
        (content (unwrap! (get-content-details (get content-id proposal)) ERR-NOT-FOUND))
        (existing-approval (get-approval-status proposal-id tx-sender))
    )
        ;; Validations
        (asserts! (not (get executed proposal)) ERR-NOT-FOUND)
        (asserts! (< block-height (get expiry-block proposal)) ERR-PROPOSAL-EXPIRED)
        (asserts! (is-none existing-approval) ERR-ALREADY-APPROVED)
        
        ;; Record approval
        (map-set proposal-approvals
            { proposal-id: proposal-id, approver: tx-sender }
            { approved: true }
        )
        
        ;; Update approval count
        (map-set share-change-proposals
            { proposal-id: proposal-id }
            (merge proposal {
                approval-count: (+ (get approval-count proposal) u1)
            })
        )
        
        (ok true)
    )
)

;; Execute approved share change
(define-public (execute-share-change (proposal-id uint))
    (let (
        (proposal (unwrap! (get-proposal proposal-id) ERR-NOT-FOUND))
        (content (unwrap! (get-content-details (get content-id proposal)) ERR-NOT-FOUND))
    )
        ;; Validations
        (asserts! (not (get executed proposal)) ERR-NOT-FOUND)
        (asserts! (< block-height (get expiry-block proposal)) ERR-PROPOSAL-EXPIRED)
        (asserts! (>= (get approval-count proposal) REQUIRED-APPROVALS) ERR-INSUFFICIENT-APPROVALS)
        
        ;; Update stakeholder share
        (map-set stakeholder-shares
            { content-id: (get content-id proposal), stakeholder: (get stakeholder proposal) }
            {
                share-percentage: (get new-share-percentage proposal),
                total-claimed: u0
            }
        )
        
        ;; Mark proposal as executed
        (map-set share-change-proposals
            { proposal-id: proposal-id }
            (merge proposal { executed: true })
        )
        
        (ok true)
    )
)

;; Original functions remain unchanged
(define-public (deposit-earnings (content-id uint) (amount uint))
    (let (
        (content (unwrap! (get-content-details content-id) ERR-NOT-FOUND))
        (current-pool (default-to { balance: u0, total-deposits: u0 } 
                                (get-earnings-pool content-id)))
    )
        (asserts! (>= amount MIN-DEPOSIT) ERR-INVALID-AMOUNT)
        
        (let (
            (platform-fee (/ (* amount PLATFORM-FEE) u100))
            (net-amount (- amount platform-fee))
        )
            (try! (stx-transfer? platform-fee tx-sender CONTRACT-OWNER))
            (try! (stx-transfer? net-amount tx-sender (as-contract tx-sender)))
            
            (map-set earnings-pool
                { content-id: content-id }
                {
                    balance: (+ (get balance current-pool) net-amount),
                    total-deposits: (+ (get total-deposits current-pool) net-amount)
                }
            )
            
            (ok true)
        )
    )
)

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
            (asserts! (> claim-amount u0) ERR-ZERO-AMOUNT)
            
            (try! (as-contract (stx-transfer? claim-amount tx-sender tx-sender)))
            
            (map-set stakeholder-shares
                { content-id: content-id, stakeholder: tx-sender }
                (merge stakeholder-info {
                    total-claimed: (+ (get total-claimed stakeholder-info) claim-amount)
                })
            )
            
            (map-set earnings-pool
                { content-id: content-id }
                (merge pool { balance: (- pool-balance claim-amount) })
            )
            
            (ok claim-amount)
        )
    )
)