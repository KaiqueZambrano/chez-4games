;;; assets.ss

;;;; ============================================================
;;;; ASSET CACHE
;;;; ============================================================

(define assets (make-eq-hashtable))

(define (load-asset! name path . rest)
  (unless (hashtable-contains? assets name)
    (let* ((loader   (if (null? rest) load-texture (car rest)))
           (unloader (if (or (null? rest) (null? (cdr rest)))
                         unload-texture
                         (cadr rest)))
           (value    (loader path)))
      (hashtable-set! assets name (cons value unloader)))))

(define-syntax load-asset
  (syntax-rules ()
    ((_ name path)
     (load-asset! 'name path))
    ((_ name path loader)
     (load-asset! 'name path loader))
    ((_ name path loader unloader)
     (load-asset! 'name path loader unloader))))

(define-syntax get-asset
  (syntax-rules ()
    ((_ name)
     (let ((entry (hashtable-ref assets 'name
                    (lambda () (error "get-asset: not loaded" 'name)))))
       (car entry)))))

(define (asset-ref name)
  (let ((entry (hashtable-ref assets name
                 (lambda () (error "asset-ref: not loaded" name)))))
    (car entry)))

(define-syntax unload-asset
  (syntax-rules ()
    ((_ name)
     (let ((entry (hashtable-ref assets 'name #f)))
       (when entry
         ((cdr entry) (car entry))
         (hashtable-delete! assets 'name))))))

(define (unload-all-assets!)
  (let ((keys (vector->list (hashtable-keys assets))))
    (for-each
      (lambda (k)
        (let ((entry (hashtable-ref assets k #f)))
          (when entry
            ((cdr entry) (car entry))
            (hashtable-delete! assets k))))
      keys)))

(define-syntax unload-assets-except!
  (syntax-rules ()
    ((_ keep ...)
     (let ((to-remove '()))
       (hashtable-for-each assets
         (lambda (name entry)
           (unless (memq name '(keep ...))
             (set! to-remove (cons (cons name entry) to-remove)))))
       (for-each (lambda (pair)
                   ((cdr (cdr pair)) (car (cdr pair)))
                   (hashtable-delete! assets (car pair)))
                 to-remove)))))
