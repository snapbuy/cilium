// SPDX-License-Identifier: GPL-2.0
/// Find function arguments that can be declared const. Confidence in the
/// results in low for now, but the compiler should catch any incorrect const
/// qualifier.
// Confidence: Low
// Copyright Authors of Cilium.
// Comments:
// Options: --include-headers

@initialize:python@
@@

cnt = 0


@rule@
identifier f, fn, x, z;
assignment operator op;
expression e;
type T0, T;
position p;
@@

(
  // Match this case first to avoid duplicating const qualifier.
  T0 fn (..., const T *x, ...) { ... }
|
  // Match this case first to avoid marking __maybe_unused parameters as const.
  T0 fn (..., T *x, ...) {
  ... when != x
  }
|
  T0 fn (...,
- T *x@p
+ const T *x
  , ...)
  {
  // Avoid matching any function where x's value is assigned or x is passed to
  // another function.
  ... when != *x op ...
      when != x->z op ...
      when != x->z[...] op ...
      when != &x->z
      when != e = x
      when != WRITE_ONCE(x->z, ...)
      when != WRITE_ONCE(x->z[...], ...)
      when != f(..., x, ...)
      // Special case for a few fields that are arrays in several structures.
      when != f(..., x->addr, ...)
      when != f(..., x->smac, ...)
      when != f(..., x->dmac, ...)
  }
)


@script:python@
x << rule.x;
p << rule.p;
@@

print("* file %s: variable %s on line %s should be declared constant" % (p[0].file, x, p[0].line))
cnt += 1


@finalize:python@
@@

if cnt > 0:
  print("""Use the following command to fix the above issues:
docker run --rm --user 1000 --workdir /workspace -v `pwd`:/workspace                \\
    -it docker.io/cilium/coccicheck:2.3@sha256:56c7445e3d0cc37de49750f5dfd154786082c4be6bc17683c231c0445862233a spatch --sp-file contrib/coccinelle/const.cocci \\
    --include-headers --very-quiet --in-place bpf/\n
""")
