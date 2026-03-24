;;; game-loop.ss

;;;; ============================================================
;;;; DELTA TIME
;;;; ============================================================

(define dt 0.0)

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
            (begin-drawing)
            (clear-background raywhite)
            (run)
            (end-drawing)
            (loop))))
      (lambda ()
        (close-audio-device)
        (close-window)))))
