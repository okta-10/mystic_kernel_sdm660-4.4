/*
 * strnlen - calculate the length of a string with limit.
 *
 * Copyright (c) 2013, Arm Limited.
 * SPDX-License-Identifier: MIT
 */

/* Assumptions:
 *
 * ARMv8-a, AArch64
 */

#include <linux/linkage.h>
#include <asm/assembler.h>

/* Arguments and results.  */
srcin		.req	x0
len		.req	x0
limit		.req	x1

/* Locals and temporaries.  */
src		.req	x2
data1		.req	x3
data2		.req	x4
data2a		.req	x5
has_nul1	.req	x6
has_nul2	.req	x7
tmp1		.req	x8
tmp2		.req	x9
tmp3		.req	x10
tmp4		.req	x11
zeroones	.req	x12
pos		.req	x13
limit_wd	.req	x14

	.macro def_fn f p2align=0
	.text
	.p2align \p2align
	.global \f
	.type \f, %function
\f:
	.endm

#define REP8_01 0x0101010101010101
#define REP8_7f 0x7f7f7f7f7f7f7f7f
#define REP8_80 0x8080808080808080

	.text
	.p2align	6
.Lstart:
	/* Pre-pad to ensure critical loop begins an icache line.  */
	.rep 7
	nop
	.endr
	/* Put this code here to avoid wasting more space with pre-padding.  */
.Lhit_limit:
	mov	len, limit
	ret

ENTRY(strnlen)
	cbz	limit, .Lhit_limit
	mov	zeroones, #REP8_01
	bic	src, srcin, #15
	ands	tmp1, srcin, #15
	b.ne	.Lmisaligned
	/* Calculate the number of full and partial words -1.  */
	sub	limit_wd, limit, #1	/* Limit != 0, so no underflow.  */
	lsr	limit_wd, limit_wd, #4	/* Convert to Qwords.  */

	/* NUL detection works on the principle that (X - 1) & (~X) & 0x80
	   (=> (X - 1) & ~(X | 0x7f)) is non-zero iff a byte is zero, and
	   can be done in parallel across the entire word.  */
	/* The inner loop deals with two Dwords at a time.  This has a
	   slightly higher start-up cost, but we should win quite quickly,
	   especially on cores with a high number of issue slots per
	   cycle, as we get much better parallelism out of the operations.  */

	/* Start of critial section -- keep to one 64Byte cache line.  */
.Lloop:
	ldp	data1, data2, [src], #16
.Lrealigned:
	sub	tmp1, data1, zeroones
	orr	tmp2, data1, #REP8_7f
	sub	tmp3, data2, zeroones
	orr	tmp4, data2, #REP8_7f
	bic	has_nul1, tmp1, tmp2
	bic	has_nul2, tmp3, tmp4
	subs	limit_wd, limit_wd, #1
	orr	tmp1, has_nul1, has_nul2
	ccmp	tmp1, #0, #0, pl	/* NZCV = 0000  */
	b.eq	.Lloop
	/* End of critical section -- keep to one 64Byte cache line.  */

	orr	tmp1, has_nul1, has_nul2
	cbz	tmp1, .Lhit_limit	/* No null in final Qword.  */

	/* We know there's a null in the final Qword.  The easiest thing
	   to do now is work out the length of the string and return
	   MIN (len, limit).  */

	sub	len, src, srcin
	cbz	has_nul1, .Lnul_in_data2
CPU_BE( mov	data2, data1 )	/*perpare data to re-calculate the syndrome*/

	sub	len, len, #8
	mov	has_nul2, has_nul1
.Lnul_in_data2:
	/*
	* For big-endian, carry propagation (if the final byte in the
	* string is 0x01) means we cannot use has_nul directly.  The
	* easiest way to get the correct byte is to byte-swap the data
	* and calculate the syndrome a second time.
	*/
CPU_BE( rev	data2, data2 )
CPU_BE( sub	tmp1, data2, zeroones )
CPU_BE( orr	tmp2, data2, #REP8_7f )
CPU_BE( bic	has_nul2, tmp1, tmp2 )

	sub	len, len, #8
	rev	has_nul2, has_nul2
	clz	pos, has_nul2
	add	len, len, pos, lsr #3		/* Bits to bytes.  */
	cmp	len, limit
	csel	len, len, limit, ls		/* Return the lower value.  */
	ret

.Lmisaligned:
	/* Deal with a partial first word.
	   We're doing two things in parallel here;
	   1) Calculate the number of words (but avoiding overflow if
	      limit is near ULONG_MAX) - to do this we need to work out
	      limit + tmp1 - 1 as a 65-bit value before shifting it;
	   2) Load and mask the initial data words - we force the bytes
	      before the ones we are interested in to 0xff - this ensures
	      early bytes will not hit any zero detection.  */
	sub	limit_wd, limit, #1
	neg	tmp4, tmp1
	cmp	tmp1, #8

	and	tmp3, limit_wd, #15
	lsr	limit_wd, limit_wd, #4
	mov	tmp2, #~0

	ldp	data1, data2, [src], #16
	lsl	tmp4, tmp4, #3		/* Bytes beyond alignment -> bits.  */
	add	tmp3, tmp3, tmp1

	/* Big-endian.  Early bytes are at MSB.  */
CPU_BE( lsl	tmp2, tmp2, tmp4 )	/* Shift (tmp1 & 63).  */
	/* Little-endian.  Early bytes are at LSB.  */
CPU_LE( lsr	tmp2, tmp2, tmp4 )	/* Shift (tmp1 & 63).  */

	add	limit_wd, limit_wd, tmp3, lsr #4

	orr	data1, data1, tmp2
	orr	data2a, data2, tmp2

	csinv	data1, data1, xzr, le
	csel	data2, data2, data2a, le
	b	.Lrealigned
ENDPIPROC(strnlen)
