#include "shell.h"
#include "../os.h"
#include "../drivers/keyboard.h"
#include <string.h>

#define SHELL_LINE_CAPACITY 32

static char command_buffer[SHELL_LINE_CAPACITY];
static char executable_path[SHELL_LINE_CAPACITY];
static unsigned char command_length;

static unsigned char shell_launch(const char *text)
{
    const char *word;
    const char *cursor;
    const char *arguments;
    unsigned char word_length = 0;
    unsigned char path_length = 0;
    unsigned char has_slash = 0;
    unsigned char has_extension = 0;

    while (*text == ' ') ++text;
    word = text;
    cursor = text;
    while (*cursor != '\0' && *cursor != ' ') {
        if (*cursor == '/') has_slash = 1;
        ++word_length;
        ++cursor;
    }
    if (word_length == 0) return 0;

    if (word[0] == '/') {
        ++word;
        --word_length;
        has_slash = 1;
    }
    if (word_length == 0) return 0;

    if (word_length >= 4 &&
        word[word_length - 4] == '.' &&
        word[word_length - 3] == 'n' &&
        word[word_length - 2] == 'e' &&
        word[word_length - 1] == 'x') {
        has_extension = 1;
    }

    if (!has_slash) {
        executable_path[path_length++] = 'b';
        executable_path[path_length++] = 'i';
        executable_path[path_length++] = 'n';
        executable_path[path_length++] = '/';
    }

    if (path_length + word_length + (has_extension ? 0 : 4) >=
        sizeof(executable_path)) return 0;

    while (word_length != 0) {
        executable_path[path_length++] = *word++;
        --word_length;
    }
    if (!has_extension) {
        executable_path[path_length++] = '.';
        executable_path[path_length++] = 'n';
        executable_path[path_length++] = 'e';
        executable_path[path_length++] = 'x';
    }
    executable_path[path_length] = '\0';

    arguments = cursor;
    while (*arguments == ' ') ++arguments;
    return os_fs_run(executable_path, arguments);
}

void shell_init(void)
{
    command_length = 0;
    command_buffer[0] = '\0';
    os_write("32 \xD7 30\nNexOS v0.1\n\nInitializing kernel...\n\nReady.\n\nnexos> ");
}

void shell_execute(const char *command)
{
    unsigned char character;
    char text[2];

    if (command == 0) return;
    os_write("\n");
    if (strcmp(command, "help") == 0) {
        os_write("Commands: help ver clear echo ls cat chars\n");
    } else if (strcmp(command, "ver") == 0) {
        os_write("NexOS v0.1\n");
    } else if (strcmp(command, "clear") == 0) {
        os_clear();
        os_write("nexos> ");
        return;
    } else if (strncmp(command, "echo ", 5) == 0) {
        os_write(command + 5);
        os_write("\n");
    } else if (strncmp(command, "run ", 4) == 0) {
        if (!shell_launch(command + 4)) {
            os_write("Program unavailable, invalid, or already running\n");
        }
    } else if (strcmp(command, "chars") == 0) {
        text[1] = '\0';
        for (character = 32; character <= 126; character++) {
            text[0] = character;
            os_write(text);
        }
        os_write("\n");
    } else if (*command != '\0') {
        if (!shell_launch(command)) {
            os_write("Unknown command or program unavailable: ");
            os_write(command);
            os_write("\n");
        }
    }
    os_write("\nnexos> ");
}

void shell_poll_input(void)
{
    char character;
    char text[2];

    character = keyboard_read_char();
    if (character == 0) return;

    if (character == '\b') {
        if (command_length != 0) {
            --command_length;
            command_buffer[command_length] = '\0';
            os_write("\b");
        }
        return;
    }

    if (character == '\n') {
        command_buffer[command_length] = '\0';
        shell_execute(command_buffer);
        command_length = 0;
        command_buffer[0] = '\0';
        return;
    }

    if (character < 32 || character > 126 ||
        command_length >= SHELL_LINE_CAPACITY - 1) return;

    command_buffer[command_length++] = character;
    command_buffer[command_length] = '\0';
    text[0] = character;
    text[1] = '\0';
    os_write(text);
}
