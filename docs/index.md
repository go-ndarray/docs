# go-ndarray documentation

**A pure-Go (no cgo) NumPy-style n-dimensional array** for `float64` — the
`numpy` equivalent for Go. Creation routines, strided **views that share data**,
broadcasting elementwise ops and ufuncs, reductions, manipulation and linear
algebra, all with cgo disabled.

Ruby has no cgo-free ndarray (`Numo::NArray`, `NMatrix` are C extensions) and
`gonum`'s optimized assembly is amd64-only. go-ndarray pairs a portable pure-Go
core with **multicore fan-out + go-asmgen SIMD** (amd64, arm64, ppc64le, loong64, riscv64 and s390x),
and a **`Workspace`** arena that takes the garbage collector out of loops. **100%
coverage**, differentially checked against NumPy.

```go
import nd "github.com/go-ndarray/ndarray"

a, _ := nd.Arange(0, 6, 1)
m, _ := a.Reshape(2, 3)
m.Sum()               // 15
m.Transpose().Shape() // [3 2]
```

**Try it in your browser:** the [playground](https://go-ndarray.github.io/playground/) runs go-ndarray compiled to
WebAssembly, with nothing to install — build a pipeline step by step (creation, views, broadcasting, ufuncs, reductions, linear algebra), inspect each step's shape, strides and shared memory, and copy the equivalent Go program and NumPy code.

## API surface

| Area | Functions / methods |
| --- | --- |
| Creation | `New`, `Zeros`, `Ones`, `Full`, `Arange`, `Linspace`, `Eye`, `Identity`, `FromData` |
| Views & shape | `Slice` (`All`/`R`/`Rng`/`From`/`To`/`Step`), `Reshape`, `Ravel`, `Transpose`, `Copy` |
| Elementwise | `Add`/`Sub`/`Mul`/`Div` (+`*Scalar`, +`*Into`), `Map`, `Neg`, `Abs` |
| Ufuncs | `Sqrt`, `Exp`, `Log`/`Log2`/`Log10`, `Sin`/`Cos`/`Tan`, `Floor`/`Ceil`/`Round`, `Square`, `Power` |
| Reductions | `Sum`, `Mean`, `Max`/`Min`, `Prod`, `ArgMax`/`ArgMin`, `CumSum`/`CumProd`, `Clip`, `Where` (+ per-axis) |
| Indexing | `Slice` (basic indexing), `MaskSelect` (`a[mask]`), `Nonzero` (`flatnonzero`), `Take` (fancy indexing) |
| Manipulation | `Flatten`, `ExpandDims`, `Squeeze`, `Concatenate`, `Stack`, `VStack`, `HStack` |
| Linear algebra | `MatMul`, `Dot`, `Inner`, `Outer` |
| Memory reuse | `NewWorkspace`, `Use`, `Reset`, `Detach` |

## Goroutines (v0.6.0)

Operations on large arrays are spread over `GOMAXPROCS` goroutines. After the
first one, the package keeps up to `GOMAXPROCS-1` helper goroutines alive. They
poll for the next operation for 200 µs, then block, so back-to-back operations
do not pay to wake threads. On 8 POWER9 cores that took a 2^20-element dot from
625 to 58 µs. The helpers are never stopped: a goroutine-leak check that runs
after ndarray operations will list them. See [Performance](performance.md).

## Untrusted input (v0.3.0)

A shape the library cannot represent is an error wrapping `ErrShapeMismatch`,
for results as well as inputs: `(2^32, 0) @ (0, 2^32)` holds no data, yet its
result would have 2^64 elements, so `MatMul` refuses it, as NumPy does. Empty
arrays with a huge axis cost nothing, and every assembly call is guarded and
fence-tested. See [Security](security.md).

## Loops: `Workspace` (v0.2.0)

Every operation returns a new array, and in a loop those results are garbage
the collector must chase. NumPy frees its temporaries the moment their
reference count drops; Go cannot. A `Workspace` gives the results of one pass a
single arena that `Reset` hands back:

```go
ws := nd.NewWorkspace()
for step := 0; step < steps; step++ {
	x := ws.Use(state)          // results computed from x come from ws
	p, _ := x.Mul(w)
	q, _ := p.Add(bias)
	state = q.Sqrt().Detach()   // the one result that outlives the pass
	ws.Reset()                  // everything else is recycled
}
```

On an AMD Zen 3 (16 cores), `x + y` on 1 024 elements goes from 2.6 µs to
0.38 µs (2.1× NumPy 2.5.3), `sqrt(x*y + x)` on 256 Ki from 1.18 ms to 0.39 ms
(7.5× NumPy). An array allocated from the workspace is **invalid after
`Reset`**; `Detach` returns a heap copy that survives it.

## Performance & architectures

Large elementwise ops, reductions and products run **multicore** (across
`GOMAXPROCS`). On **amd64, arm64, ppc64le and loong64** the hot loops are
go-asmgen SIMD kernels: sum, add/sub/mul/div, sqrt and the dot product (SSE2 or
AVX2/FMA on amd64, NEON on arm64, VSX on ppc64le, LASX on loong64 when the CPU
has it), max/min too on amd64, and a **panel-packed, cache-blocked GEMM** with
an SIMD-FMA micro-kernel (NEON 4×8; AVX2/FMA 6×8 chosen at run time by a CPUID
probe, SSE2 fallback; VSX 8×8; LASX 8×8). riscv64, s390x and the 32-bit
targets run the same pure-Go code those kernels are tested against. `Exp` and `Log` are ports of Arm's
optimized-routines (worst 0.504 and 0.508 ULP measured, against up to 0.88 and 0.72 for Go's `math.Exp`/`math.Log` on arm64), and they are
correct where amd64's `math.Exp` returns +Inf
([golang/go#81995](https://github.com/golang/go/issues/81995)) and `math.Log`
is wrong on subnormals
([golang/go#56600](https://github.com/golang/go/issues/56600)).

**Measured against NumPy 2.5.3 (OpenBLAS 0.3.34) on an AMD Zen 3, 16 cores:**

- **Faster:** whole-array reductions (`Sum`/`Mean`/`Max` at 4 Mi: 2.3–4.5×),
  row reductions (`SumAxis(1)` 2.2×, `MaxAxis(1)` 1.7×), `Exp` from 256 Ki
  elements (2.4–5.6×), and `MatMul` against single-threaded OpenBLAS
  (3.7–5.9× from 512²).
- **At parity:** `SumAxis(0)`, `Inner` against 16-thread OpenBLAS, `Log` on
  one core.
- **Slower:** `MatMul` against 16-thread OpenBLAS (0.55× at 1024², 0.3× at
  256² and below); `Dot`/mat·vec against NumPy's threaded BLAS (0.16×); `Exp`
  below 256 Ki elements (0.82×); the *allocating* forms of elementwise ops up
  to 256 Ki elements, `Concatenate`/`Stack` and slice copies outside a
  `Workspace` (0.2–0.5×).

On Apple silicon the GEMM reached parity with tuned BLAS at 1024² (OpenBLAS in
an arm64 VM, single-threaded vecLib on an M4 Max) and beats the pure-Go
**gonum 4–10×**.

CI runs the suite on amd64, arm64 and 386 natively and on
riscv64/loong64/ppc64le/s390x/arm under qemu, on Linux, macOS and Windows,
compiles it for every `GOOS/GOARCH` pair Go supports, and gates on 100%
statement coverage; v0.1.0 and v0.2.0 were also run on real amd64, arm64,
ppc64le, riscv64 and loong64 hardware.

## Where to go next

- [Roadmap](roadmap.md) — the plan and what ships today.
- [Performance](performance.md) — honest benchmarks versus NumPy / OpenBLAS.

Source: [github.com/go-ndarray/ndarray](https://github.com/go-ndarray/ndarray) ·
also the cgo-free ndarray backend behind [go-embedded-ruby](https://github.com/go-embedded-ruby/ruby)'s
`NDArray` class.
