;; Engagement Planning Contract
;; Creates and manages engagement plans

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-NOT-FOUND (err u301))
(define-constant ERR-INVALID-BUDGET (err u302))
(define-constant ERR-PLAN-CLOSED (err u303))

;; Data Variables
(define-data-var plan-counter uint u0)

;; Data Maps
(define-map engagement-plans
  { plan-id: uint }
  {
    created-by: principal,
    title: (string-ascii 100),
    description: (string-ascii 500),
    budget: uint,
    start-block: uint,
    end-block: uint,
    status: (string-ascii 20),
    stakeholder-count: uint,
    allocated-budget: uint
  }
)

(define-map plan-stakeholders
  { plan-id: uint, stakeholder: principal }
  {
    allocated-budget: uint,
    priority: uint,
    engagement-type: (string-ascii 50),
    status: (string-ascii 20)
  }
)

(define-map plan-milestones
  { plan-id: uint, milestone-id: uint }
  {
    title: (string-ascii 100),
    target-block: uint,
    completed: bool,
    completion-block: uint
  }
)

;; Public Functions

;; Create new engagement plan
(define-public (create-engagement-plan
  (title (string-ascii 100))
  (description (string-ascii 500))
  (budget uint)
  (duration-blocks uint)
)
  (let ((plan-id (+ (var-get plan-counter) u1)))
    (asserts! (> budget u0) ERR-INVALID-BUDGET)

    (map-set engagement-plans
      { plan-id: plan-id }
      {
        created-by: tx-sender,
        title: title,
        description: description,
        budget: budget,
        start-block: block-height,
        end-block: (+ block-height duration-blocks),
        status: "active",
        stakeholder-count: u0,
        allocated-budget: u0
      }
    )

    (var-set plan-counter plan-id)
    (ok plan-id)
  )
)

;; Add stakeholder to plan
(define-public (add-stakeholder-to-plan
  (plan-id uint)
  (stakeholder principal)
  (allocated-budget uint)
  (priority uint)
  (engagement-type (string-ascii 50))
)
  (let ((plan-data (unwrap! (map-get? engagement-plans { plan-id: plan-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq (get created-by plan-data) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status plan-data) "active") ERR-PLAN-CLOSED)
    (asserts! (<= (+ (get allocated-budget plan-data) allocated-budget) (get budget plan-data)) ERR-INVALID-BUDGET)

    ;; Add stakeholder to plan
    (map-set plan-stakeholders
      { plan-id: plan-id, stakeholder: stakeholder }
      {
        allocated-budget: allocated-budget,
        priority: priority,
        engagement-type: engagement-type,
        status: "assigned"
      }
    )

    ;; Update plan totals
    (map-set engagement-plans
      { plan-id: plan-id }
      (merge plan-data
        {
          stakeholder-count: (+ (get stakeholder-count plan-data) u1),
          allocated-budget: (+ (get allocated-budget plan-data) allocated-budget)
        }
      )
    )

    (ok true)
  )
)

;; Add milestone to plan
(define-public (add-milestone
  (plan-id uint)
  (milestone-id uint)
  (title (string-ascii 100))
  (target-block uint)
)
  (let ((plan-data (unwrap! (map-get? engagement-plans { plan-id: plan-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq (get created-by plan-data) tx-sender) ERR-NOT-AUTHORIZED)

    (map-set plan-milestones
      { plan-id: plan-id, milestone-id: milestone-id }
      {
        title: title,
        target-block: target-block,
        completed: false,
        completion-block: u0
      }
    )
    (ok true)
  )
)

;; Complete milestone
(define-public (complete-milestone (plan-id uint) (milestone-id uint))
  (let
    (
      (plan-data (unwrap! (map-get? engagement-plans { plan-id: plan-id }) ERR-NOT-FOUND))
      (milestone-data (unwrap! (map-get? plan-milestones { plan-id: plan-id, milestone-id: milestone-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq (get created-by plan-data) tx-sender) ERR-NOT-AUTHORIZED)

    (map-set plan-milestones
      { plan-id: plan-id, milestone-id: milestone-id }
      (merge milestone-data { completed: true, completion-block: block-height })
    )
    (ok true)
  )
)

;; Close engagement plan
(define-public (close-plan (plan-id uint))
  (let ((plan-data (unwrap! (map-get? engagement-plans { plan-id: plan-id }) ERR-NOT-FOUND)))
    (asserts! (is-eq (get created-by plan-data) tx-sender) ERR-NOT-AUTHORIZED)

    (map-set engagement-plans
      { plan-id: plan-id }
      (merge plan-data { status: "closed" })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get engagement plan
(define-read-only (get-engagement-plan (plan-id uint))
  (map-get? engagement-plans { plan-id: plan-id })
)

;; Get plan stakeholder
(define-read-only (get-plan-stakeholder (plan-id uint) (stakeholder principal))
  (map-get? plan-stakeholders { plan-id: plan-id, stakeholder: stakeholder })
)

;; Get milestone
(define-read-only (get-milestone (plan-id uint) (milestone-id uint))
  (map-get? plan-milestones { plan-id: plan-id, milestone-id: milestone-id })
)

;; Get current plan counter
(define-read-only (get-plan-counter)
  (var-get plan-counter)
)

;; Check if plan is active
(define-read-only (is-plan-active (plan-id uint))
  (match (map-get? engagement-plans { plan-id: plan-id })
    plan-data (and (is-eq (get status plan-data) "active") (<= block-height (get end-block plan-data)))
    false
  )
)
