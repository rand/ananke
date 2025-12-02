class ListNode {
  key: number;
  value: number;
  prev: ListNode | null = null;
  next: ListNode | null = null;

  constructor(key: number, value: number) {
    this.key = key;
    this.value = value;
  }
}

class LRUCache {
  private capacity: number;
  private cache: Map<number, ListNode>;
  private head: ListNode; // Most recently used (dummy head)
  private tail: ListNode; // Least recently used (dummy tail)

  constructor(capacity: number) {
    this.capacity = capacity;
    this.cache = new Map();

    // Create dummy head and tail nodes
    this.head = new ListNode(0, 0);
    this.tail = new ListNode(0, 0);
    this.head.next = this.tail;
    this.tail.prev = this.head;
  }

  get(key: number): number | null {
    const node = this.cache.get(key);

    if (!node) {
      return null;
    }

    // Move accessed node to front (most recently used)
    this.moveToFront(node);

    return node.value;
  }

  put(key: number, value: number): void {
    const existingNode = this.cache.get(key);

    if (existingNode) {
      // Update existing node value and move to front
      existingNode.value = value;
      this.moveToFront(existingNode);
    } else {
      // Create new node
      const newNode = new ListNode(key, value);

      // Add to cache and linked list
      this.cache.set(key, newNode);
      this.addToFront(newNode);

      // Check if we exceeded capacity
      if (this.cache.size > this.capacity) {
        // Remove least recently used (node before tail)
        const lru = this.tail.prev!;
        this.removeNode(lru);
        this.cache.delete(lru.key);
      }
    }
  }

  private addToFront(node: ListNode): void {
    // Add node right after head (most recently used position)
    node.prev = this.head;
    node.next = this.head.next;
    this.head.next!.prev = node;
    this.head.next = node;
  }

  private removeNode(node: ListNode): void {
    // Remove node from linked list
    const prevNode = node.prev!;
    const nextNode = node.next!;
    prevNode.next = nextNode;
    nextNode.prev = prevNode;
  }

  private moveToFront(node: ListNode): void {
    // Remove from current position
    this.removeNode(node);
    // Add to front (most recently used)
    this.addToFront(node);
  }
}

export { LRUCache };
