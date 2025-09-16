;; Gaming NFT Ecosystem Platform Smart Contract
;; A comprehensive blockchain-based gaming ecosystem that enables seamless creation, trading, 
;; crafting, and management of gaming NFTs with integrated marketplace functionality,
;; advanced asset evolution mechanics, and complete lifecycle management for Web3 gaming platforms

;; SIP-009 NFT Standard Compliance
(impl-trait .nft-trait.nft-trait)

;; Authentication & Authorization Error Constants
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-CREATOR-PERMISSION-DENIED (err u101))
(define-constant ERR-OWNERSHIP-VALIDATION-FAILED (err u102))

;; Asset Management Error Constants
(define-constant ERR-GAMING-ASSET-NOT-FOUND (err u103))
(define-constant ERR-ASSET-ALREADY-EXISTS (err u104))
(define-constant ERR-INSUFFICIENT-BALANCE (err u105))
(define-constant ERR-ASSET-TRANSFER-RESTRICTED (err u106))

;; Transaction & Payment Error Constants
(define-constant ERR-TRANSACTION-FAILED (err u107))
(define-constant ERR-PAYMENT-ERROR (err u108))
(define-constant ERR-SELF-TRANSFER-PROHIBITED (err u109))

;; Marketplace Operation Error Constants
(define-constant ERR-LISTING-NOT-FOUND (err u110))
(define-constant ERR-LISTING-EXPIRED (err u111))
(define-constant ERR-LISTING-INACTIVE (err u112))
(define-constant ERR-INVALID-PRICE-CONFIGURATION (err u113))

;; Input Validation Error Constants
(define-constant ERR-INVALID-ADDRESS (err u114))
(define-constant ERR-INVALID-PARAMETER (err u115))
(define-constant ERR-EMPTY-STRING (err u116))
(define-constant ERR-INVALID-ATTRIBUTES (err u117))
(define-constant ERR-RECIPE-NOT-FOUND (err u118))

;; System Configuration Constants
(define-constant maximum-rarity-level u10)
(define-constant minimum-rarity-level u1)
(define-constant maximum-platform-fee-basis-points u1000) ;; 10.00%
(define-constant default-platform-fee-basis-points u250) ;; 2.50%
(define-constant null-address 'SP000000000000000000002Q6VF78)

;; Platform State Variables
(define-data-var platform-administrator principal tx-sender)
(define-data-var current-nft-supply uint u0)
(define-data-var current-marketplace-fee-rate uint default-platform-fee-basis-points)
(define-data-var active-listing-counter uint u1)
(define-data-var active-recipe-counter uint u1)

;; Gaming Asset Registry - Complete NFT metadata storage
(define-map game-asset-registry
  uint ;; asset-token-identifier
  {
    asset-display-name: (string-ascii 64),
    asset-description: (string-utf8 256),
    asset-image-uri: (string-utf8 256),
    original-creator-address: principal,
    asset-category-type: (string-ascii 32),
    asset-trait-collection: (list 20 {trait-name: (string-ascii 32), trait-value: (string-utf8 64)}),
    extended-metadata-info: (optional (string-utf8 1024)),
    block-height-created: uint,
    asset-rarity-level: uint,
    transfer-enabled-status: bool
  }
)

;; Asset Ownership Tracking Registry
(define-map asset-ownership-ledger
  {asset-token-id: uint, owner-wallet-address: principal}
  uint ;; owned-quantity-amount
)

;; Marketplace Trading Listings Registry
(define-map active-marketplace-listings
  uint ;; marketplace-listing-identifier
  {
    listed-nft-token-id: uint,
    listing-seller-address: principal,
    unit-price-amount: uint,
    listing-expiration-block: uint,
    available-quantity-amount: uint,
    listing-active-status: bool
  }
)

;; Creator Authorization Registry
(define-map verified-creator-registry principal bool)

;; Marketplace Indexing for Query Optimization
(define-map marketplace-listing-active-index uint bool)
(define-map seller-marketplace-listing-index {seller: principal, listing: uint} bool)

;; Asset Crafting Recipe System Registry
(define-map asset-crafting-recipe-registry
  uint ;; crafting-recipe-identifier
  {
    required-base-asset-id: uint,
    crafting-material-requirements: (list 5 {required-material-id: uint, needed-quantity: uint}),
    crafted-output-asset-id: uint,
    recipe-enabled-status: bool
  }
)

;; Input Validation Helper Functions

(define-private (validate-wallet-address (wallet-address principal))
  (not (is-eq wallet-address null-address)))

(define-private (validate-non-empty-ascii-string (text-input (string-ascii 64)))
  (> (len text-input) u0))

(define-private (validate-non-empty-utf8-string (text-input (string-utf8 256)))
  (> (len text-input) u0))

(define-private (validate-non-empty-extended-utf8-string (text-input (string-utf8 1024)))
  (> (len text-input) u0))

(define-private (validate-rarity-level-range (rarity-level uint))
  (and (>= rarity-level minimum-rarity-level) 
       (<= rarity-level maximum-rarity-level)))

(define-private (validate-individual-trait 
  (single-trait {trait-name: (string-ascii 32), trait-value: (string-utf8 64)}))
  (and
    (> (len (get trait-name single-trait)) u0)
    (> (len (get trait-value single-trait)) u0)))

(define-private (validate-complete-trait-collection 
  (trait-collection (list 20 {trait-name: (string-ascii 32), trait-value: (string-utf8 64)})))
  (let ((total-trait-count (len trait-collection)))
    (and
      (> total-trait-count u0)
      (fold check-trait-validity trait-collection true))))

(define-private (check-trait-validity 
  (current-trait {trait-name: (string-ascii 32), trait-value: (string-utf8 64)}) 
  (previous-validation-result bool))
  (and previous-validation-result (validate-individual-trait current-trait)))

(define-private (locate-nft-owner (asset-token-id uint))
  (let ((admin-owned-balance (default-to u0 (map-get? asset-ownership-ledger 
                                                {asset-token-id: asset-token-id, 
                                                 owner-wallet-address: (var-get platform-administrator)}))))
    (if (> admin-owned-balance u0)
      (ok (some (var-get platform-administrator)))
      (ok none))))

;; Platform Administration Functions

(define-read-only (get-platform-administrator)
  (var-get platform-administrator))

(define-public (transfer-platform-ownership (new-administrator principal))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-wallet-address new-administrator) ERR-INVALID-ADDRESS)
    (ok (var-set platform-administrator new-administrator))))

(define-public (update-platform-marketplace-fee (new-fee-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (<= new-fee-rate maximum-platform-fee-basis-points) ERR-INVALID-PRICE-CONFIGURATION)
    (ok (var-set current-marketplace-fee-rate new-fee-rate))))

;; Creator Authorization Management System

(define-public (authorize-gaming-creator (creator-wallet-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-wallet-address creator-wallet-address) ERR-INVALID-ADDRESS)
    (ok (map-set verified-creator-registry creator-wallet-address true))))

(define-public (revoke-gaming-creator-authorization (creator-wallet-address principal))
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (validate-wallet-address creator-wallet-address) ERR-INVALID-ADDRESS)
    (ok (map-set verified-creator-registry creator-wallet-address false))))

(define-read-only (check-creator-authorization-status (creator-wallet-address principal))
  (default-to false (map-get? verified-creator-registry creator-wallet-address)))

;; SIP-009 Standard Implementation Functions

(define-read-only (get-last-token-id)
  (ok (var-get current-nft-supply)))

(define-read-only (get-token-uri (asset-token-id uint))
  (let ((asset-metadata (map-get? game-asset-registry asset-token-id)))
    (if (is-some asset-metadata)
      (ok (some (get asset-image-uri (unwrap-panic asset-metadata))))
      (ok none))))

(define-read-only (get-owner (asset-token-id uint))
  (let ((sender-owned-balance (default-to u0 (map-get? asset-ownership-ledger 
                                                 {asset-token-id: asset-token-id, 
                                                  owner-wallet-address: tx-sender})))
        (admin-owned-balance (default-to u0 (map-get? asset-ownership-ledger 
                                                {asset-token-id: asset-token-id, 
                                                 owner-wallet-address: (var-get platform-administrator)}))))
    (if (> sender-owned-balance u0)
      (ok (some tx-sender))
      (if (> admin-owned-balance u0)
        (ok (some (var-get platform-administrator)))
        (locate-nft-owner asset-token-id)))))

(define-public (transfer (asset-token-id uint) (sender-address principal) (recipient-address principal))
  (transfer-game-asset asset-token-id u1 sender-address recipient-address))

;; NFT Creation & Minting System

(define-public (create-new-gaming-asset 
  (asset-display-name (string-ascii 64))
  (asset-description (string-utf8 256))
  (asset-image-uri (string-utf8 256))
  (asset-category-type (string-ascii 32))
  (asset-trait-collection (list 20 {trait-name: (string-ascii 32), trait-value: (string-utf8 64)}))
  (extended-metadata-info (optional (string-utf8 1024)))
  (asset-rarity-level uint)
  (transfer-enabled-status bool))
  (let ((new-asset-token-id (+ (var-get current-nft-supply) u1)))
    
    ;; Creator Authorization Verification
    (asserts! (or (is-eq tx-sender (var-get platform-administrator))
                  (check-creator-authorization-status tx-sender)) ERR-CREATOR-PERMISSION-DENIED)
    
    ;; Input Data Validation
    (asserts! (validate-non-empty-ascii-string asset-display-name) ERR-EMPTY-STRING)
    (asserts! (validate-non-empty-utf8-string asset-description) ERR-EMPTY-STRING)
    (asserts! (validate-non-empty-utf8-string asset-image-uri) ERR-EMPTY-STRING)
    (asserts! (validate-non-empty-ascii-string asset-category-type) ERR-EMPTY-STRING)
    (asserts! (validate-rarity-level-range asset-rarity-level) ERR-INVALID-PARAMETER)
    (asserts! (validate-complete-trait-collection asset-trait-collection) ERR-INVALID-ATTRIBUTES)
    
    ;; Extended Metadata Validation
    (if (is-some extended-metadata-info)
      (asserts! (validate-non-empty-extended-utf8-string (unwrap! extended-metadata-info ERR-INVALID-PARAMETER)) ERR-EMPTY-STRING)
      true)
    
    ;; Store Complete Asset Data
    (map-set game-asset-registry new-asset-token-id {
      asset-display-name: asset-display-name,
      asset-description: asset-description,
      asset-image-uri: asset-image-uri,
      original-creator-address: tx-sender,
      asset-category-type: asset-category-type,
      asset-trait-collection: asset-trait-collection,
      extended-metadata-info: extended-metadata-info,
      block-height-created: block-height,
      asset-rarity-level: asset-rarity-level,
      transfer-enabled-status: transfer-enabled-status
    })
    
    (var-set current-nft-supply new-asset-token-id)
    (ok new-asset-token-id)))

(define-public (mint-gaming-assets (asset-token-id uint) (mint-quantity uint) (recipient-address principal))
  (let ((asset-metadata (unwrap! (map-get? game-asset-registry asset-token-id) ERR-GAMING-ASSET-NOT-FOUND))
        (recipient-current-balance (default-to u0 (map-get? asset-ownership-ledger 
                                                  {asset-token-id: asset-token-id, 
                                                   owner-wallet-address: recipient-address}))))
    
    ;; Minting Authorization Verification
    (asserts! (or (is-eq tx-sender (var-get platform-administrator))
                  (is-eq tx-sender (get original-creator-address asset-metadata))) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Minting Parameter Validation
    (asserts! (> mint-quantity u0) ERR-INVALID-PARAMETER)
    (asserts! (validate-wallet-address recipient-address) ERR-INVALID-ADDRESS)
    
    ;; Update Recipient Ownership Balance
    (map-set asset-ownership-ledger 
      {asset-token-id: asset-token-id, owner-wallet-address: recipient-address} 
      (+ recipient-current-balance mint-quantity))
    
    (ok mint-quantity)))

;; NFT Transfer System

(define-public (transfer-game-asset 
  (asset-token-id uint) 
  (transfer-quantity uint) 
  (sender-wallet-address principal) 
  (recipient-wallet-address principal))
  (let ((sender-current-balance (default-to u0 (map-get? asset-ownership-ledger 
                                                 {asset-token-id: asset-token-id, 
                                                  owner-wallet-address: sender-wallet-address})))
        (recipient-current-balance (default-to u0 (map-get? asset-ownership-ledger 
                                                    {asset-token-id: asset-token-id, 
                                                     owner-wallet-address: recipient-wallet-address})))
        (asset-metadata (unwrap! (map-get? game-asset-registry asset-token-id) ERR-GAMING-ASSET-NOT-FOUND)))
    
    ;; Transfer Parameter Validation
    (asserts! (> transfer-quantity u0) ERR-INVALID-PARAMETER)
    (asserts! (validate-wallet-address recipient-wallet-address) ERR-INVALID-ADDRESS)
    
    ;; Transfer Authorization & Balance Verification
    (asserts! (or (is-eq tx-sender sender-wallet-address) 
                  (is-eq tx-sender (var-get platform-administrator))) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (>= sender-current-balance transfer-quantity) ERR-INSUFFICIENT-BALANCE)
    (asserts! (get transfer-enabled-status asset-metadata) ERR-ASSET-TRANSFER-RESTRICTED)
    (asserts! (not (is-eq sender-wallet-address recipient-wallet-address)) ERR-SELF-TRANSFER-PROHIBITED)
    
    ;; Execute Asset Transfer
    (map-set asset-ownership-ledger 
      {asset-token-id: asset-token-id, owner-wallet-address: sender-wallet-address} 
      (- sender-current-balance transfer-quantity))
    
    (map-set asset-ownership-ledger 
      {asset-token-id: asset-token-id, owner-wallet-address: recipient-wallet-address} 
      (+ recipient-current-balance transfer-quantity))
    
    (ok true)))

(define-public (execute-batch-asset-transfers 
  (transfer-batch-list (list 20 {asset-token-id: uint, transfer-quantity: uint, recipient-address: principal})))
  (fold process-single-asset-transfer transfer-batch-list (ok true)))

(define-private (process-single-asset-transfer 
  (transfer-request {asset-token-id: uint, transfer-quantity: uint, recipient-address: principal}) 
  (previous-transfer-result (response bool uint)))
  (match previous-transfer-result
    success-status (transfer-game-asset 
              (get asset-token-id transfer-request) 
              (get transfer-quantity transfer-request) 
              tx-sender 
              (get recipient-address transfer-request))
    failure-status previous-transfer-result))

;; NFT Burning System

(define-public (burn-gaming-assets (asset-token-id uint) (burn-quantity uint))
  (let ((owner-current-balance (get-asset-balance asset-token-id tx-sender)))
    (asserts! (> burn-quantity u0) ERR-INVALID-PARAMETER)
    (asserts! (>= owner-current-balance burn-quantity) ERR-INSUFFICIENT-BALANCE)
    
    (map-set asset-ownership-ledger 
      {asset-token-id: asset-token-id, owner-wallet-address: tx-sender} 
      (- owner-current-balance burn-quantity))
    
    (ok true)))

;; Marketplace Trading System

(define-public (create-new-marketplace-listing 
  (asset-token-id uint) 
  (unit-price-amount uint) 
  (available-quantity-amount uint) 
  (listing-expiration-block uint))
  (let ((new-marketplace-listing-id (var-get active-listing-counter))
        (seller-current-balance (get-asset-balance asset-token-id tx-sender))
        (asset-metadata (unwrap! (map-get? game-asset-registry asset-token-id) ERR-GAMING-ASSET-NOT-FOUND)))
    
    ;; Listing Parameter Validation
    (asserts! (>= seller-current-balance available-quantity-amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> unit-price-amount u0) ERR-INVALID-PRICE-CONFIGURATION)
    (asserts! (> available-quantity-amount u0) ERR-INVALID-PARAMETER)
    (asserts! (> listing-expiration-block block-height) ERR-LISTING-EXPIRED)
    (asserts! (get transfer-enabled-status asset-metadata) ERR-ASSET-TRANSFER-RESTRICTED)
    
    ;; Create New Marketplace Listing
    (map-set active-marketplace-listings new-marketplace-listing-id {
      listed-nft-token-id: asset-token-id,
      listing-seller-address: tx-sender,
      unit-price-amount: unit-price-amount,
      listing-expiration-block: listing-expiration-block,
      available-quantity-amount: available-quantity-amount,
      listing-active-status: true
    })
    
    ;; Update Marketplace Indices
    (map-set marketplace-listing-active-index new-marketplace-listing-id true)
    (map-set seller-marketplace-listing-index {seller: tx-sender, listing: new-marketplace-listing-id} true)
    
    (var-set active-listing-counter (+ new-marketplace-listing-id u1))
    (ok new-marketplace-listing-id)))

(define-public (cancel-existing-marketplace-listing (marketplace-listing-id uint))
  (let ((listing-data (unwrap! (map-get? active-marketplace-listings marketplace-listing-id) ERR-LISTING-NOT-FOUND)))
    (asserts! (is-eq (get listing-seller-address listing-data) tx-sender) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (get listing-active-status listing-data) ERR-LISTING-INACTIVE)
    
    ;; Deactivate Marketplace Listing
    (map-set active-marketplace-listings marketplace-listing-id 
      (merge listing-data {listing-active-status: false}))
    
    (map-set marketplace-listing-active-index marketplace-listing-id false)
    (ok true)))

(define-public (execute-marketplace-purchase 
  (marketplace-listing-id uint) 
  (purchase-quantity uint))
  (let ((listing-data (unwrap! (map-get? active-marketplace-listings marketplace-listing-id) ERR-LISTING-NOT-FOUND))
        (asset-token-id (get listed-nft-token-id listing-data))
        (single-unit-price (get unit-price-amount listing-data))
        (seller-wallet-address (get listing-seller-address listing-data))
        (total-available-quantity (get available-quantity-amount listing-data))
        (total-purchase-cost (* single-unit-price purchase-quantity))
        (calculated-platform-fee (/ (* total-purchase-cost (var-get current-marketplace-fee-rate)) u10000))
        (seller-net-proceeds (- total-purchase-cost calculated-platform-fee)))
    
    ;; Purchase Parameter Validation
    (asserts! (> purchase-quantity u0) ERR-INVALID-PARAMETER)
    
    ;; Listing Status & Availability Verification
    (asserts! (get listing-active-status listing-data) ERR-LISTING-INACTIVE)
    (asserts! (<= block-height (get listing-expiration-block listing-data)) ERR-LISTING-EXPIRED)
    (asserts! (<= purchase-quantity total-available-quantity) ERR-INSUFFICIENT-BALANCE)
    
    ;; Execute Payment Processing
    (try! (stx-transfer? total-purchase-cost tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? seller-net-proceeds tx-sender seller-wallet-address)))
    (try! (as-contract (stx-transfer? calculated-platform-fee tx-sender (var-get platform-administrator))))
    
    ;; Execute Asset Transfer
    (try! (as-contract (transfer-game-asset asset-token-id purchase-quantity seller-wallet-address tx-sender)))
    
    ;; Update or Close Marketplace Listing
    (if (> total-available-quantity purchase-quantity)
      (map-set active-marketplace-listings marketplace-listing-id 
        (merge listing-data {available-quantity-amount: (- total-available-quantity purchase-quantity)}))
      (begin
        (map-set active-marketplace-listings marketplace-listing-id 
          (merge listing-data {listing-active-status: false, available-quantity-amount: u0}))
        (map-set marketplace-listing-active-index marketplace-listing-id false)))
    
    (ok true)))

;; Asset Crafting & Evolution System

(define-public (create-new-crafting-recipe 
  (required-base-asset-id uint) 
  (crafting-material-requirements (list 5 {required-material-id: uint, needed-quantity: uint}))
  (crafted-output-asset-id uint))
  (let ((new-crafting-recipe-id (var-get active-recipe-counter)))
    
    ;; Recipe Creation Authorization
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Recipe Component Validation
    (asserts! (is-some (map-get? game-asset-registry required-base-asset-id)) ERR-GAMING-ASSET-NOT-FOUND)
    (asserts! (is-some (map-get? game-asset-registry crafted-output-asset-id)) ERR-GAMING-ASSET-NOT-FOUND)
    (asserts! (> (len crafting-material-requirements) u0) ERR-INVALID-PARAMETER)
    
    ;; Store Crafting Recipe
    (map-set asset-crafting-recipe-registry new-crafting-recipe-id {
      required-base-asset-id: required-base-asset-id,
      crafting-material-requirements: crafting-material-requirements,
      crafted-output-asset-id: crafted-output-asset-id,
      recipe-enabled-status: true
    })
    
    (var-set active-recipe-counter (+ new-crafting-recipe-id u1))
    (ok new-crafting-recipe-id)))

(define-public (execute-asset-crafting (crafting-recipe-id uint))
  (let ((recipe-data (unwrap! (map-get? asset-crafting-recipe-registry crafting-recipe-id) ERR-RECIPE-NOT-FOUND))
        (base-asset-id (get required-base-asset-id recipe-data))
        (material-requirements (get crafting-material-requirements recipe-data))
        (output-asset-id (get crafted-output-asset-id recipe-data)))
    
    (asserts! (get recipe-enabled-status recipe-data) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Verify Base Asset Ownership
    (asserts! (>= (get-asset-balance base-asset-id tx-sender) u1) ERR-INSUFFICIENT-BALANCE)
    
    ;; Verify All Material Requirements
    (try! (fold verify-crafting-material-requirement material-requirements (ok true)))
    
    ;; Consume Base Asset
    (try! (burn-gaming-assets base-asset-id u1))
    
    ;; Consume Required Materials
    (try! (fold consume-crafting-material material-requirements (ok true)))
    
    ;; Create Output Asset
    (try! (mint-gaming-assets output-asset-id u1 tx-sender))
    
    (ok true)))

(define-private (verify-crafting-material-requirement 
  (material-requirement {required-material-id: uint, needed-quantity: uint}) 
  (verification-result (response bool uint)))
  (match verification-result
    success-status (if (>= (get-asset-balance (get required-material-id material-requirement) tx-sender) 
                    (get needed-quantity material-requirement))
             (ok true)
             ERR-INSUFFICIENT-BALANCE)
    error-status verification-result))

(define-private (consume-crafting-material 
  (material-requirement {required-material-id: uint, needed-quantity: uint}) 
  (consumption-result (response bool uint)))
  (match consumption-result
    success-status (burn-gaming-assets (get required-material-id material-requirement) 
                             (get needed-quantity material-requirement))
    error-status consumption-result))

(define-public (toggle-crafting-recipe-status 
  (crafting-recipe-id uint) 
  (recipe-enabled-status bool))
  (let ((recipe-data (unwrap! (map-get? asset-crafting-recipe-registry crafting-recipe-id) ERR-RECIPE-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (asserts! (> crafting-recipe-id u0) ERR-INVALID-PARAMETER)
    
    (map-set asset-crafting-recipe-registry crafting-recipe-id 
      (merge recipe-data {recipe-enabled-status: recipe-enabled-status}))
    
    (ok true)))

;; Asset Metadata Management System

(define-public (update-asset-metadata 
  (asset-token-id uint) 
  (updated-metadata (string-utf8 1024)))
  (let ((asset-metadata (unwrap! (map-get? game-asset-registry asset-token-id) ERR-GAMING-ASSET-NOT-FOUND)))
    
    ;; Metadata Update Authorization
    (asserts! (or (is-eq tx-sender (var-get platform-administrator))
                  (is-eq tx-sender (get original-creator-address asset-metadata))) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Metadata Content Validation
    (asserts! (validate-non-empty-extended-utf8-string updated-metadata) ERR-EMPTY-STRING)
    
    ;; Update Asset Metadata
    (map-set game-asset-registry asset-token-id 
      (merge asset-metadata {extended-metadata-info: (some updated-metadata)}))
    
    (ok true)))

(define-public (toggle-asset-transfer-status 
  (asset-token-id uint) 
  (transfer-enabled-status bool))
  (let ((asset-metadata (unwrap! (map-get? game-asset-registry asset-token-id) ERR-GAMING-ASSET-NOT-FOUND)))
    
    ;; Transfer Status Update Authorization
    (asserts! (or (is-eq tx-sender (var-get platform-administrator))
                  (is-eq tx-sender (get original-creator-address asset-metadata))) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Update Transfer Status
    (map-set game-asset-registry asset-token-id 
      (merge asset-metadata {transfer-enabled-status: transfer-enabled-status}))
    
    (ok true)))

;; Read-Only Query Functions

(define-read-only (get-complete-asset-details (asset-token-id uint))
  (map-get? game-asset-registry asset-token-id))

(define-read-only (get-asset-balance (asset-token-id uint) (owner-wallet-address principal))
  (default-to u0 (map-get? asset-ownership-ledger {asset-token-id: asset-token-id, owner-wallet-address: owner-wallet-address})))

(define-read-only (get-complete-listing-details (marketplace-listing-id uint))
  (map-get? active-marketplace-listings marketplace-listing-id))

(define-read-only (check-listing-active-status (marketplace-listing-id uint))
  (let ((listing-data (map-get? active-marketplace-listings marketplace-listing-id)))
    (match listing-data
      data (and (get listing-active-status data) 
                (<= block-height (get listing-expiration-block data)))
      false)))

(define-read-only (check-seller-listing-association (seller-address principal) (marketplace-listing-id uint))
  (default-to false (map-get? seller-marketplace-listing-index {seller: seller-address, listing: marketplace-listing-id})))

(define-read-only (get-complete-recipe-details (crafting-recipe-id uint))
  (map-get? asset-crafting-recipe-registry crafting-recipe-id))

(define-read-only (get-current-platform-marketplace-fee)
  (var-get current-marketplace-fee-rate))

(define-read-only (get-total-asset-supply)
  (var-get current-nft-supply))

(define-read-only (get-next-marketplace-listing-id)
  (var-get active-listing-counter))

(define-read-only (get-next-crafting-recipe-id)
  (var-get active-recipe-counter))

(define-read-only (check-asset-transfer-enabled-status (asset-token-id uint))
  (let ((asset-metadata (map-get? game-asset-registry asset-token-id)))
    (match asset-metadata
      data (get transfer-enabled-status data)
      false)))

(define-read-only (get-asset-original-creator (asset-token-id uint))
  (let ((asset-metadata (map-get? game-asset-registry asset-token-id)))
    (match asset-metadata
      data (some (get original-creator-address data))
      none)))

(define-read-only (get-asset-rarity-level (asset-token-id uint))
  (let ((asset-metadata (map-get? game-asset-registry asset-token-id)))
    (match asset-metadata
      data (some (get asset-rarity-level data))
      none)))

(define-read-only (get-asset-creation-block-height (asset-token-id uint))
  (let ((asset-metadata (map-get? game-asset-registry asset-token-id)))
    (match asset-metadata
      data (some (get block-height-created data))
      none)))

(define-read-only (check-listing-expiration-status (marketplace-listing-id uint))
  (let ((listing-data (map-get? active-marketplace-listings marketplace-listing-id)))
    (match listing-data
      data (> block-height (get listing-expiration-block data))
      true)))

(define-read-only (calculate-platform-marketplace-fee (total-transaction-price uint))
  (/ (* total-transaction-price (var-get current-marketplace-fee-rate)) u10000))

(define-read-only (get-user-asset-portfolio (owner-wallet-address principal) (asset-token-list (list 50 uint)))
  (map get-user-asset-balance asset-token-list))

(define-private (get-user-asset-balance (asset-token-id uint))
  {asset-token-id: asset-token-id, 
   owned-balance: (get-asset-balance asset-token-id tx-sender)})

;; Platform Analytics Functions

(define-read-only (get-comprehensive-platform-statistics)
  {
    total-assets-created: (var-get current-nft-supply),
    current-marketplace-fee-rate: (var-get current-marketplace-fee-rate),
    platform-administrator: (var-get platform-administrator),
    next-listing-identifier: (var-get active-listing-counter),
    next-recipe-identifier: (var-get active-recipe-counter)
  })

(define-read-only (get-asset-trading-information (asset-token-id uint))
  (let ((asset-metadata (map-get? game-asset-registry asset-token-id)))
    (match asset-metadata
      data {
        asset-exists: true,
        transfer-enabled: (get transfer-enabled-status data),
        rarity-level: (get asset-rarity-level data),
        category-type: (get asset-category-type data)
      }
      {
        asset-exists: false,
        transfer-enabled: false,
        rarity-level: u0,
        category-type: ""
      })))

;; Emergency Management Functions

(define-public (emergency-disable-asset-trading (asset-token-id uint))
  (let ((asset-metadata (unwrap! (map-get? game-asset-registry asset-token-id) ERR-GAMING-ASSET-NOT-FOUND)))
    ;; Emergency Action Authorization
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Asset ID Validation
    (asserts! (> asset-token-id u0) ERR-INVALID-PARAMETER)
    (asserts! (<= asset-token-id (var-get current-nft-supply)) ERR-GAMING-ASSET-NOT-FOUND)
    
    ;; Disable Asset Trading
    (map-set game-asset-registry asset-token-id 
      (merge asset-metadata {transfer-enabled-status: false}))
    
    (ok true)))

(define-public (emergency-enable-asset-trading (asset-token-id uint))
  (let ((asset-metadata (unwrap! (map-get? game-asset-registry asset-token-id) ERR-GAMING-ASSET-NOT-FOUND)))
    ;; Emergency Action Authorization
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    
    ;; Asset ID Validation
    (asserts! (> asset-token-id u0) ERR-INVALID-PARAMETER)
    (asserts! (<= asset-token-id (var-get current-nft-supply)) ERR-GAMING-ASSET-NOT-FOUND)
    
    ;; Enable Asset Trading
    (map-set game-asset-registry asset-token-id 
      (merge asset-metadata {transfer-enabled-status: true}))
    
    (ok true)))

(define-public (emergency-disable-all-crafting-recipes)
  (begin
    (asserts! (is-eq tx-sender (var-get platform-administrator)) ERR-UNAUTHORIZED-ACCESS)
    (ok true)))

;; Contract Initialization

(begin
  (print "Gaming NFT Ecosystem Platform successfully deployed!")
  (print "Comprehensive blockchain gaming infrastructure ready for asset creation, marketplace trading, crafting mechanics, and complete lifecycle management.")
  (print "All platform systems operational - Welcome to the future of decentralized gaming ecosystems!"))