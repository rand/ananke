/**
 * String Builder Tests
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

/* Include the implementation */
#include "string_builder.c"

#define TEST(name) static void test_##name(void)
#define RUN_TEST(name) do { \
    printf("  Testing %s...", #name); \
    test_##name(); \
    printf(" PASSED\n"); \
} while(0)

TEST(create_destroy) {
    string_builder_t* sb = sb_create();
    assert(sb != NULL);
    assert(sb_length(sb) == 0);
    assert(sb_is_empty(sb));
    sb_destroy(sb);
}

TEST(append) {
    string_builder_t* sb = sb_create();

    sb_append(sb, "hello");
    assert(sb_length(sb) == 5);
    assert(strcmp(sb_get_string(sb), "hello") == 0);

    sb_append(sb, " world");
    assert(sb_length(sb) == 11);
    assert(strcmp(sb_get_string(sb), "hello world") == 0);

    sb_destroy(sb);
}

TEST(append_char) {
    string_builder_t* sb = sb_create();

    sb_append_char(sb, 'a');
    sb_append_char(sb, 'b');
    sb_append_char(sb, 'c');

    assert(sb_length(sb) == 3);
    assert(strcmp(sb_get_string(sb), "abc") == 0);

    sb_destroy(sb);
}

TEST(append_n) {
    string_builder_t* sb = sb_create();

    sb_append_n(sb, "hello world", 5);
    assert(sb_length(sb) == 5);
    assert(strcmp(sb_get_string(sb), "hello") == 0);

    sb_destroy(sb);
}

TEST(append_fmt) {
    string_builder_t* sb = sb_create();

    sb_append_fmt(sb, "Number: %d", 42);
    assert(strcmp(sb_get_string(sb), "Number: 42") == 0);

    sb_append_fmt(sb, ", Float: %.2f", 3.14);
    assert(strcmp(sb_get_string(sb), "Number: 42, Float: 3.14") == 0);

    sb_destroy(sb);
}

TEST(to_string) {
    string_builder_t* sb = sb_create();
    sb_append(sb, "test string");

    char* str = sb_to_string(sb);
    assert(str != NULL);
    assert(strcmp(str, "test string") == 0);

    /* Modifying returned string doesn't affect builder */
    str[0] = 'X';
    assert(strcmp(sb_get_string(sb), "test string") == 0);

    free(str);
    sb_destroy(sb);
}

TEST(clear) {
    string_builder_t* sb = sb_create();
    sb_append(sb, "hello");
    assert(!sb_is_empty(sb));

    sb_clear(sb);
    assert(sb_is_empty(sb));
    assert(sb_length(sb) == 0);
    assert(strcmp(sb_get_string(sb), "") == 0);

    /* Can append after clear */
    sb_append(sb, "world");
    assert(strcmp(sb_get_string(sb), "world") == 0);

    sb_destroy(sb);
}

TEST(growth) {
    /* Start with small capacity */
    string_builder_t* sb = sb_create_with_capacity(8);
    size_t initial_cap = sb_capacity(sb);

    /* Append more than initial capacity */
    sb_append(sb, "This is a longer string that will trigger growth");

    assert(sb_capacity(sb) > initial_cap);
    assert(strcmp(sb_get_string(sb), "This is a longer string that will trigger growth") == 0);

    sb_destroy(sb);
}

TEST(insert) {
    string_builder_t* sb = sb_create();
    sb_append(sb, "hello world");

    sb_insert(sb, 6, "beautiful ");
    assert(strcmp(sb_get_string(sb), "hello beautiful world") == 0);

    /* Insert at beginning */
    sb_insert(sb, 0, "Oh ");
    assert(strcmp(sb_get_string(sb), "Oh hello beautiful world") == 0);

    sb_destroy(sb);
}

TEST(delete) {
    string_builder_t* sb = sb_create();
    sb_append(sb, "hello beautiful world");

    sb_delete(sb, 6, 16);  /* Remove "beautiful " */
    assert(strcmp(sb_get_string(sb), "hello world") == 0);

    sb_destroy(sb);
}

TEST(replace) {
    string_builder_t* sb = sb_create();
    sb_append(sb, "hello world");

    sb_replace(sb, "world", "universe");
    assert(strcmp(sb_get_string(sb), "hello universe") == 0);

    /* Replace with shorter string */
    sb_replace(sb, "universe", "foo");
    assert(strcmp(sb_get_string(sb), "hello foo") == 0);

    sb_destroy(sb);
}

TEST(replace_all) {
    string_builder_t* sb = sb_create();
    sb_append(sb, "foo bar foo baz foo");

    size_t count = sb_replace_all(sb, "foo", "X");
    assert(count == 3);
    assert(strcmp(sb_get_string(sb), "X bar X baz X") == 0);

    sb_destroy(sb);
}

TEST(char_at) {
    string_builder_t* sb = sb_create();
    sb_append(sb, "hello");

    assert(sb_char_at(sb, 0) == 'h');
    assert(sb_char_at(sb, 4) == 'o');
    assert(sb_char_at(sb, 5) == '\0');  /* Out of bounds */

    sb_destroy(sb);
}

TEST(set_char_at) {
    string_builder_t* sb = sb_create();
    sb_append(sb, "hello");

    sb_set_char_at(sb, 0, 'H');
    assert(strcmp(sb_get_string(sb), "Hello") == 0);

    /* Out of bounds */
    assert(!sb_set_char_at(sb, 10, 'X'));

    sb_destroy(sb);
}

TEST(shrink_to_fit) {
    string_builder_t* sb = sb_create_with_capacity(1024);
    sb_append(sb, "small");

    assert(sb_capacity(sb) == 1024);
    sb_shrink_to_fit(sb);
    assert(sb_capacity(sb) == 6);  /* 5 chars + null */
    assert(strcmp(sb_get_string(sb), "small") == 0);

    sb_destroy(sb);
}

TEST(stress) {
    string_builder_t* sb = sb_create();

    /* Many small appends */
    for (int i = 0; i < 1000; i++) {
        sb_append_char(sb, 'x');
    }
    assert(sb_length(sb) == 1000);

    /* Verify content */
    const char* str = sb_get_string(sb);
    for (int i = 0; i < 1000; i++) {
        assert(str[i] == 'x');
    }

    sb_destroy(sb);
}

int main(void) {
    printf("String Builder Tests:\n");

    RUN_TEST(create_destroy);
    RUN_TEST(append);
    RUN_TEST(append_char);
    RUN_TEST(append_n);
    RUN_TEST(append_fmt);
    RUN_TEST(to_string);
    RUN_TEST(clear);
    RUN_TEST(growth);
    RUN_TEST(insert);
    RUN_TEST(delete);
    RUN_TEST(replace);
    RUN_TEST(replace_all);
    RUN_TEST(char_at);
    RUN_TEST(set_char_at);
    RUN_TEST(shrink_to_fit);
    RUN_TEST(stress);

    printf("\nAll tests passed!\n");
    return 0;
}
