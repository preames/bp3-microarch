	.text
	.attribute	4, 16
	.file	"example.c"
	.globl	measure                    # -- Begin function measure
	.p2align	1
	.type	measure,@function
measure:                           # @measure
    vsetivli	zero, 8, e32, m1, tu, mu
    .rept   200
    vmv4r.v v8, v4
    vmv4r.v v12, v4
    vmv4r.v v16, v4
    vmv4r.v v20, v4
    vmv4r.v v24, v4
    .endr
	ret
.Lfunc_end0:
	.size	measure, .Lfunc_end0-measure
                                        # -- End function
	.ident	"Ubuntu clang version 16.0.6 (15)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
