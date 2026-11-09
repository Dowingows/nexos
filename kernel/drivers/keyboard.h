#ifndef NEXOS_KEYBOARD_H
#define NEXOS_KEYBOARD_H

extern volatile unsigned char keyboard_waiting;

/* Initialize the Family BASIC keyboard and character queue. */
void keyboard_init(void);

/* Cooperative process that scans the keyboard and yields after each read. */
void keyboard_process(void);

/* Remove a key from the queue; return zero immediately if it is empty. */
char keyboard_read_char(void);

#endif
