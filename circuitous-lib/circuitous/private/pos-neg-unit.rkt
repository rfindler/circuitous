#lang rosette/safe
(provide pos-neg@)
(require "sem-sig.rkt"
         "interp-sig.rkt"
         "shared.rkt"
         racket/unit
         racket/match
         (only-in racket/format ~a)
         (only-in racket/string string-replace)
         (only-in racket/base error))

(define-unit pos-neg@
  (import interp^)
  (export sem^)
  (define (interp-bound formula)
    (/ (length formula) 2))

  (define (constructive-constraints inputs)
    (let fold ([current inputs])
      (if
       (empty? current)
       'true
       (let ([n (first (first current))])
         (cond
           [(eq? '+ (first n))
            `(and
              (or ,n (- ,(second n)))
              ,(fold (rest current)))]
           [else (fold (rest current))])))))
  
  (define (constructive? P)
    ((build-expression (constructive-constraints P)) P))
  
  (define (get-maximal-statespace x)
    (expt 2 (inexact->exact (ceiling (/ x 2)))))
  (define (initialize-to-true i)
    (initialize-to i #t #f))
  (define (initialize-to-false i)
    (initialize-to i #f #t))
  (define (initialize-to i p m)
    (map (lambda (x)
           (if (and (list? x)
                    (equal? '+ (first x)))
               (list x p)
               (list x m)))
         i))
  (define initial-value #f)
  (define (f-or a b)
    (lambda (w)
      (or/force (a w) (b w))))
  (define (f-and a b)
    (lambda (w)
      (and/force (a w) (b w))))
  (define (f-not n)
    (lambda (w)
      (not/force (n w))))
  (define (and/force a b)
    (if (and (boolean? a) (boolean? b))
        (and a b)
        (error 'and "not boolean in (and ~a ~a)" a b)))
  (define (or/force a b)
    (if (and (boolean? a) (boolean? b))
        (or a b)
        (error 'or "not boolean in (or ~a ~a)" a b)))
  (define (not/force a)
    (if (boolean? a)
        (not a)
        (error 'not "not boolean in (not ~a)" a)))
  (define (f-implies a b)
    (lambda (w)
      (implies (a w) (b w))))
  (define (symbolic-boolean name)
    (constant (string-replace
               (~a name "$" (next-unique! name))
               " "
               "_")
              boolean?))
  (define (constraints I)
    (andmap
     (λ (x)
       (implies
        (and (list? x)
             (list? (first x))
             (eq? (first (first x)) '+)
             (contains? I `(- ,(second (first x)))))
        (not (and (second x)
                  (deref I `(- ,(second (first x))))))))
     I))

  (define (outputs=? a b #:outputs [outputs #f])
    (if outputs
        (andmap
         (lambda (w)
           (cond
             [(and (list? w) (equal? (first w) '-))
              (equal?
               (or (not (contains? a w)) (deref a w))
               (or (not (contains? b w)) (deref b w)))]
             [else
              (equal?
               (and (contains? a w) (deref a w))
               (and (contains? b w) (deref b w)))]))
         outputs)
        (andmap
         (lambda (w)
           (implies
            (contains? b (first w))
            (equal? (second w) (deref b (first w)))))
         a))))