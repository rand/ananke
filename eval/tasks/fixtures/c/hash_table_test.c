/**
 * Hash Table Tests
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

/* Include the implementation */
#include "hash_table.c"

#define TEST(name) static void test_##name(void)
#define RUN_TEST(name) do { \
    printf("  Testing %s...", #name); \
    test_##name(); \
    printf(" PASSED\n"); \
} while(0)

TEST(create_destroy) {
    hash_table_t* ht = ht_create(0);
    assert(ht != NULL);
    assert(ht_size(ht) == 0);
    ht_destroy(ht);
}

TEST(set_get) {
    hash_table_t* ht = ht_create(16);

    int value1 = 42;
    int value2 = 100;

    assert(ht_set(ht, "key1", &value1));
    assert(ht_set(ht, "key2", &value2));

    assert(ht_get(ht, "key1") == &value1);
    assert(ht_get(ht, "key2") == &value2);
    assert(ht_get(ht, "nonexistent") == NULL);

    ht_destroy(ht);
}

TEST(update_value) {
    hash_table_t* ht = ht_create(16);

    int value1 = 42;
    int value2 = 100;

    ht_set(ht, "key", &value1);
    assert(ht_get(ht, "key") == &value1);
    assert(ht_size(ht) == 1);

    /* Update same key */
    ht_set(ht, "key", &value2);
    assert(ht_get(ht, "key") == &value2);
    assert(ht_size(ht) == 1);  /* Size should stay same */

    ht_destroy(ht);
}

TEST(delete) {
    hash_table_t* ht = ht_create(16);

    int value = 42;
    ht_set(ht, "key", &value);
    assert(ht_size(ht) == 1);

    assert(ht_delete(ht, "key"));
    assert(ht_size(ht) == 0);
    assert(ht_get(ht, "key") == NULL);

    /* Delete non-existent */
    assert(!ht_delete(ht, "key"));

    ht_destroy(ht);
}

TEST(contains) {
    hash_table_t* ht = ht_create(16);

    int value = 42;
    assert(!ht_contains(ht, "key"));

    ht_set(ht, "key", &value);
    assert(ht_contains(ht, "key"));

    ht_delete(ht, "key");
    assert(!ht_contains(ht, "key"));

    ht_destroy(ht);
}

TEST(resize) {
    hash_table_t* ht = ht_create(4);

    char keys[100][16];
    int values[100];

    /* Insert enough to trigger resize */
    for (int i = 0; i < 50; i++) {
        snprintf(keys[i], 16, "key%d", i);
        values[i] = i * 10;
        ht_set(ht, keys[i], &values[i]);
    }

    assert(ht_size(ht) == 50);
    assert(ht_capacity(ht) > 4);  /* Should have resized */

    /* Verify all values */
    for (int i = 0; i < 50; i++) {
        int* v = ht_get(ht, keys[i]);
        assert(v != NULL);
        assert(*v == i * 10);
    }

    ht_destroy(ht);
}

TEST(collision_handling) {
    /* Use small capacity to force collisions */
    hash_table_t* ht = ht_create(2);

    int v1 = 1, v2 = 2, v3 = 3;

    ht_set(ht, "a", &v1);
    ht_set(ht, "b", &v2);
    ht_set(ht, "c", &v3);

    assert(ht_get(ht, "a") == &v1);
    assert(ht_get(ht, "b") == &v2);
    assert(ht_get(ht, "c") == &v3);

    /* Delete middle of chain */
    ht_delete(ht, "b");
    assert(ht_get(ht, "a") == &v1);
    assert(ht_get(ht, "b") == NULL);
    assert(ht_get(ht, "c") == &v3);

    ht_destroy(ht);
}

TEST(iterator) {
    hash_table_t* ht = ht_create(16);

    int v1 = 1, v2 = 2, v3 = 3;
    ht_set(ht, "one", &v1);
    ht_set(ht, "two", &v2);
    ht_set(ht, "three", &v3);

    ht_iterator_t* it = ht_iterator_create(ht);
    int count = 0;

    const char* key;
    void* value;
    while (ht_iterator_has_next(it)) {
        assert(ht_iterator_next(it, &key, &value));
        assert(ht_contains(ht, key));
        count++;
    }

    assert(count == 3);

    ht_iterator_destroy(it);
    ht_destroy(ht);
}

TEST(null_handling) {
    hash_table_t* ht = ht_create(16);

    assert(!ht_set(ht, NULL, NULL));
    assert(ht_get(ht, NULL) == NULL);
    assert(!ht_delete(ht, NULL));
    assert(!ht_contains(ht, NULL));

    /* NULL values are allowed */
    ht_set(ht, "key", NULL);
    assert(ht_get(ht, "key") == NULL);
    assert(ht_contains(ht, "key"));

    ht_destroy(ht);
}

TEST(empty_string_key) {
    hash_table_t* ht = ht_create(16);

    int value = 42;
    ht_set(ht, "", &value);
    assert(ht_get(ht, "") == &value);

    ht_destroy(ht);
}

int main(void) {
    printf("Hash Table Tests:\n");

    RUN_TEST(create_destroy);
    RUN_TEST(set_get);
    RUN_TEST(update_value);
    RUN_TEST(delete);
    RUN_TEST(contains);
    RUN_TEST(resize);
    RUN_TEST(collision_handling);
    RUN_TEST(iterator);
    RUN_TEST(null_handling);
    RUN_TEST(empty_string_key);

    printf("\nAll tests passed!\n");
    return 0;
}
