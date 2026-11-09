#include "keyboard.h"
#include "../proc/process.h"

#define KEYBOARD_SELECT (*(volatile unsigned char *)0x4016)
#define KEYBOARD_DATA   (*(volatile unsigned char *)0x4017)
#define KEYBOARD_ROWS 9
#define KEYS_PER_HALF_ROW 4
#define KEYBOARD_QUEUE_SIZE 16
#define KEYBOARD_QUEUE_MASK (KEYBOARD_QUEUE_SIZE - 1)

static const char key_map[KEYBOARD_ROWS][8] = {
    { ']', '[', '\n', 0, 0, 0, 0, 0 },
    { ';', ':', '@', 0, '^', '-', '/', '_' },
    { 'k', 'l', 'o', 0, '0', 'p', ',', '.' },
    { 'j', 'u', 'i', 0, '8', '9', 'n', 'm' },
    { 'h', 'g', 'y', 0, '6', '7', 'v', 'b' },
    { 'd', 'r', 't', 0, '4', '5', 'c', 'f' },
    { 'a', 's', 'w', 0, '3', 'e', 'z', 'x' },
    { 0, 'q', 0, 0, '2', '1', 0, 0 },
    { 0, 0, 0, 0, 0, '\b', ' ', 0 }
};

static volatile char key_queue[KEYBOARD_QUEUE_SIZE];
static volatile unsigned char key_head;
static volatile unsigned char key_tail;
static unsigned char key_event_latched;
volatile unsigned char keyboard_waiting;

static void keyboard_scan_delay(void)
{
    volatile unsigned char count;

    for (count = 0; count < 16; ++count) {
    }
}

static char keyboard_scan_character(unsigned char *control_pressed)
{
    unsigned char row;
    unsigned char half;
    unsigned char key;
    unsigned char data;
    unsigned char mask;
    char character;
    char first_character;

    *control_pressed = 0;
    first_character = 0;

    /* The Family BASIC keyboard is a serial matrix selected through $4016. */
    KEYBOARD_SELECT = 0x05;
    keyboard_scan_delay();
    KEYBOARD_SELECT = 0x04;

    for (row = 0; row < KEYBOARD_ROWS; ++row) {
        for (half = 0; half < 2; ++half) {
            keyboard_scan_delay();
            data = KEYBOARD_DATA;

            for (key = 0; key < KEYS_PER_HALF_ROW; ++key) {
                mask = (unsigned char)(0x10 >> key);
                if ((data & mask) == 0) {
                    if (row == 7 && half == 0 && key == 0) {
                        *control_pressed = 1;
                    } else {
                        character = key_map[row][half * KEYS_PER_HALF_ROW + key];
                        if (first_character == 0 && character != 0) {
                            first_character = character;
                        }
                    }
                }
            }

            KEYBOARD_SELECT = (half == 0) ? 0x06 : 0x04;
        }
    }

    KEYBOARD_SELECT = 0x00;
    if (*control_pressed) {
        if (first_character == 'c') return 0x03;
        return first_character == 0 ? 0 : 0x04;
    }
    return first_character;
}

static void keyboard_enqueue(char character)
{
    unsigned char next;

    next = (unsigned char)((key_tail + 1) & KEYBOARD_QUEUE_MASK);
    if (next == key_head) return;

    key_queue[key_tail] = character;
    key_tail = next;
}

void keyboard_init(void)
{
    KEYBOARD_SELECT = 0x00;
    key_head = 0;
    key_tail = 0;
    key_event_latched = 0;
    keyboard_waiting = 0;
}

void keyboard_process(void)
{
    char character;
    unsigned char control_pressed;

    for (;;) {
        /* Arm the wait before scanning so the frame NMI is not missed. */
        keyboard_waiting = 1;
        character = keyboard_scan_character(&control_pressed);

        if (character == 0) {
            if (!control_pressed) key_event_latched = 0;
        } else if (character == 0x04) {
            key_event_latched = 1;
        } else if (!key_event_latched) {
            keyboard_enqueue(character);
            key_event_latched = 1;
        }

        /* Sleep until the next frame; the shell continues running. */
        process_wait(&keyboard_waiting);
    }
}

char keyboard_read_char(void)
{
    char character;

    if (key_head == key_tail) return 0;

    character = key_queue[key_head];
    key_head = (unsigned char)((key_head + 1) & KEYBOARD_QUEUE_MASK);
    return character;
}
