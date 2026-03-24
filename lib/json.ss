;;; json.ss

;;;; ============================================================
;;;; READER
;;;; ============================================================

(define (json-parse str)
  (let ((pos 0)
        (len (string-length str)))

    (define (peek)
      (and (< pos len) (string-ref str pos)))

    (define (advance!)
      (set! pos (+ pos 1)))

    (define (consume! ch)
      (unless (eqv? (peek) ch)
        (error "json-parse" "expected" ch "at" pos))
      (advance!))

    (define (skip-whitespace!)
      (let loop ()
        (let ((c (peek)))
          (when (and c (char-whitespace? c))
            (advance!)
            (loop)))))

    (define (read-string)
      (consume! #\")
      (let loop ((chars '()))
        (let ((c (peek)))
          (cond
            ((not c)   (error "json-parse" "unterminated string"))
            ((eqv? c #\")
             (advance!)
             (list->string (reverse chars)))
            ((eqv? c #\\)
             (advance!)
             (let ((esc (peek)))
               (advance!)
               (loop (cons (case esc
                             ((#\") #\")
                             ((#\\) #\\)
                             ((#\/) #\/)
                             ((#\n) #\newline)
                             ((#\r) #\return)
                             ((#\t) #\tab)
                             (else esc))
                           chars))))
            (else
             (advance!)
             (loop (cons c chars)))))))

    (define (read-number)
      (let loop ((chars '()))
        (let ((c (peek)))
          (if (and c (or (char-numeric? c)
                         (memv c '(#\- #\+ #\. #\e #\E))))
              (begin (advance!) (loop (cons c chars)))
              (let ((s (list->string (reverse chars))))
                (string->number s))))))

    (define (read-array)
      (consume! #\[)
      (skip-whitespace!)
      (if (eqv? (peek) #\])
          (begin (advance!) '())
          (let loop ((items (list (read-value))))
            (skip-whitespace!)
            (cond
              ((eqv? (peek) #\])
               (advance!)
               (reverse items))
              ((eqv? (peek) #\,)
               (advance!)
               (skip-whitespace!)
               (loop (cons (read-value) items)))
              (else
               (error "json-parse" "expected , or ] in array"))))))

    (define (read-object)
      (consume! #\{)
      (skip-whitespace!)
      (if (eqv? (peek) #\})
          (begin (advance!) '())
          (let loop ((pairs '()))
            (skip-whitespace!)
            (let* ((key  (read-string))
                   (_    (begin (skip-whitespace!) (consume! #\:) (skip-whitespace!)))
                   (val  (read-value))
                   (pair (cons key val)))
              (skip-whitespace!)
              (cond
                ((eqv? (peek) #\})
                 (advance!)
                 (reverse (cons pair pairs)))
                ((eqv? (peek) #\,)
                 (advance!)
                 (loop (cons pair pairs)))
                (else
                 (error "json-parse" "expected , or } in object")))))))

    (define (read-literal str val)
      (let loop ((i 0))
        (when (< i (string-length str))
          (consume! (string-ref str i))
          (loop (+ i 1))))
      val)

    (define (read-value)
      (skip-whitespace!)
      (let ((c (peek)))
        (cond
          ((eqv? c #\")  (read-string))
          ((eqv? c #\{)  (read-object))
          ((eqv? c #\[)  (read-array))
          ((eqv? c #\t)  (read-literal "true"  #t))
          ((eqv? c #\f)  (read-literal "false" #f))
          ((eqv? c #\n)  (read-literal "null"  'null))
          ((or (char-numeric? c) (eqv? c #\-)) (read-number))
          (else (error "json-parse" "unexpected character" c "at" pos)))))

    (read-value)))

(define (json-load path)
  (call-with-input-file path
    (lambda (port)
      (json-parse (get-string-all port)))))

(define (json-get obj key)
  (let ((pair (assoc key obj)))
    (if pair (cdr pair) #f)))

(define (json-null? v)   (eq? v 'null))
(define (json-false? v)  (eq? v #f))
(define (json-value? v)  (not (eq? v #f)))
