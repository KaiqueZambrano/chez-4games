;;; input.ss

;;;; ============================================================
;;;; STATE
;;;; ============================================================

(define key-state             (make-eqv-hashtable))
(define keys-pressed-this-frame  '())
(define keys-released-this-frame '())

;;;; ============================================================
;;;; INTERNAL
;;;; ============================================================

(define (drain-key-pressed!)
  (let loop ()
    (let ((k (get-key-pressed)))
      (when (> k 0)
        (unless (hashtable-ref key-state k #f)
          (hashtable-set! key-state k #t)
          (set! keys-pressed-this-frame
                (cons k keys-pressed-this-frame)))
        (loop)))))

(define (drain-key-released!)
  (for-each
    (lambda (k)
      (when (is-key-released k)
        (hashtable-delete! key-state k)
        (set! keys-released-this-frame
              (cons k keys-released-this-frame))))
    (vector->list (hashtable-keys key-state))))

;;;; ============================================================
;;;; PUBLIC
;;;; ============================================================

(define (poll-input!)
  (set! keys-pressed-this-frame  '())
  (set! keys-released-this-frame '())
  (drain-key-released!)
  (drain-key-pressed!))

(define (key-down? k)
  (hashtable-ref key-state k #f))

(define (key-pressed? k)
  (and (memv k keys-pressed-this-frame) #t))

(define (key-released? k)
  (and (memv k keys-released-this-frame) #t))
