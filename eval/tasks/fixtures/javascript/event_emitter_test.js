const { EventEmitter, TypedEventEmitter, AsyncEventEmitter } = require('./event_emitter');

describe('EventEmitter', () => {
  let emitter;

  beforeEach(() => {
    emitter = new EventEmitter();
  });

  test('on and emit', () => {
    const callback = jest.fn();
    emitter.on('test', callback);
    emitter.emit('test', 'arg1', 'arg2');

    expect(callback).toHaveBeenCalledWith('arg1', 'arg2');
    expect(callback).toHaveBeenCalledTimes(1);
  });

  test('multiple listeners', () => {
    const callback1 = jest.fn();
    const callback2 = jest.fn();

    emitter.on('test', callback1);
    emitter.on('test', callback2);
    emitter.emit('test', 'data');

    expect(callback1).toHaveBeenCalledWith('data');
    expect(callback2).toHaveBeenCalledWith('data');
  });

  test('once fires only once', () => {
    const callback = jest.fn();
    emitter.once('test', callback);

    emitter.emit('test');
    emitter.emit('test');

    expect(callback).toHaveBeenCalledTimes(1);
  });

  test('off removes listener', () => {
    const callback = jest.fn();
    emitter.on('test', callback);
    emitter.off('test', callback);
    emitter.emit('test');

    expect(callback).not.toHaveBeenCalled();
  });

  test('removeAllListeners', () => {
    const callback1 = jest.fn();
    const callback2 = jest.fn();

    emitter.on('event1', callback1);
    emitter.on('event2', callback2);
    emitter.removeAllListeners('event1');

    emitter.emit('event1');
    emitter.emit('event2');

    expect(callback1).not.toHaveBeenCalled();
    expect(callback2).toHaveBeenCalled();
  });

  test('removeAllListeners without event', () => {
    const callback = jest.fn();
    emitter.on('event1', callback);
    emitter.on('event2', callback);
    emitter.removeAllListeners();

    emitter.emit('event1');
    emitter.emit('event2');

    expect(callback).not.toHaveBeenCalled();
  });

  test('listenerCount', () => {
    emitter.on('test', () => {});
    emitter.on('test', () => {});
    emitter.once('test', () => {});

    expect(emitter.listenerCount('test')).toBe(3);
    expect(emitter.listenerCount('other')).toBe(0);
  });

  test('listeners returns copy of listeners', () => {
    const fn1 = () => {};
    const fn2 = () => {};
    emitter.on('test', fn1);
    emitter.once('test', fn2);

    const listeners = emitter.listeners('test');
    expect(listeners).toContain(fn1);
    expect(listeners).toContain(fn2);
  });

  test('eventNames', () => {
    emitter.on('event1', () => {});
    emitter.on('event2', () => {});
    emitter.once('event3', () => {});

    const names = emitter.eventNames();
    expect(names).toContain('event1');
    expect(names).toContain('event2');
    expect(names).toContain('event3');
  });

  test('emit returns false for no listeners', () => {
    expect(emitter.emit('unknown')).toBe(false);
  });

  test('emit returns true when listeners called', () => {
    emitter.on('test', () => {});
    expect(emitter.emit('test')).toBe(true);
  });

  test('prependListener adds to front', () => {
    const order = [];
    emitter.on('test', () => order.push(1));
    emitter.prependListener('test', () => order.push(0));
    emitter.emit('test');

    expect(order).toEqual([0, 1]);
  });

  test('prependOnceListener', () => {
    const order = [];
    emitter.on('test', () => order.push(1));
    emitter.prependOnceListener('test', () => order.push(0));

    emitter.emit('test');
    emitter.emit('test');

    expect(order).toEqual([0, 1, 1]);
  });

  test('setMaxListeners and getMaxListeners', () => {
    emitter.setMaxListeners(5);
    expect(emitter.getMaxListeners()).toBe(5);
  });

  test('throws on non-function listener', () => {
    expect(() => emitter.on('test', 'not a function'))
      .toThrow('Listener must be a function');
  });

  test('chaining', () => {
    const result = emitter
      .on('test', () => {})
      .once('test', () => {})
      .off('test', () => {});

    expect(result).toBe(emitter);
  });
});

describe('TypedEventEmitter', () => {
  test('allows registered events', () => {
    const emitter = new TypedEventEmitter(['click', 'hover']);
    const callback = jest.fn();

    emitter.on('click', callback);
    emitter.emit('click');

    expect(callback).toHaveBeenCalled();
  });

  test('throws on unknown event', () => {
    const emitter = new TypedEventEmitter(['click']);

    expect(() => emitter.on('unknown', () => {}))
      .toThrow('Unknown event type: unknown');
  });

  test('registerEventType adds new type', () => {
    const emitter = new TypedEventEmitter(['click']);
    emitter.registerEventType('hover');

    expect(() => emitter.on('hover', () => {})).not.toThrow();
  });

  test('non-strict mode allows any event', () => {
    const emitter = new TypedEventEmitter();
    expect(() => emitter.on('anything', () => {})).not.toThrow();
  });
});

describe('AsyncEventEmitter', () => {
  test('emit awaits listeners sequentially', async () => {
    const emitter = new AsyncEventEmitter();
    const order = [];

    emitter.on('test', async () => {
      await delay(20);
      order.push(1);
    });
    emitter.on('test', async () => {
      order.push(2);
    });

    await emitter.emit('test');
    expect(order).toEqual([1, 2]);
  });

  test('emitParallel runs listeners in parallel', async () => {
    const emitter = new AsyncEventEmitter();
    const start = Date.now();

    emitter.on('test', async () => {
      await delay(50);
      return 1;
    });
    emitter.on('test', async () => {
      await delay(50);
      return 2;
    });

    const results = await emitter.emitParallel('test');
    const elapsed = Date.now() - start;

    expect(results).toEqual([1, 2]);
    expect(elapsed).toBeLessThan(100); // Should run in parallel
  });

  test('emit returns results', async () => {
    const emitter = new AsyncEventEmitter();

    emitter.on('test', async () => 'result1');
    emitter.on('test', async () => 'result2');

    const results = await emitter.emit('test');
    expect(results).toEqual(['result1', 'result2']);
  });
});

function delay(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
