# go-ndarray documentation

**A pure-Go (no cgo) NumPy-style n-dimensional array** for `float64` — the
`numpy` equivalent for Go. Creation routines, strided **views that share data**,
broadcasting elementwise ops and ufuncs, reductions, manipulation and linear
algebra, all with cgo disabled.

Ruby has no cgo-free ndarray (`Numo::NArray`, `NMatrix` are C extensions) and
`gonum`'s optimized assembly is amd64-only. go-ndarray pairs a portable scalar
core with **multicore fan-out + go-asmgen SIMD**, beating single-threaded NumPy
on the parallelizable core. **100% coverage**, differentially checked against
numpy 2.2.

```go
import nd "github.com/go-ndarray/ndarray"

a := nd.Arange(0, 6).Reshape(2, 3)
a.Sum()              // 15
a.Transpose().Shape() // [3 2]
```

## API surface

| Area | Functions / methods |
| --- | --- |
| Creation | `Zeros`, `Ones`, `Full`, `Arange`, `Linspace`, `Eye`, `FromData` |
| Views & shape | `Slice` (`All`/`R`/`Rng`/`From`/`To`/`Step`), `Reshape`, `Ravel`, `Transpose`, `Copy` |
| Elementwise | `Add`/`Sub`/`Mul`/`Div` (+`*Scalar`, +`*Into`), `Map`, `Neg`, `Abs` |
| Ufuncs | `Sqrt`, `Exp`, `Log`/`Log2`/`Log10`, `Sin`/`Cos`/`Tan`, `Floor`/`Ceil`/`Round`, `Square`, `Power` |
| Reductions | `Sum`, `Mean`, `Max`/`Min`, `Prod`, `ArgMax`/`ArgMin`, `CumSum`/`CumProd`, `Clip`, `Where` (+ per-axis) |
| Manipulation | `Flatten`, `ExpandDims`, `Squeeze`, `Concatenate`, `Stack`, `VStack`, `HStack` |
| Linear algebra | `MatMul`, `Dot`, `Inner`, `Outer` |

## Performance & architectures

The hot paths are **multicore + SIMD**: a go-asmgen sum kernel and a
panel-packed, cache-blocked GEMM with a SIMD-FMA micro-kernel (amd64 SSE2,
arm64 NEON), plus packed elementwise / sqrt / max-min kernels. The result
**beats single-threaded NumPy** on Add/Mul/Sum/Sqrt/Max and the blocked GEMM.
**MatMul reaches tuned-BLAS parity at 1024²** (≈1.00× of single-threaded vecLib,
~373 GFLOP/s; ≈0.99× vs multi-threaded OpenBLAS) and beats the pure-Go **gonum
4–10×** at every size, while **Dot (1-D) wins at parity** (~0.98×). Where tuned
BLAS still leads at small n, the benchmark page says so.

## Where to go next

- [Roadmap](roadmap.md) — the plan and what ships today.
- [Performance](performance.md) — honest benchmarks versus NumPy 2.2 / OpenBLAS.

Source: [github.com/go-ndarray/ndarray](https://github.com/go-ndarray/ndarray) ·
also the cgo-free ndarray backend behind [go-embedded-ruby](https://github.com/go-embedded-ruby/ruby)'s
`NDArray` class.
