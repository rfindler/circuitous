#lang racket/base
(provide convert-P
         propagate/remove*
         propagate*
         rename*
         replace*
         rename*/freshen
         rename**
         replace-p*
         classical
         constructive
         convert-p
         rename-internals
         vars-class
         vars-con
         (rename-out
          [FV-con FV]))
(require redex/reduction-semantics
         racket/list)
(module+ test (require rackunit))

(define-language constructive
  (P ::= (e ...))
  (e ::= (a = p))
  (p q ::= (and p q) (or p q) (not p) const a)
  (a b c ::= variable-not-otherwise-mentioned)
  (const ::= true false ⊥)
  (C ::=
     hole
     (and C p)
     (and p C)
     (or C p)
     (or p C)
     (not C)))

(define-language classical
  (P ::= (e ...))
  (e ::= (a = p))
  (p q ::= (and p q) (or p q) (not p) const a)
  (a b c ::= (ann a*) a*)
  (ann ::= + -)
  (a* b* ::= variable-not-otherwise-mentioned)
  (const ::= true false)
  (C ::=
     hole
     (and C p)
     (and p C)
     (or C p)
     (or p C)
     (not C)))

(define-union-language both (class: classical) (con: constructive))


(define-metafunction both
  convert-P : con:P -> class:P
  [(convert-P ()) ()]
  [(convert-P (con:e_1 con:e ...))
   (class:e_1 class:e_2 class:e_rest ...)
   (where (class:e_1 class:e_2)
          (convert-e con:e_1))
   (where (class:e_rest ...)
          (convert-P (con:e ...)))])

(define-metafunction both
  convert-e : con:e -> (class:e class:e)
  [(convert-e (con:a = con:p))
   (((+ con:a) = (convert-p + con:p))
    ((- con:a) = (convert-p - con:p)))])

(define-extended-language both+implies both
  (con:p con:q ::= .... (implies con:p con:q))
  (class:p class:q ::= .... (implies class:p class:q)))
(define-metafunction both+implies
  convert-p : class:ann con:p -> class:p
  [(convert-p + (and con:p con:q))
   (and (convert-p + con:p) (convert-p + con:q))]
  [(convert-p - (and con:p con:q))
   (or (convert-p - con:p) (convert-p - con:q))]
  [(convert-p + (or con:p con:q))
   (or (convert-p + con:p) (convert-p + con:q))]
  [(convert-p - (or con:p con:q))
   (and (convert-p - con:p) (convert-p - con:q))]
  [(convert-p - (not con:p))
   (convert-p + con:p)]
  [(convert-p + (not con:p))
   (convert-p - con:p)]
  [(convert-p class:ann con:a)
   (class:ann con:a)]
  [(convert-p + true)
   true]
  [(convert-p - true)
   false]
  [(convert-p + false)
   false]
  [(convert-p - false)
   true]
  [(convert-p + ⊥)
   false]
  [(convert-p - ⊥)
   false]
  ;; TODO this are not validated
  [(convert-p + (implies con:p con:q))
   (or (convert-p - con:p)
       (and (convert-p + con:p)
            (convert-p + con:q)))]
  [(convert-p - (implies con:p con:q))
   (and (convert-p + con:p)
        (convert-p - con:q))])

(module+ test
  (check-equal?
   (term (convert-P ((a = b))))
   (term (((+ a) = (+ b)) ((- a) = (- b))))))

(define-metafunction classical
  remove : P a ... -> P
  [(remove P) P]
  [(remove (e_1 ... (a = p) e_2 ...) a b ...)
   (remove (e_1 ... e_2 ...) b ...)])

(define-metafunction classical
  propagate/remove* : P a ... -> P
  [(propagate/remove* P a ...)
   (remove (propagate* P a ...) a ...)])

(define-metafunction classical
  propagate* : P a ... -> P
  [(propagate* P) P]
  [(propagate* P a b ...)
   (propagate* (propagate P a) b ...)])

(define-metafunction classical
  propagate : P a -> P
  [(propagate P a)
   (replace P a (get a P))])

(define-metafunction classical
  get : a P -> p
  [(get a (_ ... (a = p) _ ...))
   p])

(define-metafunction classical
  rename* : P a a -> P
  [(rename* P a_1 a_2)
   (e_1 ... (a_2 = p) e_2 ...)
   (where (e_1 ... (a_1 = p) e_2 ...)
          (replace* P (a_1 a_2)))]
  [(rename* P a_1 a_2)
   (replace* P (a_1 a_2))])

(define-metafunction classical
  rename** : P (a a) ... -> P
  [(rename** P) P]
  [(rename** P (a_1 a_2) (b_1 b_2) ...)
   (rename** (rename* P a_1 a_2)
             (b_1 b_2) ...)])


(define-metafunction classical
  replace* : P (p p) ... -> P
  [(replace* P) P]
  [(replace* P (q_1 q_2) any_r ...)
   (replace* (replace P q_1 q_2) any_r ...)])

(define-metafunction classical
  replace : P p p -> P
  [(replace ((a = p) ...) q_1 q_2)
   ((a = (replace-p p q_1 q_2)) ...)])
(define-metafunction classical
  replace-p* : (p ...) (p p) ... -> (p ...)
  [(replace-p* (p ...)) (p ...)]
  [(replace-p* (p ...)
               (p_1 p_2)
               (p_3 p_4) ...)
   (replace-p*
    ((replace-p p p_1 p_2) ...)
    (p_3 p_4) ...)])
(define-metafunction classical
  replace-p : p p p -> p
  [(replace-p q_1 q_1 q_2)
   q_2]
  [(replace-p (not p) q_1 q_2)
   (not (replace-p p q_1 q_2))]
  [(replace-p (and p q)  q_1 q_2)
   (and (replace-p p q_1 q_2)
        (replace-p q q_1 q_2))]
  [(replace-p (or p q)  q_1 q_2)
   (or (replace-p p q_1 q_2)
       (replace-p q q_1 q_2))]
  [(replace-p p_other  q_1 q_2)
   p_other])

(define-metafunction constructive
  rename*/freshen : ((a b) ...) P (a b) ... P -> (((a b) ...) P)
  [(rename*/freshen ((a_reg b_reg) ...) P (a b) ... P_i)
   (((a_regv b_regv) ...)
    (rename** P
              (a b) ...
              (a_v b_v) ...))
   (where (a_v ...)
          ,(remove*
            (term (a ...))
            (term (variables P))))
   (where (b_v ...)
          ,(variables-not-in
            (term (b ... P_i))
            (term (a_v ...))))
   (where ((a_regv = b_regv) ...)
          (rename** ((a_reg = b_reg) ...)
                    (a b) ...
                    (a_v b_v) ...)) ])
                             
  


(define-metafunction classical
  variables : P -> (a ...)
  [(variables ((a = p) ...))
   ,(remove-duplicates (term (a ... b ... ...)))
   (where ((b ...) ...)
          ((vars-p p) ...))])

(define-metafunction classical
  vars-p : p -> (a ...)
  [(vars-p a) (a)]
  [(vars-p (_ p q))
   (a ... b ...)
   (where (a ...) (vars-p p))
   (where (b ...) (vars-p q))]
  [(vars-p (not p)) (vars-p p)]
  [(vars-p const) ()])

(define-metafunction constructive
  FV-con : P -> (a ...)
  [(FV-con ((a = p) ...))
   ,(remove-duplicates
     (remove* (term (a ...))
              (term (b ... ...))))
   (where ((b ...) ...)
          ((vars-con p) ...))])
(define-metafunction classical
  FV-class : P -> (a ...)
  [(FV-class ((a = p) ...))
   ,(remove-duplicates
     (remove* (term (a ...))
              (term (b ... ...))))
   (where ((b ...) ...)
          ((vars-class p) ...))])

(define-metafunction constructive
  all-vars-con : P -> (a ...)
  [(all-vars-con ((a = p) ...))
   ,(remove-duplicates (term (a ... b ... ...)))
   (where ((b ...) ...) ((vars-con p) ...))])
(define-metafunction constructive
  vars-con : p -> (a ...)
  [(vars-con (and p q))
   (a ... b ...)
   (where (a ...) (vars-con p))
   (where (b ...) (vars-con q))]
  [(vars-con (or p q))
   (a ... b ...)
   (where (a ...) (vars-con p))
   (where (b ...) (vars-con q))]
  [(vars-con (not p)) (vars-con p)]
  [(vars-con a) (a)]
  [(vars-con const) ()])
(define-metafunction classical
  all-vars-class : P -> (a ...)
  [(all-vars-class ((a = p) ...))
   ,(remove-duplicates (term (a ... b ... ...)))
   (where ((b ...) ...) ((vars-class p) ...))])
(define-metafunction classical
  vars-class : p -> (a ...)
  [(vars-class (and p q))
   (a ... b ...)
   (where (a ...) (vars-class p))
   (where (b ...) (vars-class q))]
  [(vars-class (or p q))
   (a ... b ...)
   (where (a ...) (vars-class p))
   (where (b ...) (vars-class q))]
  [(vars-class (not p)) (vars-class p)]
  [(vars-class a) (a)]
  [(vars-class const) ()])

;; rename any internal wires in each circuit that would
;; conflict with the other circuit to a new name not in either circuit
;; expects the interfaces to be deduplicated already
(define (rename-internals P1 P2
                           #:c1-regs c1r
                           #:c2-regs c2r
                          #:c1-interface c1i
                          #:c2-interface c2i)
  (cond
    [(redex-match? constructive P P1)
     (define P1-unsafe-internals (remove* c1i (term (all-vars-con ,P2))))
     (define P2-unsafe-internals (remove* c2i (term (all-vars-con ,P1))))
     (define r1 (term (freshen-names-con ,P1 ,P1-unsafe-internals ,c1r ,(append c2r c2i P2))))
     (append
      r1
      (term (freshen-names-con ,P2 ,P2-unsafe-internals ,c2r ,(append c1r c1i P1 r1))))]
    [else
     (define P1-unsafe-internals (remove* c1i (term (all-vars-class ,P2))))
     (define P2-unsafe-internals (remove* c2i (term (all-vars-class ,P1))))
     (define r1 (term (freshen-names-class ,P1 ,P1-unsafe-internals ,c1r ,(append c2r c2i P2))))
     (append
      r1
      (term (freshen-names-class ,P2 ,P2-unsafe-internals ,c2r ,(append c1r c1i P1 r1))))]))

(module+ test
  (check-equal?
   (rename-internals
    (term ((a = (and a a))))
    (term ((b = (and a a))))
    #:c1-regs empty
    #:c2-regs empty
    #:c1-interface empty
    #:c2-interface (term (a b)))
   (term
    (((a1 = (and a1 a1)))
     ()
     ((b = (and a a)))
     ())))
  (check-equal?
   (rename-internals
    (term (((+ a) = (and (+ a) (+ a)))
           ((- a) = (or (- a) (- a)))))
    (term (((+ b) = (and (+ a) (+ a)))
           ((- b) = (or (- a) (- a)))))
    #:c1-regs empty
    #:c2-regs empty
    #:c1-interface empty
    #:c2-interface (term ((+ a) (- a) (+ b) (- b))))
   (list
    (term (((+ a1) = (and (+ a1) (+ a1)))
           ((- a1) = (or (- a1) (- a1)))))
    '()
    (term (((+ b) = (and (+ a) (+ a)))
           ((- b) = (or (- a) (- a)))))
    '()))

  (check-equal?
   (rename-internals
    (term ((a = (and a a))
           (b = q)))
    (term ((b = q)
           (a = true)))
    #:c1-regs '((a q))
    #:c2-regs '((a q))
    #:c1-interface empty
    #:c2-interface (term (a b)))
   (term
    (((a1 = (and a1 a1))
      (b1 = q1))
     ((a1 q1))
     ((b = q2) (a = true))
     ((a q2)))))
  
  (check-equal?
   (rename-internals
    (term (((+ a) = (and (+ a) (+ a)))
           ((- a) = (or (- a) (- a)))
           ((+ b) = (+ q))
           ((- b) = (- q))))
    (term (((+ b) = (+ q))
           ((- b) = (- q))
           ((+ a) = true)
           ((- a) = false)))
    #:c1-regs '(((+ a) (+ q)) ((- a) (- q)))
    #:c2-regs '(((+ a) (+ q)) ((- a) (- q)))
    #:c1-interface empty
    #:c2-interface (term ((+ a) (- a) (+ b) (- b))))
   (list
    (term (((+ a1) = (and (+ a1) (+ a1)))
           ((- a1) = (or (- a1) (- a1)))
           ((+ b1) = (+ q1))
           ((- b1) = (- q1))))
    '(((+ a1) (+ q1)) ((- a1) (- q1)))
    (term (((+ b) = (+ q2))
           ((- b) = (- q2))
           ((+ a) = true)
           ((- a) = false)))
    '(((+ a) (+ q2)) ((- a) (- q2)))))

  (check-equal?
   (rename-internals
    (term ((a = a)
           (a1 = a1)))
    #:c1-regs empty
    #:c1-interface empty
    (term ((a = a)
           (a1 = a1)))
    #:c2-regs empty
    #:c2-interface empty)
   (list
    (term ((a2 = a2)
           (a3 = a3)))
    empty
    (term ((a4 = a4)
           (a5 = a5)))
    empty))
  (check-equal?
   (rename-internals
    (term (((+ a) = (+ a))
           ((- a) = (- a))
           ((+ a1) = (+ a1))
           ((- a1) = (- a1))))
    #:c1-regs empty
    #:c1-interface empty
    (term (((+ a) = (+ a))
           ((- a) = (- a))
           ((+ a1) = (+ a1))
           ((- a1) = (- a1))))
    #:c2-regs empty
    #:c2-interface empty)
   (list
    (term (((+ a3) = (+ a3))
           ((- a3) = (- a3))
           ((+ a2) = (+ a2))
           ((- a2) = (- a2))))
    empty
    (term (((+ a5) = (+ a5))
           ((- a5) = (- a5))
           ((+ a4) = (+ a4))
           ((- a4) = (- a4))))
    empty)))
    


;; rename everything in the given variable set to a fresh name
(define-metafunction constructive
  [(freshen-names-con (e ...) (a ...) ((a_r b_r) ...) any)
   ((e_o ...)
    (unnest-ors p))
   (where a_random
          ,(variable-not-in (term (e ... a ... a_r ... b_r ... any))
                            'random))
   (where
    ((_ = p)
     e_o ...)
    (rename** ((a_random = (nest-ors (a_r b_r) ...)) e ...)
              ,@(map list
                     (term (a ...))
                     (variables-not-in (term (e ... any a ... a_r ... b_r ... a_random)) (term (a ...))))))])

(define-metafunction classical
  [(freshen-names-class P () ((a_r b_r) ...) any)
   (P ((a_r b_r) ...))]
  [(freshen-names-class P (a* a ...) ((a_r b_r) ...) any)
   ((rename** P_r (a* ,(variable-not-in (term (P_r any a ...)) (term a*))))
    ((a_ro b_ro) ...))
   (where (P_r ((a_ro b_ro) ...)) (freshen-names-class P (a ...) ((a_r b_r) ...) any))]
  [(freshen-names-class P
                        ((ann a*) a ... (ann_2 a*) b ...)
                        ((a_r b_r) ...)
                        any)
   ((e_o ...)
    (unnest-ors p))
   (where ((e ...) ((a_ro b_ro) ...)) (freshen-names-class P (a ... b ...) ((a_r b_r) ...) any))
   (where b* ,(variable-not-in (term (e ... P any a ... b ... a_ro ... b_ro ... a_r ... b_r ...))
                               (term a*)))
   (where a_random
          ,(variable-not-in (term (P e ... a ... a_ro ... b_ro ... a_r ... b_r ... b* any))
                            'random))
   (where
    ((_ = p)
     e_o ...)
    (rename** ((a_random = (nest-ors (a_ro b_ro) ...)) e ...)
              ((ann a*) (ann b*))
              ((ann_2 a*) (ann_2 b*))))])



(define-metafunction classical
  nest-ors : (a a) ... -> p
  [(nest-ors) false]
  [(nest-ors (a b) (a_r b_r) ...)
   (or (or a b) (nest-ors (a_r b_r) ...))])
(define-metafunction classical
  unnest-ors : p -> ((a a) ...)
  [(unnest-ors false) ()]
  [(unnest-ors (or (or a b) p))
   ((a b) (a_r b_r) ...)
   (where ((a_r b_r) ...) (unnest-ors p))])
  

  
  
