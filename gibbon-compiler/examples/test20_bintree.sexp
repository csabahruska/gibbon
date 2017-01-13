#lang gibbon

(data Tree
      [Leaf Int]
      [Node Tree Tree])

(define (build-tree [n : Int]) : Tree
  (if (= n 0)
      (Leaf 100)
      (let ([min1  : Int (- n 1)])
      (let ([l : Tree (build-tree min1)]
            [r : Tree (build-tree min1)])
        (Node l r)))))

;; Since we're not using tr0 in our result, if we don't time it, the
;; compiler will drop it:
(let ((tr0 : Tree (time (build-tree 2))))
  2222)
