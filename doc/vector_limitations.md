# Vector extension limitations

Limitations of the current vector implementation that software has no
architectural way to discover. In each case `vsetvli` accepts the configuration,
`vtype.vill` stays clear and `vlmax` reports its full value, so the restriction
cannot be detected by reading CSRs.

## Widening and narrowing operations are limited to `vl <= VLMAX/2` at non-fractional LMUL

Widening and narrowing instructions are decoded only when LMUL is fractional, or
when `vl <= VLMAX/2`. Outside that window they raise an illegal instruction
exception, even though the preceding `vsetvli` accepted the configuration and
returned the larger `vl`.

This collides with the usual vectorisation idiom, in which software asks for the
largest legal `vl` and then issues a widening operation:

```asm
vsetvli t0, a0, e32, m1, ta, ma   # accepted, t0 = VLMAX
vwadd.vv v4, v8, v12              # illegal instruction when t0 > VLMAX/2
```

Software that needs widening or narrowing at non-fractional LMUL must cap `vl`
at `VLMAX/2` itself, or use a fractional LMUL, for which the restriction does
not apply.

### Where this is implemented

The enable is computed on both `vsetvl` paths, in each case as
`vtype[2] || (vl <= vlmax >> 1)`, where `vtype[2]` is the sign bit of `vlmul`
and therefore selects the fractional settings:

- `rtl/datapath/rtl/id_stage/rtl/vset_module.sv`, on the `vset` decode path
- `rtl/csr/rtl/csr_bsc.sv`, on the CSR write path

It reaches the decoder through `vset_queue.sv` and appears there as
`v_2sew_en_int`, which gates every widening and narrowing entry in `decoder.sv`.
When it is low those entries assert `xcpt_illegal_instruction_int`.

### Status

This follows from the current LMUL <= 1 support. The limit on LMUL also applies
to the EMUL of widening and narrowing instructions, and permitting them at
`vl <= VLMAX/2` is what makes them usable at all in the meantime. Full LMUL > 1
support is in progress, and this restriction is expected to disappear with it.
