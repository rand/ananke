/**
 * Hash Table with Chaining Implementation
 * Uses separate chaining for collision resolution with dynamic resizing.
 */

#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stddef.h>

#define INITIAL_CAPACITY 16
#define LOAD_FACTOR_THRESHOLD 0.75

typedef struct ht_entry {
    char* key;
    void* value;
    struct ht_entry* next;
} ht_entry_t;

typedef struct hash_table {
    ht_entry_t** buckets;
    size_t capacity;
    size_t size;
} hash_table_t;

/* djb2 hash function */
static unsigned long djb2_hash(const char* str) {
    unsigned long hash = 5381;
    int c;
    while ((c = *str++)) {
        hash = ((hash << 5) + hash) + c;  /* hash * 33 + c */
    }
    return hash;
}

static ht_entry_t* entry_create(const char* key, void* value) {
    ht_entry_t* entry = malloc(sizeof(ht_entry_t));
    if (!entry) return NULL;

    entry->key = strdup(key);
    if (!entry->key) {
        free(entry);
        return NULL;
    }

    entry->value = value;
    entry->next = NULL;
    return entry;
}

static void entry_destroy(ht_entry_t* entry) {
    if (entry) {
        free(entry->key);
        free(entry);
    }
}

hash_table_t* ht_create(size_t initial_capacity) {
    if (initial_capacity == 0) {
        initial_capacity = INITIAL_CAPACITY;
    }

    hash_table_t* ht = malloc(sizeof(hash_table_t));
    if (!ht) return NULL;

    ht->buckets = calloc(initial_capacity, sizeof(ht_entry_t*));
    if (!ht->buckets) {
        free(ht);
        return NULL;
    }

    ht->capacity = initial_capacity;
    ht->size = 0;
    return ht;
}

void ht_destroy(hash_table_t* ht) {
    if (!ht) return;

    for (size_t i = 0; i < ht->capacity; i++) {
        ht_entry_t* entry = ht->buckets[i];
        while (entry) {
            ht_entry_t* next = entry->next;
            entry_destroy(entry);
            entry = next;
        }
    }

    free(ht->buckets);
    free(ht);
}

static bool ht_resize(hash_table_t* ht) {
    size_t new_capacity = ht->capacity * 2;
    ht_entry_t** new_buckets = calloc(new_capacity, sizeof(ht_entry_t*));
    if (!new_buckets) return false;

    /* Rehash all entries */
    for (size_t i = 0; i < ht->capacity; i++) {
        ht_entry_t* entry = ht->buckets[i];
        while (entry) {
            ht_entry_t* next = entry->next;
            size_t new_index = djb2_hash(entry->key) % new_capacity;
            entry->next = new_buckets[new_index];
            new_buckets[new_index] = entry;
            entry = next;
        }
    }

    free(ht->buckets);
    ht->buckets = new_buckets;
    ht->capacity = new_capacity;
    return true;
}

bool ht_set(hash_table_t* ht, const char* key, void* value) {
    if (!ht || !key) return false;

    /* Check for resize */
    double load_factor = (double)ht->size / ht->capacity;
    if (load_factor > LOAD_FACTOR_THRESHOLD) {
        if (!ht_resize(ht)) return false;
    }

    size_t index = djb2_hash(key) % ht->capacity;

    /* Check if key exists - update value */
    ht_entry_t* entry = ht->buckets[index];
    while (entry) {
        if (strcmp(entry->key, key) == 0) {
            entry->value = value;
            return true;
        }
        entry = entry->next;
    }

    /* Create new entry */
    ht_entry_t* new_entry = entry_create(key, value);
    if (!new_entry) return false;

    new_entry->next = ht->buckets[index];
    ht->buckets[index] = new_entry;
    ht->size++;

    return true;
}

void* ht_get(hash_table_t* ht, const char* key) {
    if (!ht || !key) return NULL;

    size_t index = djb2_hash(key) % ht->capacity;
    ht_entry_t* entry = ht->buckets[index];

    while (entry) {
        if (strcmp(entry->key, key) == 0) {
            return entry->value;
        }
        entry = entry->next;
    }

    return NULL;
}

bool ht_contains(hash_table_t* ht, const char* key) {
    if (!ht || !key) return false;

    size_t index = djb2_hash(key) % ht->capacity;
    ht_entry_t* entry = ht->buckets[index];

    while (entry) {
        if (strcmp(entry->key, key) == 0) {
            return true;
        }
        entry = entry->next;
    }

    return false;
}

bool ht_delete(hash_table_t* ht, const char* key) {
    if (!ht || !key) return false;

    size_t index = djb2_hash(key) % ht->capacity;
    ht_entry_t* entry = ht->buckets[index];
    ht_entry_t* prev = NULL;

    while (entry) {
        if (strcmp(entry->key, key) == 0) {
            if (prev) {
                prev->next = entry->next;
            } else {
                ht->buckets[index] = entry->next;
            }
            entry_destroy(entry);
            ht->size--;
            return true;
        }
        prev = entry;
        entry = entry->next;
    }

    return false;
}

size_t ht_size(hash_table_t* ht) {
    return ht ? ht->size : 0;
}

size_t ht_capacity(hash_table_t* ht) {
    return ht ? ht->capacity : 0;
}

/* Iterator support */
typedef struct ht_iterator {
    hash_table_t* ht;
    size_t bucket_index;
    ht_entry_t* current;
} ht_iterator_t;

ht_iterator_t* ht_iterator_create(hash_table_t* ht) {
    if (!ht) return NULL;

    ht_iterator_t* it = malloc(sizeof(ht_iterator_t));
    if (!it) return NULL;

    it->ht = ht;
    it->bucket_index = 0;
    it->current = NULL;

    /* Find first entry */
    for (size_t i = 0; i < ht->capacity; i++) {
        if (ht->buckets[i]) {
            it->bucket_index = i;
            it->current = ht->buckets[i];
            break;
        }
    }

    return it;
}

bool ht_iterator_has_next(ht_iterator_t* it) {
    return it && it->current != NULL;
}

bool ht_iterator_next(ht_iterator_t* it, const char** key, void** value) {
    if (!it || !it->current) return false;

    if (key) *key = it->current->key;
    if (value) *value = it->current->value;

    /* Move to next */
    if (it->current->next) {
        it->current = it->current->next;
    } else {
        it->current = NULL;
        for (size_t i = it->bucket_index + 1; i < it->ht->capacity; i++) {
            if (it->ht->buckets[i]) {
                it->bucket_index = i;
                it->current = it->ht->buckets[i];
                break;
            }
        }
    }

    return true;
}

void ht_iterator_destroy(ht_iterator_t* it) {
    free(it);
}
