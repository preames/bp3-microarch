	.text
	.attribute	4, 16
	.globl	measure                    # -- Begin function measure
	.p2align	1
	.type	measure,@function
measure:                           # @measure
    li a1, 16
    vsetivli	zero, PARAM_VL, PARAM_SEW, PARAM_LMUL, ta, ma
    .rept   200
    vlse64.v v12, (a0), a1
    vlse64.v v16, (a0), a1
    vlse64.v v20, (a0), a1
    vlse64.v v24, (a0), a1
    vlse64.v v28, (a0), a1
    .endr
	ret
.Lfunc_end0:
	.size	measure, .Lfunc_end0-measure
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
	.addrsig
