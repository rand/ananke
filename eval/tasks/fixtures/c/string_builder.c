/**
 * Dynamic String Builder Implementation
 * Efficient string concatenation with automatic buffer resizing.
 */

#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdbool.h>

#define INITIAL_CAPACITY 64
#define GROWTH_FACTOR 2

typedef struct string_builder {
    char* buffer;
    size_t length;
    size_t capacity;
} string_builder_t;

string_builder_t* sb_create(void) {
    return sb_create_with_capacity(INITIAL_CAPACITY);
}

string_builder_t* sb_create_with_capacity(size_t initial_capacity) {
    if (initial_capacity == 0) {
        initial_capacity = INITIAL_CAPACITY;
    }

    string_builder_t* sb = malloc(sizeof(string_builder_t));
    if (!sb) return NULL;

    sb->buffer = malloc(initial_capacity);
    if (!sb->buffer) {
        free(sb);
        return NULL;
    }

    sb->buffer[0] = '\0';
    sb->length = 0;
    sb->capacity = initial_capacity;

    return sb;
}

void sb_destroy(string_builder_t* sb) {
    if (sb) {
        free(sb->buffer);
        free(sb);
    }
}

static bool ensure_capacity(string_builder_t* sb, size_t additional) {
    size_t required = sb->length + additional + 1;  /* +1 for null terminator */
    if (required <= sb->capacity) {
        return true;
    }

    /* Double capacity until sufficient */
    size_t new_capacity = sb->capacity;
    while (new_capacity < required) {
        new_capacity *= GROWTH_FACTOR;
    }

    char* new_buffer = realloc(sb->buffer, new_capacity);
    if (!new_buffer) {
        return false;
    }

    sb->buffer = new_buffer;
    sb->capacity = new_capacity;
    return true;
}

bool sb_append(string_builder_t* sb, const char* str) {
    if (!sb || !str) return false;

    size_t len = strlen(str);
    if (!ensure_capacity(sb, len)) {
        return false;
    }

    memcpy(sb->buffer + sb->length, str, len + 1);
    sb->length += len;
    return true;
}

bool sb_append_n(string_builder_t* sb, const char* str, size_t n) {
    if (!sb || !str) return false;

    if (!ensure_capacity(sb, n)) {
        return false;
    }

    memcpy(sb->buffer + sb->length, str, n);
    sb->length += n;
    sb->buffer[sb->length] = '\0';
    return true;
}

bool sb_append_char(string_builder_t* sb, char c) {
    if (!sb) return false;

    if (!ensure_capacity(sb, 1)) {
        return false;
    }

    sb->buffer[sb->length++] = c;
    sb->buffer[sb->length] = '\0';
    return true;
}

int sb_append_fmt(string_builder_t* sb, const char* fmt, ...) {
    if (!sb || !fmt) return -1;

    va_list args;

    /* First pass: determine needed size */
    va_start(args, fmt);
    int needed = vsnprintf(NULL, 0, fmt, args);
    va_end(args);

    if (needed < 0) return -1;

    if (!ensure_capacity(sb, (size_t)needed)) {
        return -1;
    }

    /* Second pass: actually write */
    va_start(args, fmt);
    vsnprintf(sb->buffer + sb->length, (size_t)needed + 1, fmt, args);
    va_end(args);

    sb->length += (size_t)needed;
    return needed;
}

char* sb_to_string(string_builder_t* sb) {
    if (!sb) return NULL;

    char* result = malloc(sb->length + 1);
    if (!result) return NULL;

    memcpy(result, sb->buffer, sb->length + 1);
    return result;
}

const char* sb_get_string(string_builder_t* sb) {
    return sb ? sb->buffer : NULL;
}

size_t sb_length(string_builder_t* sb) {
    return sb ? sb->length : 0;
}

size_t sb_capacity(string_builder_t* sb) {
    return sb ? sb->capacity : 0;
}

bool sb_is_empty(string_builder_t* sb) {
    return sb_length(sb) == 0;
}

void sb_clear(string_builder_t* sb) {
    if (sb) {
        sb->length = 0;
        sb->buffer[0] = '\0';
    }
}

bool sb_shrink_to_fit(string_builder_t* sb) {
    if (!sb) return false;

    size_t new_capacity = sb->length + 1;
    char* new_buffer = realloc(sb->buffer, new_capacity);
    if (!new_buffer && new_capacity > 0) {
        return false;
    }

    sb->buffer = new_buffer;
    sb->capacity = new_capacity;
    return true;
}

bool sb_insert(string_builder_t* sb, size_t pos, const char* str) {
    if (!sb || !str || pos > sb->length) return false;

    size_t len = strlen(str);
    if (!ensure_capacity(sb, len)) {
        return false;
    }

    /* Move existing content */
    memmove(sb->buffer + pos + len, sb->buffer + pos, sb->length - pos + 1);
    memcpy(sb->buffer + pos, str, len);
    sb->length += len;

    return true;
}

bool sb_delete(string_builder_t* sb, size_t start, size_t end) {
    if (!sb || start >= end || end > sb->length) return false;

    size_t removed = end - start;
    memmove(sb->buffer + start, sb->buffer + end, sb->length - end + 1);
    sb->length -= removed;

    return true;
}

bool sb_replace(string_builder_t* sb, const char* old_str, const char* new_str) {
    if (!sb || !old_str || !new_str) return false;

    char* found = strstr(sb->buffer, old_str);
    if (!found) return false;

    size_t old_len = strlen(old_str);
    size_t new_len = strlen(new_str);
    size_t pos = (size_t)(found - sb->buffer);

    if (new_len > old_len) {
        if (!ensure_capacity(sb, new_len - old_len)) {
            return false;
        }
        /* Refresh pointer after potential realloc */
        found = sb->buffer + pos;
    }

    /* Move tail */
    memmove(found + new_len, found + old_len, sb->length - pos - old_len + 1);
    memcpy(found, new_str, new_len);
    sb->length = sb->length - old_len + new_len;

    return true;
}

size_t sb_replace_all(string_builder_t* sb, const char* old_str, const char* new_str) {
    if (!sb || !old_str || !new_str || old_str[0] == '\0') return 0;

    size_t count = 0;
    size_t old_len = strlen(old_str);
    size_t new_len = strlen(new_str);
    size_t pos = 0;

    while (pos <= sb->length - old_len) {
        char* found = strstr(sb->buffer + pos, old_str);
        if (!found) break;

        pos = (size_t)(found - sb->buffer);

        if (new_len > old_len) {
            if (!ensure_capacity(sb, new_len - old_len)) {
                break;
            }
            found = sb->buffer + pos;
        }

        memmove(found + new_len, found + old_len, sb->length - pos - old_len + 1);
        memcpy(found, new_str, new_len);
        sb->length = sb->length - old_len + new_len;

        pos += new_len;
        count++;
    }

    return count;
}

char sb_char_at(string_builder_t* sb, size_t index) {
    if (!sb || index >= sb->length) return '\0';
    return sb->buffer[index];
}

bool sb_set_char_at(string_builder_t* sb, size_t index, char c) {
    if (!sb || index >= sb->length) return false;
    sb->buffer[index] = c;
    return true;
}
