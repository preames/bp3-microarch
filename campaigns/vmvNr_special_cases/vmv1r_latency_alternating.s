	.text
	.attribute	4, 16
	.file	"example.c"
	.globl	measure                    # -- Begin function measure
	.p2align	1
	.type	measure,@function
measure:                           # @measure
    vsetivli	zero, 8, e32, m1, tu, mu
    .rept   500
    vmv1r.v v2, v1
    vmv1r.v v1, v2
    .endr
	ret
.Lfunc_end0:
	.size	measure, .Lfunc_end0-measure
                                        # -- End function
	.ident	"Ubuntu clang version 16.0.6 (15)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
