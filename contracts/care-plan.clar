;; Care Plan Development Contract
;; Creates and manages personalized senior assistance programs

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-INPUT (err u101))
(define-constant ERR-PLAN-NOT-FOUND (err u102))
(define-constant ERR-PLAN-ALREADY-EXISTS (err u103))

;; Data Variables
(define-data-var next-plan-id uint u1)

;; Data Maps
(define-map care-plans
  { plan-id: uint }
  {
    elder: principal,
    caregiver: principal,
    description: (string-ascii 500),
    goals: (string-ascii 1000),
    status: (string-ascii 20),
    created-at: uint,
    updated-at: uint,
    duration-days: uint
  }
)

(define-map elder-plans
  { elder: principal }
  { active-plan-id: uint }
)

(define-map caregiver-permissions
  { elder: principal, caregiver: principal }
  { authorized: bool, granted-at: uint }
)

;; Private Functions
(define-private (is-authorized (elder principal) (caller principal))
  (or
    (is-eq caller elder)
    (default-to false (get authorized (map-get? caregiver-permissions { elder: elder, caregiver: caller })))
  )
)

;; Public Functions
(define-public (create-care-plan (elder principal) (description (string-ascii 500)) (duration-days uint))
  (let
    (
      (plan-id (var-get next-plan-id))
      (current-time stacks-block-height)
    )
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (> duration-days u0) ERR-INVALID-INPUT)
    (asserts! (< duration-days u365) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? elder-plans { elder: elder })) ERR-PLAN-ALREADY-EXISTS)

    (map-set care-plans
      { plan-id: plan-id }
      {
        elder: elder,
        caregiver: tx-sender,
        description: description,
        goals: "",
        status: "active",
        created-at: current-time,
        updated-at: current-time,
        duration-days: duration-days
      }
    )

    (map-set elder-plans
      { elder: elder }
      { active-plan-id: plan-id }
    )

    (var-set next-plan-id (+ plan-id u1))
    (ok plan-id)
  )
)

(define-public (update-care-plan (plan-id uint) (description (string-ascii 500)) (goals (string-ascii 1000)))
  (let
    (
      (plan (unwrap! (map-get? care-plans { plan-id: plan-id }) ERR-PLAN-NOT-FOUND))
      (current-time stacks-block-height)
    )
    (asserts! (is-authorized (get elder plan) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)

    (map-set care-plans
      { plan-id: plan-id }
      (merge plan {
        description: description,
        goals: goals,
        updated-at: current-time
      })
    )
    (ok true)
  )
)

(define-public (authorize-caregiver (elder principal) (caregiver principal))
  (let
    (
      (current-time stacks-block-height)
    )
    (asserts! (is-eq tx-sender elder) ERR-NOT-AUTHORIZED)

    (map-set caregiver-permissions
      { elder: elder, caregiver: caregiver }
      { authorized: true, granted-at: current-time }
    )
    (ok true)
  )
)

(define-public (deactivate-care-plan (plan-id uint))
  (let
    (
      (plan (unwrap! (map-get? care-plans { plan-id: plan-id }) ERR-PLAN-NOT-FOUND))
      (current-time stacks-block-height)
    )
    (asserts! (is-authorized (get elder plan) tx-sender) ERR-NOT-AUTHORIZED)

    (map-set care-plans
      { plan-id: plan-id }
      (merge plan {
        status: "inactive",
        updated-at: current-time
      })
    )
    (ok true)
  )
)

;; Read-only Functions
(define-read-only (get-care-plan (plan-id uint))
  (map-get? care-plans { plan-id: plan-id })
)

(define-read-only (get-elder-active-plan (elder principal))
  (match (map-get? elder-plans { elder: elder })
    plan-info (map-get? care-plans { plan-id: (get active-plan-id plan-info) })
    none
  )
)

(define-read-only (is-caregiver-authorized (elder principal) (caregiver principal))
  (default-to false (get authorized (map-get? caregiver-permissions { elder: elder, caregiver: caregiver })))
)
