	.text
	.attribute	4, 16
	.globl	measure                    # -- Begin function measure
	.p2align	1
	.type	measure,@function
measure:                           # @measure
    vsetivli	zero, PARAM_VL, PARAM_SEW, PARAM_LMUL, ta, ma
    .rept   250
    vlseg2e64.v v0, (a0)
    vlseg2e64.v v8, (a0)
    vlseg2e64.v v16, (a0)
    vlseg2e64.v v24, (a0)
    .endr
	ret
.Lfunc_end0:
	.size	measure, .Lfunc_end0-measure
                                        # -- End function
	.section	".note.GNU-stack","",@progbits
	.addrsig
