/**
 * Ring Buffer Tests
 * Uses a simple test framework for C.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

/* Include the implementation */
#include "ring_buffer.c"

#define TEST(name) static void test_##name(void)
#define RUN_TEST(name) do { \
    printf("  Testing %s...", #name); \
    test_##name(); \
    printf(" PASSED\n"); \
} while(0)

TEST(create_destroy) {
    ring_buffer_t* rb = ring_buffer_create(16);
    assert(rb != NULL);
    assert(ring_buffer_capacity(rb) == 16);
    assert(ring_buffer_is_empty(rb));
    assert(!ring_buffer_is_full(rb));
    ring_buffer_destroy(rb);
}

TEST(power_of_2_capacity) {
    ring_buffer_t* rb = ring_buffer_create(10);
    assert(rb != NULL);
    /* Should round up to 16 */
    assert(ring_buffer_capacity(rb) == 16);
    ring_buffer_destroy(rb);

    rb = ring_buffer_create(1);
    assert(ring_buffer_capacity(rb) == 1);
    ring_buffer_destroy(rb);

    rb = ring_buffer_create(0);
    assert(ring_buffer_capacity(rb) == 1);
    ring_buffer_destroy(rb);
}

TEST(push_pop_basic) {
    ring_buffer_t* rb = ring_buffer_create(16);

    const char* data = "hello";
    size_t written = ring_buffer_push(rb, data, 5);
    assert(written == 5);
    assert(ring_buffer_size(rb) == 5);

    char buf[16] = {0};
    size_t read = ring_buffer_pop(rb, buf, 16);
    assert(read == 5);
    assert(memcmp(buf, "hello", 5) == 0);
    assert(ring_buffer_is_empty(rb));

    ring_buffer_destroy(rb);
}

TEST(push_full_buffer) {
    ring_buffer_t* rb = ring_buffer_create(4);

    const char* data = "test";
    size_t written = ring_buffer_push(rb, data, 4);
    assert(written == 4);
    assert(ring_buffer_is_full(rb));

    /* Try to push more - should fail */
    written = ring_buffer_push(rb, "x", 1);
    assert(written == 0);

    ring_buffer_destroy(rb);
}

TEST(wraparound) {
    ring_buffer_t* rb = ring_buffer_create(8);

    /* Fill partially */
    ring_buffer_push(rb, "1234", 4);

    /* Read some */
    char buf[8];
    ring_buffer_pop(rb, buf, 2);

    /* Push more to cause wraparound */
    ring_buffer_push(rb, "5678", 4);

    /* Read all - should get "345678" */
    memset(buf, 0, 8);
    size_t read = ring_buffer_pop(rb, buf, 8);
    assert(read == 6);
    assert(memcmp(buf, "345678", 6) == 0);

    ring_buffer_destroy(rb);
}

TEST(peek) {
    ring_buffer_t* rb = ring_buffer_create(16);

    ring_buffer_push(rb, "hello", 5);

    char buf[16] = {0};
    size_t peeked = ring_buffer_peek(rb, buf, 3);
    assert(peeked == 3);
    assert(memcmp(buf, "hel", 3) == 0);

    /* Size should be unchanged */
    assert(ring_buffer_size(rb) == 5);

    ring_buffer_destroy(rb);
}

TEST(clear) {
    ring_buffer_t* rb = ring_buffer_create(16);

    ring_buffer_push(rb, "hello", 5);
    assert(!ring_buffer_is_empty(rb));

    ring_buffer_clear(rb);
    assert(ring_buffer_is_empty(rb));

    ring_buffer_destroy(rb);
}

TEST(partial_read_write) {
    ring_buffer_t* rb = ring_buffer_create(4);

    /* Push more than capacity */
    size_t written = ring_buffer_push(rb, "hello", 5);
    assert(written == 4);  /* Limited to capacity */

    /* Pop less than available */
    char buf[8] = {0};
    size_t read = ring_buffer_pop(rb, buf, 2);
    assert(read == 2);
    assert(memcmp(buf, "he", 2) == 0);

    ring_buffer_destroy(rb);
}

TEST(multiple_push_pop) {
    ring_buffer_t* rb = ring_buffer_create(16);
    char buf[16];

    for (int i = 0; i < 100; i++) {
        ring_buffer_push(rb, "ab", 2);
        size_t read = ring_buffer_pop(rb, buf, 2);
        assert(read == 2);
        assert(buf[0] == 'a' && buf[1] == 'b');
    }

    assert(ring_buffer_is_empty(rb));
    ring_buffer_destroy(rb);
}

int main(void) {
    printf("Ring Buffer Tests:\n");

    RUN_TEST(create_destroy);
    RUN_TEST(power_of_2_capacity);
    RUN_TEST(push_pop_basic);
    RUN_TEST(push_full_buffer);
    RUN_TEST(wraparound);
    RUN_TEST(peek);
    RUN_TEST(clear);
    RUN_TEST(partial_read_write);
    RUN_TEST(multiple_push_pop);

    printf("\nAll tests passed!\n");
    return 0;
}
