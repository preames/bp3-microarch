	.text
	.attribute	4, 16
	.globl	measure                    # -- Begin function measure
	.p2align	1
	.type	measure,@function
measure:                           # @measure
    vsetvli	a1, zero, PARAM_SEW, PARAM_LMUL, ta, ma
    .rept   200
    vadd.vv v12, v4, v8
    vadd.vv v16, v4, v8
    vadd.vv v20, v4, v8
    vadd.vv v24, v4, v8
    vadd.vv v28, v4, v8
    .endr
	ret
.Lfunc_end0:
	.size	measure, .Lfunc_end0-measure
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
	.addrsig
