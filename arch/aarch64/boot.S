/*
 * arch/arm64/kernel/boot.S
 *
 * Created by Le Min(lemin9538@163.com)
 */

#include <asm/asm_mmu.h>
#include <asm/aarch64_common.h>
#include <asm/gic_reg.h>
#include <config/config.h>

	.section __start_up, "ax"
	.balign 4

	.global _start
	.type _start, "function"
_start:	
	// SCR_EL3 Secure Configuration Register
	ldr	x1, =el3_vectors
	msr	VBAR_EL3, x1

	msr	SCR_EL3, xzr
	isb

	//ICC_SRE_EL3 Interrupt Controller System Register Enable register 
	mov	x0, #15
	msr	ICC_SRE_EL3, x0
	isb

	mov	x3, #(SCR_EL3_RW | \
			SCR_EL3_SMD | \
			SCR_EL3_NS | \
			SCR_EL3_HCE)
	msr	SCR_EL3, x3
	isb

	mov	x0, #15
	msr	ICC_SRE_EL2, x0
	isb
	msr	ICC_SRE_EL1, X0

	/*
	 * init the vmpidr
	 */
	mrs	x0, MPIDR_EL1
	msr	VMPIDR_EL2, x0
	mrs	x0, MIDR_EL1
	msr	VPIDR_EL2, x0

	/* get the cpu id to x19 */
	mrs	x19, MPIDR_EL1
	ubfx	x19, x19, #MPIDR_EL1_AFF0_LSB, #MPIDR_EL1_AFF_WIDTH

	msr	CPTR_EL3, xzr

	mov	x0, #0
	msr	SCTLR_EL3, x0

	ldr	x0, =__el3_stack_end
	sub	x0, x0, x19, lsl #12
	mov	sp, x0

	/* do the gic setting for el3 */
	bl	gic_init_el3

	cbnz	x19, drop_to_el2

	/* do other init things */

	.global drop_to_el2
drop_to_el2:
	adr	x1, el2_entry_aarch64
	msr	ELR_EL3, X1
	mov	x1, #(AARCH64_SPSR_EL2h | \
		AARCH64_SPSR_F  | \
		AARCH64_SPSR_I  | \
		AARCH64_SPSR_A)
	msr	SPSR_EL3, x1
	eret

	.global el2_entry_aarch64
	.type el2_entry_aarch64, "function"
el2_entry_aarch64:
	ldr	x1, =el2_vectors
	msr	VBAR_EL2, x1

	mov	x0, #15	// el1 access ICC_SRE_EL1 will trap to EL2
	msr	ICC_SRE_EL2, x0

	msr	VTTBR_EL2, xzr
	isb

	// neither EL3 nor EL2 trap floating point or accesses to CPACR
	msr	CPTR_EL2, xzr

	ldr	x0, =__el2_stack_end
	sub	x0, x0, x19, lsl #13
	mov	sp, x0

	cbnz	x19, secondary_start_up

	ldr	x0, =__bss_start
	mov	x1, #0
	ldr	x2, =__bss_end
	sub	x2, x2, x0
	bl	memset

	b	boot_main
	nop
	isb
	b	return_to_el1

secondary_start_up:
	/* here wait for boot cpu finish tht init work */
	b	boot_secondary
	nop
	isb
	b return_to_el1
