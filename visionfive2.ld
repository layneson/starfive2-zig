. = 0x8000000;
 
SECTIONS {
	/* Include entry point at start of binary */
	.text : ALIGN(4K) {
		*(.start);
		*(.text*);
	}
    .bss : ALIGN(4K) {
		PROVIDE(_bss_start = .);
		*(.bss*);
		/* PROVIDE(_global_pointer = .); */
		PROVIDE(_bss_end = .);
	}
	.rodata : ALIGN(4K) {
		*(.rodata*);
	}
	.data : ALIGN(4K) {
		*(.data*);
	}
	.sdata : ALIGN(4K) {
		*(.sdata*);
	}
}