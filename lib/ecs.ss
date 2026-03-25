;;; ecs.ss

;;;; ============================================================
;;;; GLOBAL STATE
;;;; ============================================================

(define entities              (make-eq-hashtable))
(define component-defs        (make-eq-hashtable))
(define pipeline              '())
(define event-queue           '())
(define event-handlers        '())
(define global-event-handlers '())
(define scenes                '())
(define current-scene         #f)
(define next-id               0)

;;;; ============================================================
;;;; INTERNAL HELPERS
;;;; ============================================================

(define (hashtable-for-each ht proc)
  (vector-for-each proc
                   (hashtable-keys   ht)
                   (hashtable-values ht)))

(define (entity-ref id)
  (hashtable-ref entities id #f))

(define (comp-ref id comp-name)
  (let ((e (entity-ref id)))
    (and e (hashtable-ref e comp-name #f))))

(define (next-id!)
  (set! next-id (+ next-id 1))
  next-id)

;;;; ============================================================
;;;; COMPONENT
;;;; ============================================================

(define-syntax component
  (syntax-rules ()
    ((_ name (field ...))
     (hashtable-set! component-defs 'name '(field ...)))
    ((_ name)
     (hashtable-set! component-defs 'name '()))))

(define (make-component comp-name field-vals)
  (let* ((fields (hashtable-ref component-defs comp-name
                   (lambda () (error "unknown component" comp-name))))
         (ht     (make-eq-hashtable)))
    (unless (= (length field-vals) (length fields))
      (error "make-component: wrong number of fields"
             comp-name
             (string-append "expected " (number->string (length fields))
                            ", got "    (number->string (length field-vals)))))
    (for-each (lambda (f)
                (let ((given (assq f field-vals)))
                  (hashtable-set! ht f (if given (cadr given) #f))))
              fields)
    ht))

;;;; ============================================================
;;;; ENTITY
;;;; ============================================================

(define (make-entity comp-list)
  (let ((id (next-id!))
        (ht (make-eq-hashtable)))
    (for-each (lambda (pair)
                (hashtable-set! ht (car pair) (cdr pair)))
              comp-list)
    (hashtable-set! entities id ht)
    id))

(define-syntax entity
  (syntax-rules ()
    ((_ name (comp val ...) ...)
     (define name
       (make-entity
         (list (cons 'comp
                     (make-component 'comp
                       (map list
                            (hashtable-ref component-defs 'comp '())
                            '(val ...))))
               ...))))))

(define-syntax spawn
  (syntax-rules ()
    ((_ (comp val ...) ...)
     (make-entity
       (list (cons 'comp
                   (make-component 'comp
                     (map list
                          (hashtable-ref component-defs 'comp '())
                          '(val ...))))
             ...)))))

(define (despawn id)
  (hashtable-delete! entities id))

;;;; ============================================================
;;;; COMPONENT ACCESS
;;;; ============================================================

(define (has-component? id comp-name)
  (let ((e (entity-ref id)))
    (and e (hashtable-contains? e comp-name))))

(define-syntax add-component
  (syntax-rules ()
    ((_ id comp)
     (let ((e (entity-ref id)))
       (if e
           (hashtable-set! e 'comp (make-component 'comp '()))
           (error "add-component: entity not found" id))))
    ((_ id comp (field val) ...)
     (let ((e (entity-ref id)))
       (if e
           (hashtable-set! e 'comp
             (make-component 'comp (list (list 'field val) ...)))
           (error "add-component: entity not found" id))))))

(define-syntax remove-component
  (syntax-rules ()
    ((_ id comp)
     (let ((e (entity-ref id)))
       (when e (hashtable-delete! e 'comp))))))

(define (comp-get comp-ht field)
  (hashtable-ref comp-ht field
    (lambda () (error "comp-get: unknown field" field))))

(define (comp-set! comp-ht field val)
  (hashtable-set! comp-ht field val))

(define (field-get id comp-name field)
  (let ((c (comp-ref id comp-name)))
    (if c
        (comp-get c field)
        (error "field-get: component not found" comp-name id))))

(define (field-set! id comp-name field val)
  (let ((c (comp-ref id comp-name)))
    (if c
        (comp-set! c field val)
        (error "field-set!: component not found" comp-name id))))

(define-syntax get
  (syntax-rules ()
    ((_ comp field)     (comp-get  comp     'field))
    ((_ id comp field)  (field-get id 'comp 'field))))

(define-syntax put!
  (syntax-rules ()
    ((_ comp field expr)     (comp-set!  comp     'field expr))
    ((_ id comp field expr)  (field-set! id 'comp 'field expr))))

;;;; ============================================================
;;;; QUERY
;;;; ============================================================

(define (query required . rest)
  (let ((excluded (if (null? rest) '() (car rest)))
        (acc      '()))
    (hashtable-for-each entities
      (lambda (id comp-ht)
        (define (has-all?)
          (for-all (lambda (n) (hashtable-contains? comp-ht n)) required))
        (define (has-none?)
          (not (exists (lambda (n) (hashtable-contains? comp-ht n)) excluded)))
        (when (and (has-all?) (has-none?))
          (set! acc
            (cons (cons id (map (lambda (n) (hashtable-ref comp-ht n #f))
                                required))
                  acc)))))
    acc))

;;;; ============================================================
;;;; SYSTEM
;;;; ============================================================

(define-syntax system
  (lambda (stx)
    (syntax-case stx (: not)
      ((_ name ((var : comp) ...) not (excl ...) body ...)
       (with-syntax ([eid (datum->syntax #'name 'entity-id)])
         #'(set! pipeline
             (cons (list 'entity 'name '(comp ...) '(excl ...)
                         (lambda (eid var ...) body ...))
                   pipeline))))
      ((_ name ((var : comp) ...) body ...)
       (with-syntax ([eid (datum->syntax #'name 'entity-id)])
         #'(set! pipeline
             (cons (list 'entity 'name '(comp ...) '()
                         (lambda (eid var ...) body ...))
                   pipeline)))))))

;;;; ============================================================
;;;; GLOBAL SYSTEM
;;;; ============================================================

(define-syntax global-system
  (syntax-rules ()
    ((_ name body ...)
     (set! pipeline
           (cons (list 'global 'name (lambda () body ...))
                 pipeline)))))

;;;; ============================================================
;;;; EVENTS
;;;; ============================================================

(define event-defs (make-eq-hashtable))

(define-syntax event
  (syntax-rules ()
    ((_ name (field ...))
     (hashtable-set! event-defs 'name '(field ...)))))

(define-syntax emit
  (syntax-rules ()
    ((_ name (field val) ...)
     (begin
       (let ((expected (hashtable-ref event-defs 'name #f)))
         (when expected
           (let ((given '(field ...)))
             (unless (equal? (list->vector (sort given symbol<?))
                             (list->vector (sort expected symbol<?)))
               (error "emit: wrong fields for event" 'name
                      (string-append "expected: "
                                     (apply string-append
                                            (map (lambda (s)
                                                   (string-append (symbol->string s) " "))
                                                 expected))
                                     "got: "
                                     (apply string-append
                                            (map (lambda (s)
                                                   (string-append (symbol->string s) " "))
                                                 given)))))))))
       (set! event-queue
             (append event-queue
                     (list (list 'name (list 'field val) ...)))))))

(define-syntax on
  (syntax-rules ()
    ((_ name (field ...) body ...)
     (set! event-handlers
           (cons (cons 'name (lambda (field ...) body ...))
                 event-handlers)))))

(define-syntax on-global
  (syntax-rules ()
    ((_ name (field ...) body ...)
     (set! global-event-handlers
           (cons (cons 'name (lambda (field ...) body ...))
                 global-event-handlers)))))

(define (dispatch)
  (let ((current-queue event-queue))
    (set! event-queue '())
    (for-each
      (lambda (ev)
        (let ((ev-name (car ev))
              (args    (map cadr (cdr ev))))
          (for-each
            (lambda (h)
              (when (eq? (car h) ev-name)
                (apply (cdr h) args)))
            (append (reverse event-handlers)
                    (reverse global-event-handlers)))))
      current-queue)))

;;;; ============================================================
;;;; SCENE
;;;; ============================================================

(define-syntax scene
  (syntax-rules (on-enter on-exit)
    ((_ name
        (on-enter enter-body ...)
        (on-exit  exit-body  ...))
     (set! scenes
           (cons (list 'name
                       (lambda () enter-body ...)
                       (lambda () exit-body  ...))
                 scenes)))))

(define (go-to* name)
  (when current-scene
    (let ((cur (assq current-scene scenes)))
      (when cur ((caddr cur)))))

  (set! pipeline              '())
  (set! event-handlers        '())
  (set! event-queue           '())

  (let ((to-remove '()))
    (hashtable-for-each entities
      (lambda (id comp-ht)
        (unless (hashtable-contains? comp-ht 'persistent)
          (set! to-remove (cons id to-remove)))))
    (for-each despawn to-remove))

  (set! current-scene name)
  (let ((next (assq name scenes)))
    (if next
        ((cadr next))
        (error "go-to: scene not found" name))))

(define-syntax go-to
  (syntax-rules ()
    ((_ name) (go-to* 'name))))

;;;; ============================================================
;;;; RUN
;;;; ============================================================

(define (run-systems)
  (for-each
    (lambda (entry)
      (case (car entry)
        ((entity)
         (let ((required (list-ref entry 2))
               (excluded (list-ref entry 3))
               (proc     (list-ref entry 4)))
           (for-each
             (lambda (e) (apply proc (car e) (cdr e)))
             (query required excluded))))
        ((global)
         ((list-ref entry 2)))))
    (reverse pipeline)))

(define (run)
  (run-systems)
  (dispatch))
