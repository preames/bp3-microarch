	.text
	.attribute	4, 16
	.globl	measure                    # -- Begin function measure
	.p2align	1
	.type	measure,@function
measure:                           # @measure
    vsetvli	a0, zero, e32, m1, ta, ma
    .rept   1000
    vadd.vv v12, v4, v8
    .endr
	ret
.Lfunc_end0:
	.size	measure, .Lfunc_end0-measure
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
	.addrsig
