;; Claim Validation Contract
;; Verifies loss events and validates claims through oracle data

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-CLAIM-NOT-FOUND (err u301))
(define-constant ERR-INVALID-CLAIM-DATA (err u302))
(define-constant ERR-CLAIM-ALREADY-PROCESSED (err u303))
(define-constant ERR-POLICY-NOT-ACTIVE (err u304))
(define-constant ERR-ORACLE-VALIDATION-FAILED (err u305))

;; Claim status constants
(define-constant CLAIM-STATUS-PENDING u0)
(define-constant CLAIM-STATUS-APPROVED u1)
(define-constant CLAIM-STATUS-REJECTED u2)
(define-constant CLAIM-STATUS-INVESTIGATING u3)

;; Data Variables
(define-data-var next-claim-id uint u1)
(define-data-var oracle-address (optional principal) none)

;; Data Maps
(define-map claims
  { claim-id: uint }
  {
    policy-id: uint,
    claimant: principal,
    claim-amount: uint,
    incident-description: (string-ascii 500),
    incident-date: uint,
    submission-block: uint,
    status: uint,
    validator: (optional principal),
    validation-data: (optional (string-ascii 200)),
    processing-notes: (optional (string-ascii 300))
  }
)

(define-map policy-claims
  { policy-id: uint }
  { claim-ids: (list 50 uint) }
)

(define-map oracle-validations
  { claim-id: uint }
  {
    oracle-response: (string-ascii 200),
    validation-score: uint,
    validation-block: uint,
    is-verified: bool
  }
)

;; Read-only functions
(define-read-only (get-claim (claim-id uint))
  (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-policy-claims (policy-id uint))
  (default-to
    { claim-ids: (list) }
    (map-get? policy-claims { policy-id: policy-id })
  )
)

(define-read-only (get-oracle-validation (claim-id uint))
  (map-get? oracle-validations { claim-id: claim-id })
)

(define-read-only (is-claim-valid (claim-id uint))
  (match (get-claim claim-id)
    claim-data
      (and
        (is-eq (get status claim-data) CLAIM-STATUS-APPROVED)
        (is-some (get validator claim-data))
      )
    false
  )
)

(define-read-only (get-next-claim-id)
  (var-get next-claim-id)
)

;; Public functions
(define-public (submit-claim
  (policy-id uint)
  (claim-amount uint)
  (incident-description (string-ascii 500))
  (incident-date uint)
)
  (let
    (
      (claim-id (var-get next-claim-id))
    )
    (asserts! (> claim-amount u0) ERR-INVALID-CLAIM-DATA)
    (asserts! (<= incident-date block-height) ERR-INVALID-CLAIM-DATA)
    (asserts! (< (len incident-description) u501) ERR-INVALID-CLAIM-DATA)

    ;; Create the claim
    (map-set claims
      { claim-id: claim-id }
      {
        policy-id: policy-id,
        claimant: tx-sender,
        claim-amount: claim-amount,
        incident-description: incident-description,
        incident-date: incident-date,
        submission-block: block-height,
        status: CLAIM-STATUS-PENDING,
        validator: none,
        validation-data: none,
        processing-notes: none
      }
    )

    ;; Update policy claims list
    (let
      (
        (current-claims (get claim-ids (get-policy-claims policy-id)))
        (updated-claims (unwrap! (as-max-len? (append current-claims claim-id) u50) ERR-INVALID-CLAIM-DATA))
      )
      (map-set policy-claims
        { policy-id: policy-id }
        { claim-ids: updated-claims }
      )
    )

    ;; Increment claim ID counter
    (var-set next-claim-id (+ claim-id u1))

    (ok claim-id)
  )
)

(define-public (validate-claim-with-oracle
  (claim-id uint)
  (oracle-response (string-ascii 200))
  (validation-score uint)
)
  (let
    (
      (claim-data (unwrap! (get-claim claim-id) ERR-CLAIM-NOT-FOUND))
      (oracle (unwrap! (var-get oracle-address) ERR-ORACLE-VALIDATION-FAILED))
    )
    (asserts! (is-eq tx-sender oracle) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status claim-data) CLAIM-STATUS-PENDING) ERR-CLAIM-ALREADY-PROCESSED)
    (asserts! (<= validation-score u100) ERR-INVALID-CLAIM-DATA)

    ;; Store oracle validation
    (map-set oracle-validations
      { claim-id: claim-id }
      {
        oracle-response: oracle-response,
        validation-score: validation-score,
        validation-block: block-height,
        is-verified: (>= validation-score u70)
      }
    )

    ;; Update claim status based on validation score
    (let
      (
        (new-status (if (>= validation-score u70) CLAIM-STATUS-APPROVED CLAIM-STATUS-REJECTED))
      )
      (map-set claims
        { claim-id: claim-id }
        (merge claim-data
          {
            status: new-status,
            validator: (some tx-sender),
            validation-data: (some oracle-response)
          }
        )
      )
    )

    (ok (>= validation-score u70))
  )
)

(define-public (manual-claim-review
  (claim-id uint)
  (approved bool)
  (processing-notes (string-ascii 300))
)
  (let
    (
      (claim-data (unwrap! (get-claim claim-id) ERR-CLAIM-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status claim-data) CLAIM-STATUS-PENDING) ERR-CLAIM-ALREADY-PROCESSED)
    (asserts! (< (len processing-notes) u301) ERR-INVALID-CLAIM-DATA)

    (let
      (
        (new-status (if approved CLAIM-STATUS-APPROVED CLAIM-STATUS-REJECTED))
      )
      (map-set claims
        { claim-id: claim-id }
        (merge claim-data
          {
            status: new-status,
            validator: (some tx-sender),
            processing-notes: (some processing-notes)
          }
        )
      )
    )

    (ok approved)
  )
)

(define-public (update-claim-status
  (claim-id uint)
  (new-status uint)
  (notes (string-ascii 300))
)
  (let
    (
      (claim-data (unwrap! (get-claim claim-id) ERR-CLAIM-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-status u3) ERR-INVALID-CLAIM-DATA)
    (asserts! (< (len notes) u301) ERR-INVALID-CLAIM-DATA)

    (map-set claims
      { claim-id: claim-id }
      (merge claim-data
        {
          status: new-status,
          processing-notes: (some notes)
        }
      )
    )

    (ok true)
  )
)

(define-public (set-oracle-address (oracle principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set oracle-address (some oracle))
    (ok true)
  )
)
