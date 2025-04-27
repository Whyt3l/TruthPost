;; TruthPost - Social media platform with on-chain content verification
;; Creators earn tokens based on engagement and accuracy ratings

;; Error codes
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_INPUT (err u103))
(define-constant ERR_ALREADY_VERIFIED (err u104))
(define-constant ERR_ALREADY_RATED (err u105))
(define-constant ERR_SELF_RATING (err u106))
(define-constant ERR_EMPTY_STRING (err u107))
(define-constant ERR_INVALID_RATING (err u108))
(define-constant ERR_INVALID_POST_ID (err u109))
(define-constant ERR_EMPTY_HASH (err u110))

;; Constants
(define-constant MAX_RATING u5)
(define-constant ENGAGEMENT_REWARD u10)
(define-constant ACCURACY_REWARD u20)
(define-constant VERIFICATION_REWARD u50)

;; Data maps
(define-map users
  { user-id: principal }
  { username: (string-ascii 50), reputation: uint, tokens: uint, verified: bool }
)

(define-map posts
  { post-id: uint }
  { 
    author: principal, 
    content: (string-ascii 500), 
    content-hash: (buff 32),
    timestamp: uint, 
    verified: bool,
    verification-count: uint,
    engagement-count: uint,
    accuracy-rating: uint,
    rating-count: uint
  }
)

(define-map post-verifications
  { post-id: uint, verifier: principal }
  { verified: bool }
)

(define-map post-engagements
  { post-id: uint, user: principal }
  { engaged: bool, engagement-type: (string-ascii 10) }
)

(define-map post-ratings
  { post-id: uint, rater: principal }
  { rating: uint }
)

;; Variables
(define-data-var next-post-id uint u1)
(define-data-var action-counter uint u0)

;; Helper functions
(define-private (is-valid-post-id (post-id uint))
  (< post-id (var-get next-post-id))
)

;; User functions
(define-public (register-user (username (string-ascii 50)))
  (let ((caller tx-sender))
    ;; Validate username is not empty
    (asserts! (> (len username) u0) ERR_EMPTY_STRING)
    ;; Check if user already exists
    (asserts! (is-none (map-get? users {user-id: caller})) ERR_ALREADY_EXISTS)
    ;; Register user
    (ok (map-set users 
      {user-id: caller} 
      {username: username, reputation: u0, tokens: u100, verified: false}))
  )
)

(define-public (update-username (username (string-ascii 50)))
  (let ((caller tx-sender))
    ;; Validate username is not empty
    (asserts! (> (len username) u0) ERR_EMPTY_STRING)
    ;; Check if user exists
    (asserts! (is-some (map-get? users {user-id: caller})) ERR_NOT_FOUND)
    ;; Update username
    (ok (map-set users 
      {user-id: caller} 
      (merge (unwrap! (map-get? users {user-id: caller}) ERR_NOT_FOUND)
             {username: username})))
  )
)

;; Post functions
(define-public (create-post (content (string-ascii 500)) (content-hash (buff 32)))
  (let ((caller tx-sender)
        (post-id (var-get next-post-id)))
    ;; Validate content is not empty
    (asserts! (> (len content) u0) ERR_EMPTY_STRING)
    ;; Validate content-hash is not empty
    (asserts! (> (len content-hash) u0) ERR_EMPTY_HASH)
    ;; Check if user exists
    (asserts! (is-some (map-get? users {user-id: caller})) ERR_NOT_FOUND)
    ;; Increment action counter
    (var-set action-counter (+ (var-get action-counter) u1))
    
    ;; Create post with validated data
    (map-set posts 
      {post-id: post-id} 
      { 
        author: caller, 
        content: content, 
        content-hash: content-hash,
        timestamp: (var-get action-counter), 
        verified: false,
        verification-count: u0,
        engagement-count: u0,
        accuracy-rating: u0,
        rating-count: u0
      })
    ;; Increment post ID
    (var-set next-post-id (+ post-id u1))
    (ok post-id)
  )
)

(define-public (verify-post (post-id uint))
  (let ((caller tx-sender))
    ;; Validate post-id
    (asserts! (is-valid-post-id post-id) ERR_INVALID_POST_ID)
    ;; Check if user exists
    (asserts! (is-some (map-get? users {user-id: caller})) ERR_NOT_FOUND)
    ;; Check if post exists
    (asserts! (is-some (map-get? posts {post-id: post-id})) ERR_NOT_FOUND)
    
    ;; Get post data
    (let ((post (unwrap! (map-get? posts {post-id: post-id}) ERR_NOT_FOUND)))
      ;; Check if user is not the author
      (asserts! (not (is-eq caller (get author post))) ERR_SELF_RATING)
      ;; Check if user has not already verified this post
      (asserts! (is-none (map-get? post-verifications {post-id: post-id, verifier: caller})) ERR_ALREADY_VERIFIED)
      
      ;; Record verification with validated post-id
      (map-set post-verifications 
        {post-id: post-id, verifier: caller} 
        {verified: true})
      
      ;; Update post verification count
      (let ((new-verification-count (+ (get verification-count post) u1))
            (author-user (unwrap! (map-get? users {user-id: (get author post)}) ERR_NOT_FOUND))
            (verifier-user (unwrap! (map-get? users {user-id: caller}) ERR_NOT_FOUND)))
        
        ;; Update post data with validated post-id
        (map-set posts 
          {post-id: post-id} 
          (merge post {
            verification-count: new-verification-count,
            verified: (>= new-verification-count u3)
          }))
        
        ;; Reward verifier with tokens
        (map-set users 
          {user-id: caller} 
          (merge verifier-user {
            tokens: (+ (get tokens verifier-user) u5),
            reputation: (+ (get reputation verifier-user) u1)
          }))
        
        ;; If post becomes verified (3+ verifications), reward author
        (if (and (>= new-verification-count u3) (not (get verified post)))
          (map-set users 
            {user-id: (get author post)} 
            (merge author-user {
              tokens: (+ (get tokens author-user) VERIFICATION_REWARD),
              reputation: (+ (get reputation author-user) u10)
            }))
          true)
        
        (ok new-verification-count)
      )
    )
  )
)

(define-public (engage-with-post (post-id uint) (engagement-type (string-ascii 10)))
  (let ((caller tx-sender))
    ;; Validate post-id
    (asserts! (is-valid-post-id post-id) ERR_INVALID_POST_ID)
    ;; Validate engagement type (like, share, comment)
    (asserts! (or (is-eq engagement-type "like") 
                 (is-eq engagement-type "share") 
                 (is-eq engagement-type "comment")) 
             ERR_INVALID_INPUT)
    ;; Check if user exists
    (asserts! (is-some (map-get? users {user-id: caller})) ERR_NOT_FOUND)
    ;; Check if post exists
    (asserts! (is-some (map-get? posts {post-id: post-id})) ERR_NOT_FOUND)
    
    ;; Get post data
    (let ((post (unwrap! (map-get? posts {post-id: post-id}) ERR_NOT_FOUND)))
      ;; Check if user has not already engaged with this post
      (asserts! (is-none (map-get? post-engagements {post-id: post-id, user: caller})) ERR_ALREADY_EXISTS)
      
      ;; Record engagement with validated post-id
      (map-set post-engagements 
        {post-id: post-id, user: caller} 
        {engaged: true, engagement-type: engagement-type})
      
      ;; Update post engagement count
      (let ((new-engagement-count (+ (get engagement-count post) u1))
            (author-user (unwrap! (map-get? users {user-id: (get author post)}) ERR_NOT_FOUND)))
        
        ;; Update post data with validated post-id
        (map-set posts 
          {post-id: post-id} 
          (merge post {engagement-count: new-engagement-count}))
        
        ;; Reward author with tokens for engagement
        (map-set users 
          {user-id: (get author post)} 
          (merge author-user {
            tokens: (+ (get tokens author-user) ENGAGEMENT_REWARD)
          }))
        
        (ok new-engagement-count)
      )
    )
  )
)

(define-public (rate-post-accuracy (post-id uint) (rating uint))
  (let ((caller tx-sender))
    ;; Validate post-id
    (asserts! (is-valid-post-id post-id) ERR_INVALID_POST_ID)
    ;; Validate rating (1-5)
    (asserts! (and (>= rating u1) (<= rating MAX_RATING)) ERR_INVALID_RATING)
    ;; Check if user exists
    (asserts! (is-some (map-get? users {user-id: caller})) ERR_NOT_FOUND)
    ;; Check if post exists
    (asserts! (is-some (map-get? posts {post-id: post-id})) ERR_NOT_FOUND)
    
    ;; Get post data
    (let ((post (unwrap! (map-get? posts {post-id: post-id}) ERR_NOT_FOUND)))
      ;; Check if user is not the author
      (asserts! (not (is-eq caller (get author post))) ERR_SELF_RATING)
      ;; Check if user has not already rated this post
      (asserts! (is-none (map-get? post-ratings {post-id: post-id, rater: caller})) ERR_ALREADY_RATED)
      
      ;; Record rating with validated post-id and rating
      (map-set post-ratings 
        {post-id: post-id, rater: caller} 
        {rating: rating})
      
      ;; Update post rating
      (let ((current-total-rating (* (get accuracy-rating post) (get rating-count post)))
            (new-rating-count (+ (get rating-count post) u1))
            (new-total-rating (+ current-total-rating rating))
            (new-average-rating (/ new-total-rating new-rating-count))
            (author-user (unwrap! (map-get? users {user-id: (get author post)}) ERR_NOT_FOUND))
            (rater-user (unwrap! (map-get? users {user-id: caller}) ERR_NOT_FOUND)))
        
        ;; Update post data with validated post-id
        (map-set posts 
          {post-id: post-id} 
          (merge post {
            accuracy-rating: new-average-rating,
            rating-count: new-rating-count
          }))
        
        ;; Reward rater with tokens
        (map-set users 
          {user-id: caller} 
          (merge rater-user {
            tokens: (+ (get tokens rater-user) u2),
            reputation: (+ (get reputation rater-user) u1)
          }))
        
        ;; Reward author based on rating
        (if (>= rating u4)
          (map-set users 
            {user-id: (get author post)} 
            (merge author-user {
              tokens: (+ (get tokens author-user) ACCURACY_REWARD),
              reputation: (+ (get reputation author-user) u5)
            }))
          true)
        
        (ok new-average-rating)
      )
    )
  )
)

;; Read-only functions
(define-read-only (get-user-info (user-id principal))
  (map-get? users {user-id: user-id})
)

(define-read-only (get-post (post-id uint))
  (map-get? posts {post-id: post-id})
)

(define-read-only (get-post-verification (post-id uint) (verifier principal))
  (map-get? post-verifications {post-id: post-id, verifier: verifier})
)

(define-read-only (get-post-engagement (post-id uint) (user principal))
  (map-get? post-engagements {post-id: post-id, user: user})
)

(define-read-only (get-post-rating (post-id uint) (rater principal))
  (map-get? post-ratings {post-id: post-id, rater: rater})
)

(define-read-only (get-total-posts)
  (- (var-get next-post-id) u1)
)
