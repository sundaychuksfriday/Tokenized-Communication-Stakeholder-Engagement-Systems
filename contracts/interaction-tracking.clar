;; Interaction Tracking Contract
;; Records all stakeholder interactions

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-NOT-FOUND (err u401))
(define-constant ERR-INVALID-RATING (err u402))

;; Data Variables
(define-data-var interaction-counter uint u0)

;; Data Maps
(define-map interactions
  { interaction-id: uint }
  {
    stakeholder: principal,
    manager: principal,
    interaction-type: (string-ascii 50),
    description: (string-ascii 500),
    outcome: (string-ascii 200),
    rating: uint,
    timestamp: uint,
    plan-id: (optional uint),
    follow-up-required: bool
  }
)

(define-map interaction-tags
  { interaction-id: uint, tag: (string-ascii 30) }
  { added-by: principal, added-at: uint }
)

(define-map stakeholder-interaction-summary
  { stakeholder: principal }
  {
    total-interactions: uint,
    last-interaction: uint,
    average-rating: uint,
    positive-interactions: uint,
    negative-interactions: uint
  }
)

;; Public Functions

;; Record new interaction
(define-public (record-interaction
  (stakeholder principal)
  (interaction-type (string-ascii 50))
  (description (string-ascii 500))
  (outcome (string-ascii 200))
  (rating uint)
  (plan-id (optional uint))
  (follow-up-required bool)
)
  (let ((interaction-id (+ (var-get interaction-counter) u1)))
    (asserts! (<= rating u5) ERR-INVALID-RATING)

    ;; Record interaction
    (map-set interactions
      { interaction-id: interaction-id }
      {
        stakeholder: stakeholder,
        manager: tx-sender,
        interaction-type: interaction-type,
        description: description,
        outcome: outcome,
        rating: rating,
        timestamp: block-height,
        plan-id: plan-id,
        follow-up-required: follow-up-required
      }
    )

    ;; Update stakeholder summary
    (match (map-get? stakeholder-interaction-summary { stakeholder: stakeholder })
      summary-data (update-stakeholder-summary stakeholder summary-data rating)
      (create-stakeholder-summary stakeholder rating)
    )

    (var-set interaction-counter interaction-id)
    (ok interaction-id)
  )
)

;; Add tag to interaction
(define-public (add-interaction-tag (interaction-id uint) (tag (string-ascii 30)))
  (let ((interaction-data (unwrap! (map-get? interactions { interaction-id: interaction-id }) ERR-NOT-FOUND)))
    (map-set interaction-tags
      { interaction-id: interaction-id, tag: tag }
      { added-by: tx-sender, added-at: block-height }
    )
    (ok true)
  )
)

;; Update interaction outcome
(define-public (update-interaction-outcome (interaction-id uint) (new-outcome (string-ascii 200)))
  (let ((interaction-data (unwrap! (map-get? interactions { interaction-id: interaction-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq (get manager interaction-data) tx-sender) ERR-NOT-AUTHORIZED)

    (map-set interactions
      { interaction-id: interaction-id }
      (merge interaction-data { outcome: new-outcome })
    )
    (ok true)
  )
)

;; Mark follow-up completed
(define-public (complete-follow-up (interaction-id uint))
  (let ((interaction-data (unwrap! (map-get? interactions { interaction-id: interaction-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq (get manager interaction-data) tx-sender) ERR-NOT-AUTHORIZED)

    (map-set interactions
      { interaction-id: interaction-id }
      (merge interaction-data { follow-up-required: false })
    )
    (ok true)
  )
)

;; Private Functions

;; Create new stakeholder summary
(define-private (create-stakeholder-summary (stakeholder principal) (rating uint))
  (map-set stakeholder-interaction-summary
    { stakeholder: stakeholder }
    {
      total-interactions: u1,
      last-interaction: block-height,
      average-rating: rating,
      positive-interactions: (if (>= rating u4) u1 u0),
      negative-interactions: (if (< rating u3) u1 u0)
    }
  )
)

;; Update existing stakeholder summary
(define-private (update-stakeholder-summary (stakeholder principal) (summary-data (tuple (total-interactions uint) (last-interaction uint) (average-rating uint) (positive-interactions uint) (negative-interactions uint))) (rating uint))
  (let
    (
      (new-total (+ (get total-interactions summary-data) u1))
      (new-avg (/ (+ (* (get average-rating summary-data) (get total-interactions summary-data)) rating) new-total))
      (new-positive (+ (get positive-interactions summary-data) (if (>= rating u4) u1 u0)))
      (new-negative (+ (get negative-interactions summary-data) (if (< rating u3) u1 u0)))
    )
    (map-set stakeholder-interaction-summary
      { stakeholder: stakeholder }
      {
        total-interactions: new-total,
        last-interaction: block-height,
        average-rating: new-avg,
        positive-interactions: new-positive,
        negative-interactions: new-negative
      }
    )
  )
)

;; Read-only Functions

;; Get interaction details
(define-read-only (get-interaction (interaction-id uint))
  (map-get? interactions { interaction-id: interaction-id })
)

;; Get interaction tag
(define-read-only (get-interaction-tag (interaction-id uint) (tag (string-ascii 30)))
  (map-get? interaction-tags { interaction-id: interaction-id, tag: tag })
)

;; Get stakeholder summary
(define-read-only (get-stakeholder-summary (stakeholder principal))
  (map-get? stakeholder-interaction-summary { stakeholder: stakeholder })
)

;; Get total interaction count
(define-read-only (get-interaction-count)
  (var-get interaction-counter)
)

;; Check if follow-up required
(define-read-only (requires-follow-up (interaction-id uint))
  (match (map-get? interactions { interaction-id: interaction-id })
    interaction-data (get follow-up-required interaction-data)
    false
  )
)
