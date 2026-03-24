;;; assets.ss

;;;; ============================================================
;;;; ASSET MANAGER
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
                    (lambda () (error "asset not loaded" 'name)))))
       (car entry)))))

(define (asset-ref name)
  (let ((entry (hashtable-ref assets name
                 (lambda () (error "asset not loaded" name)))))
    (car entry)))

(define-syntax unload-asset
  (syntax-rules ()
    ((_ name)
     (let ((entry (hashtable-ref assets 'name #f)))
       (when entry
         ((cdr entry) (car entry))
         (hashtable-delete! assets 'name))))))
