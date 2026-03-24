;;;; ============================================================
;;;; ASSET MANAGER
;;;; ============================================================

(define *assets* (make-eq-hashtable))

(define (load-asset name path . rest)
  (unless (hashtable-contains? *assets* name)
    (let ((loader (if (null? rest) load-texture (car rest))))
      (hashtable-set! *assets* name (loader path)))))

(define (get-asset name)
  (hashtable-ref *assets* name
    (lambda () (error "asset not loaded" name))))

(define (unload-asset name)
  (let ((asset (hashtable-ref *assets* name #f)))
    (when asset
      (hashtable-delete! *assets* name))))

;;;; ============================================================
;;;; DELTA TIME
;;;; ============================================================

(define *dt* 0.0)

;;;; ============================================================
;;;; ANIMATION COMPONENT
;;;; ============================================================

(component animation (asset frame-w frame-h frames fps frame elapsed))

;;;; ============================================================
;;;; ANIMATION SYSTEM
;;;; ============================================================

(system animation-system
  ((anim : animation))
  (let* ((elapsed     (get anim elapsed))
         (fps         (get anim fps))
         (frames      (get anim frames))
         (frame       (get anim frame))
         (new-elapsed (+ elapsed *dt*)))
    (if (>= new-elapsed (/ 1.0 fps))
        (begin
          (put! anim frame   (modulo (+ frame 1) frames))
          (put! anim elapsed 0.0))
        (put! anim elapsed new-elapsed))))

;;;; ============================================================
;;;; RENDER ANIMATION SYSTEM
;;;; ============================================================

(system render-animation-system
  ((anim : animation) (pos : position))
  (let* ((tex   (get-asset (get anim asset)))
         (fw    (get anim frame-w))
         (fh    (get anim frame-h))
         (frame (get anim frame))
         (src   (make-rect (* frame fw) 0 fw fh))
         (dest  (make-vec2 (exact->inexact (get pos x))
                           (exact->inexact (get pos y)))))
    (draw-texture-rec tex src dest white)))

;;;; ============================================================
;;;; GAME LOOP
;;;; ============================================================

(define (game-loop title width height fps . rest)
  (let ((init (if (null? rest) (lambda () #f) (car rest))))
    (init-window width height title)
    (set-target-fps fps)
    (init)
    (let loop ()
      (unless (window-should-close)
        (set! *dt* (get-frame-time))
        (begin-drawing)
        (clear-background raywhite)
        (run)
        (end-drawing)
        (loop)))
    (close-window)))
