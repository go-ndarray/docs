---
# Below the "Mirrored from" line, this page is the "Accuracy contract" section
# of go-ndarray/ndarray README.md, verbatim (README: "Mirrored pages").
title: "Accuracy contract"
linkTitle: "Accuracy"
weight: 25
description: "What go-ndarray promises about its results: a stated error bound, checked against an exact oracle, not equality with NumPy's bits."
tags: [accuracy, numpy, math/big]
---

> Mirrored from [`README.md`](https://github.com/go-ndarray/ndarray/blob/v0.40.3/README.md#accuracy-contract) at v0.40.3.

The contract is **correct, and as fast as possible**. "Correct" means a stated error bound, checked against an exact oracle. Equality with NumPy's bits is not the contract: wherever it holds today, it is how a function was ported, and a faster default that stays within its bound may replace it.

Bound: elementwise `+ − × ÷` and `Sqrt` are correctly rounded (one IEEE operation, ≤ 0.5 ULP). Float64 `Exp`/`Log` have a worst error of 0.511 / 0.519 ULP, the figures of Arm's optimized-routines, which go-simd/floats ports. Float32 `Exp`/`Log` are correctly rounded. The proof covers all 2³² inputs and lives in go-simd/floats; it runs on demand, and CI checks a sample. `Max`/`Min` are exact.

`Sum` satisfies |Ŝ − S| ≤ γ_d·Σ|xᵢ|, with γ_m = m·u/(1 − m·u), u = 2⁻⁵³ for float64 and 2⁻²⁴ for float32. d is the rounding depth of NumPy's pairwise tree: at most 24 in a leaf of up to 128 elements, plus one per halving. The bound holds for any tree at most d deep, not for a serial loop, which needs γ_{n−1}.

Every element of `MatMul`/`Dot` satisfies |Ĉᵢⱼ − Cᵢⱼ| ≤ γ_k·(|A|·|B|)ᵢⱼ, whatever the summation order, with or without FMA. Both bounds are from Higham, *Accuracy and Stability of Numerical Algorithms*, §3.1 and §4.2.

Oracle: `math/big` at 1024 bits for sums and inner products. `TestSumDepth`, `TestAccuracyBoundSum` and `TestAccuracyBoundMatMul` check them; the difference is taken in `big.Float`, so the oracle is never rounded. `Exp`/`Log` are checked against a 300-bit reference in go-simd/floats.

Exact: the defaults are still the exact ports, NumPy's pairwise order for `Sum` included, so results match NumPy bit for bit where they did before. When a faster default lands, that arithmetic stays available behind an explicit option.
