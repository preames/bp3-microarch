	.text
	.attribute	4, 16
	.file	"example.c"
	.globl	read_counters                    # -- Begin function read_counters
	.p2align	1
	.type	read_counters,@function
read_counters:                           # @read_counters
    # %bb.0:
    rdcycle a3
    sd a3, (a0) 
    rdinstret a3
    sd a3, (a1) 
	ret
.Lfunc_end0:
	.size	read_counters, .Lfunc_end0-read_counters
                                        # -- End function
	.ident	"Ubuntu clang version 16.0.6 (15)"
	.section	".note.GNU-stack","",@progbits
	.addrsig
