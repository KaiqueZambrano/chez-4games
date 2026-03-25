;;; animation.ss

;;;; ============================================================
;;;; COMPONENT
;;;; ============================================================

(component animation (texture frame-w frame-h row frames speed scale-x scale-y frame elapsed))

;;;; ============================================================
;;;; FRAME ADVANCE
;;;; ============================================================

(define (make-animation-system)
  (system animation-system
    ((anim : animation))
    (let* ((elapsed     (get anim elapsed))
           (speed       (get anim speed))
           (frames      (get anim frames))
           (frame       (get anim frame))
           (new-elapsed (+ elapsed dt)))
      (if (>= new-elapsed (/ 1.0 speed))
          (begin
            (put! anim frame   (modulo (+ frame 1) frames))
            (put! anim elapsed 0.0))
          (put! anim elapsed new-elapsed)))))

;;;; ============================================================
;;;; RENDERING
;;;; ============================================================

(define (make-render-animation-system)
  (system render-animation-system
    ((anim : animation) (pos : position))
    (let* ((tex     (asset-ref (get anim texture)))
           (fw      (get anim frame-w))
           (fh      (get anim frame-h))
           (row     (get anim row))
           (frame   (get anim frame))
           (scale-x (get anim scale-x))
           (scale-y (get anim scale-y))
           (src-x   (* frame fw))
           (src-y   (* row   fh))
           (src-w   (* scale-x fw))
           (src-h   (* scale-y fh))
           (src     (make-rect (exact->inexact src-x)
                               (exact->inexact src-y)
                               (exact->inexact src-w)
                               (exact->inexact src-h)))
           (dest    (make-rect (exact->inexact (get pos x))
                               (exact->inexact (get pos y))
                               (exact->inexact (* (abs scale-x) fw))
                               (exact->inexact (* (abs scale-y) fh))))
           (origin  (make-vec2 0.0 0.0)))
      (draw-texture-pro tex src dest origin 0.0 white))))
