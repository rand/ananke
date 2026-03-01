/**
 * Event Emitter Implementation
 * Demonstrates the observer pattern in JavaScript
 */

class EventEmitter {
  constructor() {
    this._listeners = new Map();
    this._onceListeners = new Map();
    this.maxListeners = 10;
  }

  on(event, listener) {
    if (typeof listener !== 'function') {
      throw new TypeError('Listener must be a function');
    }

    if (!this._listeners.has(event)) {
      this._listeners.set(event, []);
    }

    const listeners = this._listeners.get(event);

    if (listeners.length >= this.maxListeners) {
      console.warn(`MaxListenersExceededWarning: Possible memory leak. ${listeners.length + 1} listeners added to ${event}`);
    }

    listeners.push(listener);
    return this;
  }

  once(event, listener) {
    if (typeof listener !== 'function') {
      throw new TypeError('Listener must be a function');
    }

    if (!this._onceListeners.has(event)) {
      this._onceListeners.set(event, []);
    }

    this._onceListeners.get(event).push(listener);
    return this;
  }

  emit(event, ...args) {
    let called = false;

    // Get once listeners first (they are prepended)
    const onceListeners = this._onceListeners.has(event)
      ? this._onceListeners.get(event).slice()
      : [];

    // Clear once listeners before calling (they only fire once)
    if (onceListeners.length > 0) {
      this._onceListeners.set(event, []);
    }

    // Call once listeners first (prepended)
    for (const listener of onceListeners) {
      listener.apply(this, args);
      called = true;
    }

    // Then call regular listeners
    if (this._listeners.has(event)) {
      const listeners = this._listeners.get(event).slice();
      for (const listener of listeners) {
        listener.apply(this, args);
        called = true;
      }
    }

    return called;
  }

  off(event, listener) {
    if (this._listeners.has(event)) {
      const listeners = this._listeners.get(event);
      const index = listeners.indexOf(listener);
      if (index !== -1) {
        listeners.splice(index, 1);
      }
    }

    if (this._onceListeners.has(event)) {
      const listeners = this._onceListeners.get(event);
      const index = listeners.indexOf(listener);
      if (index !== -1) {
        listeners.splice(index, 1);
      }
    }

    return this;
  }

  removeAllListeners(event) {
    if (event === undefined) {
      this._listeners.clear();
      this._onceListeners.clear();
    } else {
      this._listeners.delete(event);
      this._onceListeners.delete(event);
    }
    return this;
  }

  listenerCount(event) {
    const regular = this._listeners.has(event) ? this._listeners.get(event).length : 0;
    const once = this._onceListeners.has(event) ? this._onceListeners.get(event).length : 0;
    return regular + once;
  }

  listeners(event) {
    const regular = this._listeners.get(event) || [];
    const once = this._onceListeners.get(event) || [];
    return [...regular, ...once];
  }

  eventNames() {
    const names = new Set([
      ...this._listeners.keys(),
      ...this._onceListeners.keys()
    ]);
    return Array.from(names);
  }

  setMaxListeners(n) {
    this.maxListeners = n;
    return this;
  }

  getMaxListeners() {
    return this.maxListeners;
  }

  prependListener(event, listener) {
    if (typeof listener !== 'function') {
      throw new TypeError('Listener must be a function');
    }

    if (!this._listeners.has(event)) {
      this._listeners.set(event, []);
    }

    this._listeners.get(event).unshift(listener);
    return this;
  }

  prependOnceListener(event, listener) {
    if (typeof listener !== 'function') {
      throw new TypeError('Listener must be a function');
    }

    if (!this._onceListeners.has(event)) {
      this._onceListeners.set(event, []);
    }

    this._onceListeners.get(event).unshift(listener);
    return this;
  }
}

class TypedEventEmitter extends EventEmitter {
  constructor(eventTypes = []) {
    super();
    this.eventTypes = new Set(eventTypes);
    this.strictMode = eventTypes.length > 0;
  }

  _validateEvent(event) {
    if (this.strictMode && !this.eventTypes.has(event)) {
      throw new Error(`Unknown event type: ${event}`);
    }
  }

  on(event, listener) {
    this._validateEvent(event);
    return super.on(event, listener);
  }

  once(event, listener) {
    this._validateEvent(event);
    return super.once(event, listener);
  }

  emit(event, ...args) {
    this._validateEvent(event);
    return super.emit(event, ...args);
  }

  registerEventType(event) {
    this.eventTypes.add(event);
    return this;
  }
}

class AsyncEventEmitter extends EventEmitter {
  async emit(event, ...args) {
    const results = [];

    if (this._listeners.has(event)) {
      const listeners = this._listeners.get(event).slice();
      for (const listener of listeners) {
        results.push(await listener.apply(this, args));
      }
    }

    if (this._onceListeners.has(event)) {
      const listeners = this._onceListeners.get(event).slice();
      this._onceListeners.set(event, []);
      for (const listener of listeners) {
        results.push(await listener.apply(this, args));
      }
    }

    return results;
  }

  async emitParallel(event, ...args) {
    const promises = [];

    if (this._listeners.has(event)) {
      const listeners = this._listeners.get(event).slice();
      for (const listener of listeners) {
        promises.push(listener.apply(this, args));
      }
    }

    if (this._onceListeners.has(event)) {
      const listeners = this._onceListeners.get(event).slice();
      this._onceListeners.set(event, []);
      for (const listener of listeners) {
        promises.push(listener.apply(this, args));
      }
    }

    return Promise.all(promises);
  }
}

module.exports = {
  EventEmitter,
  TypedEventEmitter,
  AsyncEventEmitter
};
