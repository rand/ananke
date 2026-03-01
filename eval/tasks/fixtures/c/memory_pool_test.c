/**
 * Memory Pool Tests
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

/* Include the implementation */
#include "memory_pool.c"

#define TEST(name) static void test_##name(void)
#define RUN_TEST(name) do { \
    printf("  Testing %s...", #name); \
    test_##name(); \
    printf(" PASSED\n"); \
} while(0)

TEST(create_destroy) {
    mem_pool_t* pool = pool_create(64, 10);
    assert(pool != NULL);
    assert(pool_capacity(pool) == 10);
    assert(pool_available(pool) == 10);
    assert(pool_used(pool) == 0);
    assert(pool_is_empty(pool));
    assert(!pool_is_full(pool));
    pool_destroy(pool);
}

TEST(alloc_free) {
    mem_pool_t* pool = pool_create(64, 3);

    void* b1 = pool_alloc(pool);
    assert(b1 != NULL);
    assert(pool_available(pool) == 2);

    void* b2 = pool_alloc(pool);
    assert(b2 != NULL);
    assert(b2 != b1);
    assert(pool_available(pool) == 1);

    void* b3 = pool_alloc(pool);
    assert(b3 != NULL);
    assert(pool_available(pool) == 0);
    assert(pool_is_full(pool));

    /* Pool exhausted */
    void* b4 = pool_alloc(pool);
    assert(b4 == NULL);

    /* Free one */
    assert(pool_free(pool, b2));
    assert(pool_available(pool) == 1);

    /* Can allocate again */
    void* b5 = pool_alloc(pool);
    assert(b5 == b2);  /* Should reuse freed block */

    pool_destroy(pool);
}

TEST(invalid_free) {
    mem_pool_t* pool = pool_create(64, 5);

    /* Free NULL */
    assert(!pool_free(pool, NULL));

    /* Free pointer outside pool */
    int outside;
    assert(!pool_free(pool, &outside));

    /* Free misaligned pointer */
    void* b1 = pool_alloc(pool);
    assert(!pool_free(pool, (char*)b1 + 1));  /* Misaligned */

    pool_free(pool, b1);
    pool_destroy(pool);
}

TEST(minimum_block_size) {
    /* Very small block size should be adjusted */
    mem_pool_t* pool = pool_create(1, 10);
    assert(pool != NULL);
    assert(pool_block_size(pool) >= sizeof(void*));
    pool_destroy(pool);
}

TEST(calloc) {
    mem_pool_t* pool = pool_create(64, 5);

    void* block = pool_calloc(pool);
    assert(block != NULL);

    /* Verify zeroed */
    char* p = (char*)block;
    for (size_t i = 0; i < 64; i++) {
        assert(p[i] == 0);
    }

    pool_destroy(pool);
}

TEST(reset) {
    mem_pool_t* pool = pool_create(64, 5);

    /* Allocate all */
    for (int i = 0; i < 5; i++) {
        pool_alloc(pool);
    }
    assert(pool_is_full(pool));

    /* Reset */
    pool_reset(pool);
    assert(pool_is_empty(pool));
    assert(pool_available(pool) == 5);

    /* Can allocate again */
    for (int i = 0; i < 5; i++) {
        assert(pool_alloc(pool) != NULL);
    }

    pool_destroy(pool);
}

static int visitor_count = 0;
static void test_visitor(void* block, void* user_data) {
    (void)block;
    (void)user_data;
    visitor_count++;
}

TEST(foreach_used) {
    mem_pool_t* pool = pool_create(64, 5);

    void* b1 = pool_alloc(pool);
    void* b2 = pool_alloc(pool);
    void* b3 = pool_alloc(pool);
    pool_free(pool, b2);  /* Free middle one */

    visitor_count = 0;
    pool_foreach_used(pool, test_visitor, NULL);
    assert(visitor_count == 2);  /* b1 and b3 */

    (void)b1;
    (void)b3;
    pool_destroy(pool);
}

TEST(write_to_blocks) {
    /* Verify we can actually use the allocated memory */
    mem_pool_t* pool = pool_create(sizeof(int) * 4, 3);

    int* arr1 = pool_alloc(pool);
    int* arr2 = pool_alloc(pool);
    int* arr3 = pool_alloc(pool);

    /* Write to blocks */
    for (int i = 0; i < 4; i++) {
        arr1[i] = i;
        arr2[i] = i * 10;
        arr3[i] = i * 100;
    }

    /* Verify data */
    for (int i = 0; i < 4; i++) {
        assert(arr1[i] == i);
        assert(arr2[i] == i * 10);
        assert(arr3[i] == i * 100);
    }

    pool_destroy(pool);
}

TEST(stress) {
    mem_pool_t* pool = pool_create(32, 100);
    void* blocks[100];

    /* Allocate all */
    for (int i = 0; i < 100; i++) {
        blocks[i] = pool_alloc(pool);
        assert(blocks[i] != NULL);
    }

    /* Free every other one */
    for (int i = 0; i < 100; i += 2) {
        pool_free(pool, blocks[i]);
    }
    assert(pool_available(pool) == 50);

    /* Reallocate */
    for (int i = 0; i < 50; i++) {
        assert(pool_alloc(pool) != NULL);
    }
    assert(pool_is_full(pool));

    pool_destroy(pool);
}

int main(void) {
    printf("Memory Pool Tests:\n");

    RUN_TEST(create_destroy);
    RUN_TEST(alloc_free);
    RUN_TEST(invalid_free);
    RUN_TEST(minimum_block_size);
    RUN_TEST(calloc);
    RUN_TEST(reset);
    RUN_TEST(foreach_used);
    RUN_TEST(write_to_blocks);
    RUN_TEST(stress);

    printf("\nAll tests passed!\n");
    return 0;
}
