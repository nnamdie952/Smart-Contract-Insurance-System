;; Policy Customization Contract
;; Creates and manages tailored insurance policies

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-POLICY-NOT-FOUND (err u101))
(define-constant ERR-POLICY-EXPIRED (err u102))
(define-constant ERR-INVALID-PARAMETERS (err u103))
(define-constant ERR-POLICY-ALREADY-EXISTS (err u104))

;; Data Variables
(define-data-var next-policy-id uint u1)

;; Data Maps
(define-map policies
  { policy-id: uint }
  {
    owner: principal,
    coverage-amount: uint,
    premium: uint,
    coverage-type: (string-ascii 50),
    start-block: uint,
    end-block: uint,
    is-active: bool,
    conditions: (string-ascii 500)
  }
)

(define-map policy-owners
  { owner: principal }
  { policy-ids: (list 100 uint) }
)

;; Read-only functions
(define-read-only (get-policy (policy-id uint))
  (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-owner-policies (owner principal))
  (default-to
    { policy-ids: (list) }
    (map-get? policy-owners { owner: owner })
  )
)

(define-read-only (is-policy-active (policy-id uint))
  (match (get-policy policy-id)
    policy-data
      (and
        (get is-active policy-data)
        (>= block-height (get start-block policy-data))
        (<= block-height (get end-block policy-data))
      )
    false
  )
)

(define-read-only (get-next-policy-id)
  (var-get next-policy-id)
)

;; Public functions
(define-public (create-policy
  (coverage-amount uint)
  (coverage-type (string-ascii 50))
  (duration-blocks uint)
  (conditions (string-ascii 500))
)
  (let
    (
      (policy-id (var-get next-policy-id))
      (start-block block-height)
      (end-block (+ block-height duration-blocks))
    )
    (asserts! (> coverage-amount u0) ERR-INVALID-PARAMETERS)
    (asserts! (> duration-blocks u0) ERR-INVALID-PARAMETERS)
    (asserts! (< (len coverage-type) u51) ERR-INVALID-PARAMETERS)

    ;; Create the policy
    (map-set policies
      { policy-id: policy-id }
      {
        owner: tx-sender,
        coverage-amount: coverage-amount,
        premium: u0, ;; Will be set by risk assessment
        coverage-type: coverage-type,
        start-block: start-block,
        end-block: end-block,
        is-active: false, ;; Activated after premium payment
        conditions: conditions
      }
    )

    ;; Update owner's policy list
    (let
      (
        (current-policies (get policy-ids (get-owner-policies tx-sender)))
        (updated-policies (unwrap! (as-max-len? (append current-policies policy-id) u100) ERR-INVALID-PARAMETERS))
      )
      (map-set policy-owners
        { owner: tx-sender }
        { policy-ids: updated-policies }
      )
    )

    ;; Increment policy ID counter
    (var-set next-policy-id (+ policy-id u1))

    (ok policy-id)
  )
)

(define-public (activate-policy (policy-id uint) (premium uint))
  (let
    (
      (policy-data (unwrap! (get-policy policy-id) ERR-POLICY-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get owner policy-data)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-active policy-data)) ERR-POLICY-ALREADY-EXISTS)
    (asserts! (> premium u0) ERR-INVALID-PARAMETERS)

    ;; Update policy with premium and activate
    (map-set policies
      { policy-id: policy-id }
      (merge policy-data { premium: premium, is-active: true })
    )

    (ok true)
  )
)

(define-public (update-policy-conditions
  (policy-id uint)
  (new-conditions (string-ascii 500))
)
  (let
    (
      (policy-data (unwrap! (get-policy policy-id) ERR-POLICY-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get owner policy-data)) ERR-NOT-AUTHORIZED)
    (asserts! (is-policy-active policy-id) ERR-POLICY-EXPIRED)
    (asserts! (< (len new-conditions) u501) ERR-INVALID-PARAMETERS)

    (map-set policies
      { policy-id: policy-id }
      (merge policy-data { conditions: new-conditions })
    )

    (ok true)
  )
)

(define-public (cancel-policy (policy-id uint))
  (let
    (
      (policy-data (unwrap! (get-policy policy-id) ERR-POLICY-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get owner policy-data)) ERR-NOT-AUTHORIZED)
    (asserts! (get is-active policy-data) ERR-POLICY-EXPIRED)

    (map-set policies
      { policy-id: policy-id }
      (merge policy-data { is-active: false })
    )

    (ok true)
  )
)
