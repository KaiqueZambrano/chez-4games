;;; ecs.ss

;;;; ============================================================
;;;; GLOBAL STATE
;;;; ============================================================

(define entities       '())
(define components     '())
(define systems        '())

(define event-types    '())
(define event-queue    '())
(define event-handlers '())

(define next-id        0)

(define (new-id)
  (set! next-id (+ next-id 1))
  next-id)

;;;; ============================================================
;;;; UTIL
;;;; ============================================================

(define (filter pred lst)
  (let loop ((lst lst) (acc '()))
    (cond
      ((null? lst)      (reverse acc))
      ((pred (car lst)) (loop (cdr lst) (cons (car lst) acc)))
      (else             (loop (cdr lst) acc)))))

;;;; ============================================================
;;;; COMPONENT
;;;; ============================================================

(define-syntax component
  (syntax-rules ()
    ((_ name [field ...])
     (set! components (cons '(name (field #f) ...) components)))
    ((_ name)
     (set! components (cons '(name) components)))))

(define (make-component name field-vals)
  (let ((template (assoc name components)))
    (cons name
          (map (lambda (pair)
                 (let ((given (assoc (car pair) field-vals)))
                   (list (car pair) (if given (cadr given) #f))))
               (cdr template)))))

;;;; ============================================================
;;;; ENTITY
;;;; ============================================================

(define (make-entity comp-list)
  (let ((id (new-id)))
    (set! entities (cons (cons id comp-list) entities))
    id))

(define-syntax entity
  (syntax-rules ()
    ((_ name [comp val ...] ...)
     (define name
       (make-entity
         (list (make-component 'comp
                 (map list
                      (map car (cdr (assoc 'comp components)))
                      '(val ...)))
               ...))))))

(define-syntax spawn
  (syntax-rules ()
    ((_ [comp val ...] ...)
     (make-entity
       (list (make-component 'comp
               (map list
                    (map car (cdr (assoc 'comp components)))
                    '(val ...)))
             ...)))))

(define (despawn id)
  (set! entities (filter (lambda (e) (not (= (car e) id))) entities)))

;;;; ============================================================
;;;; COMPONENT ACCESS
;;;; ============================================================

(define (has-component? id name)
  (and (assoc id entities)
       (assoc name (cdr (assoc id entities)))))

(define (add-component id name field-vals)
  (let ((e (assoc id entities)))
    (set-cdr! e (cons (make-component name field-vals) (cdr e)))))

(define (remove-component id name)
  (let ((e (assoc id entities)))
    (set-cdr! e (filter (lambda (c) (not (eq? (car c) name))) (cdr e)))))

(define (comp-get comp field)
  (cadr (assoc field (cdr comp))))

(define (comp-set! comp field val)
  (set-car! (cdr (assoc field (cdr comp))) val))

(define (field-get id comp-name field)
  (comp-get (assoc comp-name (cdr (assoc id entities))) field))

(define (field-set! id comp-name field val)
  (comp-set! (assoc comp-name (cdr (assoc id entities))) field val))

(define-syntax get
  (syntax-rules ()
    ((_ comp field)          (comp-get   comp   'field))
    ((_ id comp field)       (field-get  id 'comp 'field))))

(define-syntax put!
  (syntax-rules ()
    ((_ comp field expr)     (comp-set!  comp   'field expr))
    ((_ id comp field expr)  (field-set! id 'comp 'field expr))))

;;;; ============================================================
;;;; QUERY
;;;; ============================================================

(define (query required . rest)
  (let ((excluded (if (null? rest) '() (car rest))))

    (define (has-all?  comps names) (for-all (lambda (n)     (assoc n comps)) names))
    (define (has-none? comps names) (not (exists (lambda (n) (assoc n comps)) names)))

    (let loop ((es entities) (acc '()))
      (if (null? es)
          (reverse acc)
          (let* ((e     (car es))
                 (comps (cdr e)))
            (if (and (has-all? comps required) (has-none? comps excluded))
                (loop (cdr es)
                      (cons (cons (car e)
                                  (map (lambda (n) (assoc n comps)) required))
                            acc))
                (loop (cdr es) acc)))))))

;;;; ============================================================
;;;; SYSTEM
;;;; ============================================================

(define-syntax system
  (lambda (stx)
    (syntax-case stx (: & not)
      ((_ name [var : comp] not [excl ...] body ...)
       (with-syntax ([eid (datum->syntax #'name 'entity-id)])
         #'(set! systems (append systems
             (list (list 'name '(comp) '(excl ...)
                         (lambda (eid var) body ...)))))))
      ((_ name [var : comp] body ...)
       (with-syntax ([eid (datum->syntax #'name 'entity-id)])
         #'(set! systems (append systems
             (list (list 'name '(comp) '()
                         (lambda (eid var) body ...)))))))
      ((_ name [var : comp & rest ...] not [excl ...] body ...)
       #'(system-aux name [var : comp & rest ...] (excl ...) body ...))
      ((_ name [var : comp & rest ...] body ...)
       #'(system-aux name [var : comp & rest ...] () body ...)))))

(define-syntax system-aux
  (lambda (stx)
    (syntax-case stx (: &)
      ((_ name [var : comp] (excl ...) body ...)
       (with-syntax ([eid (datum->syntax #'name 'entity-id)])
         #'(set! systems (append systems
             (list (list 'name '(comp) '(excl ...)
                         (lambda (eid var) body ...)))))))
      ((_ name [var : comp & rest ...] (excl ...) body ...)
       #'(system-aux-acc name [rest ...] (comp) (excl ...) (var) body ...)))))

(define-syntax system-aux-acc
  (lambda (stx)
    (syntax-case stx (: &)
      ((_ name [var : comp] (comps ...) (excl ...) (vars ...) body ...)
       (with-syntax ([eid (datum->syntax #'name 'entity-id)])
         #'(set! systems (append systems
             (list (list 'name '(comps ... comp) '(excl ...)
                         (lambda (eid vars ... var) body ...)))))))
      ((_ name [var : comp & rest ...] (comps ...) (excl ...) (vars ...) body ...)
       #'(system-aux-acc name [rest ...] (comps ... comp) (excl ...) (vars ... var) body ...)))))

;;;; ============================================================
;;;; EVENTS
;;;; ============================================================

(define-syntax event
  (syntax-rules ()
    ((_ name [field ...])
     (set! event-types (cons '(name field ...) event-types)))))

(define-syntax emit
  (syntax-rules ()
    ((_ name [field val] ...)
     (set! event-queue
           (append event-queue
                   (list (list 'name (list 'field val) ...)))))))

(define-syntax on
  (syntax-rules ()
    ((_ name [field ...] body ...)
     (set! event-handlers
           (append event-handlers
                   (list (cons 'name (lambda (field ...) body ...))))))))

(define (dispatch)
  (for-each
    (lambda (ev)
      (let ((handler (assoc (car ev) event-handlers)))
        (when handler
          (apply (cdr handler) (map cadr (cdr ev))))))
    event-queue)
  (set! event-queue '()))

;;;; ============================================================
;;;; RUN
;;;; ============================================================

(define (run-systems)
  (for-each
    (lambda (sys)
      (let ((required (cadr  sys))
            (excluded (caddr sys))
            (proc     (cadddr sys)))
        (for-each
          (lambda (e) (apply proc (car e) (cdr e)))
          (query required excluded))))
    systems))

(define (run)
  (run-systems)
  (dispatch))
