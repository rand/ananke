/**
 * Fixed-Size Memory Pool Allocator
 * O(1) allocation/deallocation using a free list.
 */

#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct mem_pool {
    void* memory;           /* Backing memory */
    void* free_list;        /* Head of free list */
    size_t block_size;      /* Size of each block */
    size_t block_count;     /* Total number of blocks */
    size_t available;       /* Currently available blocks */
    size_t total_size;      /* Total memory size */
} mem_pool_t;

/* Minimum block size must hold a pointer for the free list */
#define MIN_BLOCK_SIZE sizeof(void*)

static size_t align_size(size_t size, size_t alignment) {
    return (size + alignment - 1) & ~(alignment - 1);
}

mem_pool_t* pool_create(size_t block_size, size_t block_count) {
    if (block_count == 0) return NULL;

    /* Ensure block size can hold a pointer */
    if (block_size < MIN_BLOCK_SIZE) {
        block_size = MIN_BLOCK_SIZE;
    }

    /* Align to pointer size */
    block_size = align_size(block_size, sizeof(void*));

    mem_pool_t* pool = malloc(sizeof(mem_pool_t));
    if (!pool) return NULL;

    size_t total_size = block_size * block_count;
    pool->memory = malloc(total_size);
    if (!pool->memory) {
        free(pool);
        return NULL;
    }

    pool->block_size = block_size;
    pool->block_count = block_count;
    pool->available = block_count;
    pool->total_size = total_size;

    /* Initialize free list */
    char* ptr = (char*)pool->memory;
    for (size_t i = 0; i < block_count - 1; i++) {
        *(void**)(ptr + i * block_size) = ptr + (i + 1) * block_size;
    }
    *(void**)(ptr + (block_count - 1) * block_size) = NULL;

    pool->free_list = pool->memory;

    return pool;
}

void pool_destroy(mem_pool_t* pool) {
    if (pool) {
        free(pool->memory);
        free(pool);
    }
}

void* pool_alloc(mem_pool_t* pool) {
    if (!pool || !pool->free_list) {
        return NULL;
    }

    /* Pop from free list */
    void* block = pool->free_list;
    pool->free_list = *(void**)block;
    pool->available--;

    return block;
}

static bool ptr_in_pool(mem_pool_t* pool, void* ptr) {
    char* p = (char*)ptr;
    char* start = (char*)pool->memory;
    char* end = start + pool->total_size;

    if (p < start || p >= end) {
        return false;
    }

    /* Check alignment */
    size_t offset = p - start;
    return (offset % pool->block_size) == 0;
}

bool pool_free(mem_pool_t* pool, void* ptr) {
    if (!pool || !ptr) {
        return false;
    }

    /* Validate pointer belongs to pool */
    if (!ptr_in_pool(pool, ptr)) {
        return false;
    }

    /* Push to free list */
    *(void**)ptr = pool->free_list;
    pool->free_list = ptr;
    pool->available++;

    return true;
}

size_t pool_available(mem_pool_t* pool) {
    return pool ? pool->available : 0;
}

size_t pool_used(mem_pool_t* pool) {
    return pool ? pool->block_count - pool->available : 0;
}

size_t pool_capacity(mem_pool_t* pool) {
    return pool ? pool->block_count : 0;
}

size_t pool_block_size(mem_pool_t* pool) {
    return pool ? pool->block_size : 0;
}

bool pool_is_empty(mem_pool_t* pool) {
    return pool_used(pool) == 0;
}

bool pool_is_full(mem_pool_t* pool) {
    return pool ? pool->available == 0 : true;
}

/* Allocate and zero-initialize */
void* pool_calloc(mem_pool_t* pool) {
    void* block = pool_alloc(pool);
    if (block) {
        memset(block, 0, pool->block_size);
    }
    return block;
}

/* Reset pool to initial state */
void pool_reset(mem_pool_t* pool) {
    if (!pool) return;

    /* Rebuild free list */
    char* ptr = (char*)pool->memory;
    for (size_t i = 0; i < pool->block_count - 1; i++) {
        *(void**)(ptr + i * pool->block_size) = ptr + (i + 1) * pool->block_size;
    }
    *(void**)(ptr + (pool->block_count - 1) * pool->block_size) = NULL;

    pool->free_list = pool->memory;
    pool->available = pool->block_count;
}

/* Iterator for allocated blocks (debugging) */
typedef void (*pool_visitor_fn)(void* block, void* user_data);

void pool_foreach_used(mem_pool_t* pool, pool_visitor_fn visitor, void* user_data) {
    if (!pool || !visitor) return;

    /* Build a set of free blocks */
    bool* is_free = calloc(pool->block_count, sizeof(bool));
    if (!is_free) return;

    void* current = pool->free_list;
    char* base = (char*)pool->memory;

    while (current) {
        size_t index = ((char*)current - base) / pool->block_size;
        is_free[index] = true;
        current = *(void**)current;
    }

    /* Visit all non-free blocks */
    for (size_t i = 0; i < pool->block_count; i++) {
        if (!is_free[i]) {
            visitor(base + i * pool->block_size, user_data);
        }
    }

    free(is_free);
}
