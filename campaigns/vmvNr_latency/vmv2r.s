	.text
	.attribute	4, 16
	.file	"example.c"
	.globl	measure                    # -- Begin function measure
	.p2align	1
	.type	measure,@function
measure:                           # @measure
    vsetivli	zero, 8, e32, m1, tu, mu
    .rept   200
    vmv2r.v v8, v4
    vmv2r.v v12, v8
    vmv2r.v v16, v12
    vmv2r.v v20, v16
    vmv2r.v v4, v20
    .endr
	ret
.Lfunc_end0:
	.size	measure, .Lfunc_end0-measure
                                        # -- End function
	.ident	"Ubuntu clang version 16.0.6 (15)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
