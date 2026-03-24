;;; tilemap.ss

;;;; ============================================================
;;;; INTERNAL STRUCTURE
;;;; ============================================================

(define tilemaps (make-eq-hashtable))

;;;; ============================================================
;;;; INTERNAL HELPERS
;;;; ============================================================

(define (resolve-path map-path rel-path)
  (let* ((dir (let loop ((i (- (string-length map-path) 1)))
                (cond
                  ((< i 0) "")
                  ((or (eqv? (string-ref map-path i) #\/)
                       (eqv? (string-ref map-path i) #\\))
                   (substring map-path 0 (+ i 1)))
                  (else (loop (- i 1))))))
         (rel (if (and (> (string-length rel-path) 2)
                       (string=? (substring rel-path 0 2) "./"))
                  (substring rel-path 2 (string-length rel-path))
                  rel-path)))
    (string-append dir rel)))

(define (parse-tilesets tilesets-json map-path tw th)
  (map (lambda (ts)
         (let* ((firstgid  (json-get ts "firstgid"))
                (img-path  (resolve-path map-path (json-get ts "image")))
                (img-tw    (or (json-get ts "tilewidth")  tw))
                (img-th    (or (json-get ts "tileheight") th))
                (img-w     (json-get ts "imagewidth"))
                (src-cols  (quotient img-w img-tw))
                (tex-name  (string->symbol img-path)))
           (load-asset! tex-name img-path)
           (list firstgid tex-name img-tw img-th src-cols)))
       tilesets-json))

(define (parse-layers layers-json)
  (let loop ((ls layers-json) (tile-layers '()) (obj-layers '()))
    (if (null? ls)
        (list (reverse tile-layers) (reverse obj-layers))
        (let* ((l       (car ls))
               (type    (json-get l "type"))
               (lname   (json-get l "name"))
               (visible (json-get l "visible")))
          (cond
            ((string=? type "tilelayer")
             (loop (cdr ls)
                   (cons (list lname
                               (json-get l "data")
                               (if (eq? visible #f) #f #t))
                         tile-layers)
                   obj-layers))
            ((string=? type "objectgroup")
             (loop (cdr ls)
                   tile-layers
                   (cons (list lname
                               (json-get l "objects")
                               (if (eq? visible #f) #f #t))
                         obj-layers)))
            (else
             (loop (cdr ls) tile-layers obj-layers)))))))

(define (tile-source tilesets gid)
  (let loop ((ts (reverse tilesets)))
    (if (null? ts)
        #f
        (let* ((t        (car ts))
               (firstgid (list-ref t 0))
               (tex-name (list-ref t 1))
               (tw       (list-ref t 2))
               (th       (list-ref t 3))
               (src-cols (list-ref t 4))
               (local-id (- gid firstgid)))
          (if (>= local-id 0)
              (let ((src-x (* (modulo local-id src-cols) tw))
                    (src-y (* (quotient local-id src-cols) th)))
                (list tex-name src-x src-y tw th))
              (loop (cdr ts)))))))

;;;; ============================================================
;;;; LOADER
;;;; ============================================================

(define-syntax load-tilemap
  (syntax-rules ()
    ((_ name path)
     (let* ((json      (json-load path))
            (tw        (json-get json "tilewidth"))
            (th        (json-get json "tileheight"))
            (mw        (json-get json "width"))
            (mh        (json-get json "height"))
            (tilesets  (parse-tilesets (json-get json "tilesets") path tw th))
            (layers    (parse-layers   (json-get json "layers")))
            (m         (list (cons 'tile-width  tw)
                             (cons 'tile-height th)
                             (cons 'map-width   mw)
                             (cons 'map-height  mh)
                             (cons 'tilesets    tilesets)
                             (cons 'tile-layers (car layers))
                             (cons 'obj-layers  (cadr layers)))))
       (hashtable-set! tilemaps 'name m)))))

;;;; ============================================================
;;;; RENDERER
;;;; ============================================================

(define-syntax render-tilemap
  (syntax-rules ()
    ((_ name)
     (render-tilemap name #f))
    ((_ name cam)
     (let* ((m      (hashtable-ref tilemaps 'name
                      (lambda () (error "tilemap not loaded" 'name))))
            (tw     (cdr (assq 'tile-width  m)))
            (th     (cdr (assq 'tile-height m)))
            (mw     (cdr (assq 'map-width   m)))
            (tsets  (cdr (assq 'tilesets    m)))
            (layers (cdr (assq 'tile-layers m))))
       (when cam (begin-mode-2d cam))
       (for-each
         (lambda (layer)
           (let ((data    (cadr  layer))
                 (visible (caddr layer)))
             (when visible
               (let loop ((tiles data) (i 0))
                 (unless (null? tiles)
                   (let ((gid (car tiles)))
                     (when (> gid 0)
                       (let* ((src  (tile-source tsets gid))
                              (_ (unless src
                                   (error "render-tilemap: no tileset found for gid" gid)))
                              (tex  (asset-ref (car src)))
                              (sx   (cadr src))
                              (sy   (caddr src))
                              (stw  (list-ref src 3))
                              (sth  (list-ref src 4))
                              (dx   (* (modulo i mw) tw))
                              (dy   (* (quotient i mw) th))
                              (srec (make-rect sx sy stw sth))
                              (dpos (make-vec2 (exact->inexact dx)
                                               (exact->inexact dy))))
                         (draw-texture-rec tex srec dpos white))))
                   (loop (cdr tiles) (+ i 1)))))))
         layers)
       (when cam (end-mode-2d))))))

;;;; ============================================================
;;;; OBJECT ACCESS
;;;; ============================================================

(define-syntax tilemap-objects
  (syntax-rules ()
    ((_ name)
     (let* ((m          (hashtable-ref tilemaps 'name
                          (lambda () (error "tilemap not loaded" 'name))))
            (obj-layers (cdr (assq 'obj-layers m))))
       (apply append (map cadr obj-layers))))
    ((_ name layer)
     (let* ((m          (hashtable-ref tilemaps 'name
                          (lambda () (error "tilemap not loaded" 'name))))
            (obj-layers (cdr (assq 'obj-layers m)))
            (l          (assoc layer obj-layers)))
       (if l (cadr l) '())))))

(define (obj-x      obj) (json-get obj "x"))
(define (obj-y      obj) (json-get obj "y"))
(define (obj-width  obj) (json-get obj "width"))
(define (obj-height obj) (json-get obj "height"))
(define (obj-name   obj) (json-get obj "name"))
(define (obj-type   obj) (json-get obj "type"))
(define (obj-id     obj) (json-get obj "id"))

;;;; ============================================================
;;;; MAP INFO
;;;; ============================================================

(define-syntax tilemap-width
  (syntax-rules ()
    ((_ name)
     (let ((m (hashtable-ref tilemaps 'name
                (lambda () (error "tilemap not loaded" 'name)))))
       (* (cdr (assq 'map-width  m))
          (cdr (assq 'tile-width m)))))))

(define-syntax tilemap-height
  (syntax-rules ()
    ((_ name)
     (let ((m (hashtable-ref tilemaps 'name
                (lambda () (error "tilemap not loaded" 'name)))))
       (* (cdr (assq 'map-height  m))
          (cdr (assq 'tile-height m)))))))
