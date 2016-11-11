#lang typed/racket/base

;; Run make buildtree before this

(require "command_line_runner.rkt" racket/system)

(system "make buildtree")

(define PASSNAME "buildtree")

(launch-benchmarks "./buildtree_treelang_c_packed.exe -benchmark " PASSNAME "treelang-c-packed")

(launch-benchmarks "racket buildtree_treelang.sexp " PASSNAME "treelang-racket")

;; NEW

(launch-benchmarks "./treebench_mlton.exe build " PASSNAME "handwritten-mlton")


