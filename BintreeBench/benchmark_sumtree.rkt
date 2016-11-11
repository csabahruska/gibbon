#lang typed/racket/base

;; WARNING: Code duplication with benchmark_buildtree.rkt

(require "command_line_runner.rkt" racket/system)

(system "make sumtree")

(define PASSNAME "sumtree")

(launch-benchmarks "./sumtree_treelang_c_packed.exe -benchmark " PASSNAME "treelang-c-packed")

(launch-benchmarks "racket sumtree_treelang.sexp " PASSNAME "treelang-racket")

;; NEW

(launch-benchmarks "./treebench_mlton.exe " PASSNAME "handwritten-mlton")