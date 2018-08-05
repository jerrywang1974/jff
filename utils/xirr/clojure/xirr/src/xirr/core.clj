(ns xirr.core
  (:require [clojure.string :as str]
            [clojure.java.io :as io])
  (:gen-class))

(import [java.time LocalDate])
(import [java.time.format DateTimeFormatter])

; http://commons.apache.org/proper/commons-math/userguide/analysis.html
(import [org.apache.commons.math3.analysis UnivariateFunction])
(import [org.apache.commons.math3.analysis.solvers
         BisectionSolver BrentSolver BracketingNthOrderBrentSolver
         FieldBracketingNthOrderBrentSolver IllinoisSolver
         MullerSolver MullerSolver2 PegasusSolver RegulaFalsiSolver
         RiddersSolver SecantSolver])

(defn read-ledger [path & options]
  (let [{:keys [has-header date-formatter]
         :or {has-header true date-formatter DateTimeFormatter/ISO_LOCAL_DATE}} options]
    (with-open [reader (io/reader path)]
      (mapv (fn [line]
              (let [cols (str/split line #"\s+|,")]
                (into [(LocalDate/parse (first cols) date-formatter)]
                      (map #(Double/parseDouble %) (next cols)))))
            (let [lines (line-seq reader)]
              (if has-header
                (next lines)
                lines))))))

(defn interval-days [from to]
  (- (.toEpochDay to) (.toEpochDay from)))

(defn extract-transactions [ledger n]
  (let [day0 (first (first ledger))
        last (ledger (- n 1))]
    (conj (mapv #(vector (interval-days day0 (% 0)) (% 1))
                (take (- n 1) ledger))
          [(interval-days day0 (last 0)) (last 2)])))

;; net present value:
;;   x = 1 / (1 + r)
;;   npv = \sum_{i=0}^n C_i * x^{i/365}, where `i` refers days.
;;   series = [[days transaction]...]
(defn npv-fn [series]
  (fn [x]
    (reduce + (map #(* (% 1)
                       (Math/pow x (/ (% 0) 365.0)))
                   series))))

(defn npv-derivative-fn [series]
  (fn [x]
    (reduce + (map #(* (% 1)
                       (/ (% 0) 365.0)
                       (Math/pow x (- (/ (% 0) 365.0) 1.0)))
                   series))))

(defn npv-functor [fn]
  (reify UnivariateFunction
    (value [this x]
      (fn x))))

(defn xirr [series & options]
  (let [{:keys [solver iter min max initial]
         :or {solver (BracketingNthOrderBrentSolver.)
              iter 10000
              min -0.999999
              max 10.0
              initial 0.1}} options]
    (- (/ 1.0 (.solve solver
                      iter
                      (npv-functor (npv-fn series))
                      (/ 1.0 (+ 1.0 max))
                      (/ 1.0 (+ 1.0 min))
                      (/ 1.0 (+ 1.0 initial))))
       1.0)))

(defn -main
  [& args]
  (let [ledger (read-ledger (first args))
        row0 (ledger 0)
        fmt "%s\t%s\t%s\t%s\n"]
    (printf fmt "date" "transaction" "asset" "xirr")
    (printf fmt (row0 0) (row0 1) (row0 2) 0.0)
    (doseq [i (range 1 (count ledger))]
      (let [row (ledger i)
            rate (xirr (extract-transactions ledger (inc i)))]
        (printf fmt (row 0) (row 1) (row 2) (* rate 100.0))))))
