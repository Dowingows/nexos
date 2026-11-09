#ifndef NEXOS_EXCEPTION_H
#define NEXOS_EXCEPTION_H

/* CPU state captured during the exception. */
extern unsigned char exception_a;
extern unsigned char exception_x;
extern unsigned char exception_y;
extern unsigned char exception_status;
extern unsigned int exception_pc;

/* Trigger an exception with the BRK instruction. */
void trigger_exception(void);

/* Handle the exception captured by Assembly. */
void exception_handler(void);

#endif