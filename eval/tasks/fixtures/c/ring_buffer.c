/**
 * Lock-Free Ring Buffer Implementation
 * Single-producer single-consumer circular buffer with power-of-2 capacity.
 */

#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdatomic.h>

typedef struct ring_buffer {
    uint8_t* buffer;
    size_t capacity;     /* Always power of 2 */
    size_t mask;         /* capacity - 1 for fast modulo */
    atomic_size_t head;  /* Write position */
    atomic_size_t tail;  /* Read position */
} ring_buffer_t;

/* Round up to next power of 2 */
static size_t next_power_of_2(size_t n) {
    if (n == 0) return 1;
    n--;
    n |= n >> 1;
    n |= n >> 2;
    n |= n >> 4;
    n |= n >> 8;
    n |= n >> 16;
#if SIZE_MAX > 0xFFFFFFFF
    n |= n >> 32;
#endif
    return n + 1;
}

ring_buffer_t* ring_buffer_create(size_t capacity) {
    if (capacity == 0) {
        capacity = 1;
    }

    /* Round up to power of 2 */
    capacity = next_power_of_2(capacity);

    ring_buffer_t* rb = malloc(sizeof(ring_buffer_t));
    if (!rb) return NULL;

    rb->buffer = malloc(capacity);
    if (!rb->buffer) {
        free(rb);
        return NULL;
    }

    rb->capacity = capacity;
    rb->mask = capacity - 1;
    atomic_init(&rb->head, 0);
    atomic_init(&rb->tail, 0);

    return rb;
}

void ring_buffer_destroy(ring_buffer_t* rb) {
    if (rb) {
        free(rb->buffer);
        free(rb);
    }
}

size_t ring_buffer_size(ring_buffer_t* rb) {
    size_t head = atomic_load(&rb->head);
    size_t tail = atomic_load(&rb->tail);
    return head - tail;
}

size_t ring_buffer_available(ring_buffer_t* rb) {
    return rb->capacity - ring_buffer_size(rb);
}

bool ring_buffer_is_empty(ring_buffer_t* rb) {
    return ring_buffer_size(rb) == 0;
}

bool ring_buffer_is_full(ring_buffer_t* rb) {
    return ring_buffer_size(rb) == rb->capacity;
}

size_t ring_buffer_push(ring_buffer_t* rb, const void* data, size_t size) {
    if (!rb || !data || size == 0) return 0;

    size_t available = ring_buffer_available(rb);
    if (available == 0) return 0;

    /* Limit to available space */
    size_t to_write = (size < available) ? size : available;
    size_t head = atomic_load(&rb->head);

    const uint8_t* src = (const uint8_t*)data;

    for (size_t i = 0; i < to_write; i++) {
        rb->buffer[(head + i) & rb->mask] = src[i];
    }

    atomic_store(&rb->head, head + to_write);
    return to_write;
}

size_t ring_buffer_pop(ring_buffer_t* rb, void* buf, size_t size) {
    if (!rb || !buf || size == 0) return 0;

    size_t current_size = ring_buffer_size(rb);
    if (current_size == 0) return 0;

    /* Limit to available data */
    size_t to_read = (size < current_size) ? size : current_size;
    size_t tail = atomic_load(&rb->tail);

    uint8_t* dst = (uint8_t*)buf;

    for (size_t i = 0; i < to_read; i++) {
        dst[i] = rb->buffer[(tail + i) & rb->mask];
    }

    atomic_store(&rb->tail, tail + to_read);
    return to_read;
}

size_t ring_buffer_peek(ring_buffer_t* rb, void* buf, size_t size) {
    if (!rb || !buf || size == 0) return 0;

    size_t current_size = ring_buffer_size(rb);
    if (current_size == 0) return 0;

    size_t to_peek = (size < current_size) ? size : current_size;
    size_t tail = atomic_load(&rb->tail);

    uint8_t* dst = (uint8_t*)buf;

    for (size_t i = 0; i < to_peek; i++) {
        dst[i] = rb->buffer[(tail + i) & rb->mask];
    }

    return to_peek;
}

void ring_buffer_clear(ring_buffer_t* rb) {
    if (rb) {
        atomic_store(&rb->tail, atomic_load(&rb->head));
    }
}

size_t ring_buffer_capacity(ring_buffer_t* rb) {
    return rb ? rb->capacity : 0;
}
