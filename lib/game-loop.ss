;;; game-loop.ss

;;;; ============================================================
;;;; DELTA TIME
;;;; ============================================================

(define dt 0.0)

;;;; ============================================================
;;;; TEXT INPUT
;;;; ============================================================

(define (text-input)
  (let loop ((chars '()))
    (let ((c (get-char-pressed)))
      (if (= c 0)
          (list->string (reverse chars))
          (loop (cons (integer->char c) chars))))))

;;;; ============================================================
;;;; GAME LOOP
;;;; ============================================================

(define (game-loop title width height target-fps . rest)
  (let ((init (if (null? rest) (lambda () #f) (car rest))))
    (init-window width height title)
    (init-audio-device)
    (set-target-fps target-fps)
    (init)
    (dynamic-wind
      (lambda () #f)
      (lambda ()
        (let loop ()
          (unless (window-should-close)
            (set! dt (get-frame-time))
            (drain-ftype-guardian!)
            (poll-input!)
            (begin-drawing)
            (clear-background raywhite)
            (run)
            (end-drawing)
            (loop))))
      (lambda ()
        (close-audio-device)
        (close-window)))))
