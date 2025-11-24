// Sample TypeScript test file with Jest assertions for testing the assertion parser

describe('Email Validator', () => {
    test('validates email format', () => {
        expect(validateEmail('test@example.com')).toBe(true);
        expect(validateEmail('user.name+tag@domain.co.uk')).toBe(true);
        expect(validateEmail('invalid')).toBe(false);
        expect(validateEmail('')).toBe(false);
        expect(validateEmail('missing@domain')).toBe(false);
    });

    test('throws on null input', () => {
        expect(() => validateEmail(null)).toThrow('Input cannot be null');
        expect(() => validateEmail(undefined)).toThrow();
    });
});

describe('User Service', () => {
    test('creates user with valid data', async () => {
        const user = await createUser({
            name: 'John Doe',
            email: 'john@example.com',
            age: 25
        });

        expect(user).toHaveProperty('id');
        expect(user.name).toEqual('John Doe');
        expect(user.email).toEqual('john@example.com');
        expect(user.age).toBeGreaterThan(0);
        expect(user.age).toBeLessThan(150);
        expect(user.isActive).toBeTruthy();
    });

    test('rejects invalid user data', async () => {
        const result = await createUser({ name: '', email: 'invalid' });
        expect(result).toBeNull();
        expect(result).toBeFalsy();
    });

    test('finds user by id', async () => {
        const user = await findUserById('123');
        expect(user).toBeDefined();
        expect(user).not.toBeNull();
        expect(user).not.toBeUndefined();
    });
});

describe('String Utils', () => {
    test('formats strings correctly', () => {
        expect(toUpperCase('hello')).toBe('HELLO');
        expect(toLowerCase('WORLD')).toBe('world');
        expect(capitalize('test')).toEqual('Test');
    });

    test('matches patterns', () => {
        expect(formatPhone('1234567890')).toMatch(/\d{3}-\d{3}-\d{4}/);
        expect(formatDate(new Date())).toMatch(/\d{4}-\d{2}-\d{2}/);
    });

    test('checks string membership', () => {
        expect(parseCSV('a,b,c')).toContain('b');
        expect(splitWords('hello world')).toContain('hello');
    });
});

describe('Math Operations', () => {
    test('performs calculations', () => {
        expect(add(2, 3)).toBe(5);
        expect(subtract(10, 4)).toEqual(6);
        expect(multiply(3, 7)).toBe(21);
        expect(divide(15, 3)).toBe(5);
    });

    test('handles edge cases', () => {
        expect(divide(10, 0)).toBeNaN();
        expect(sqrt(-1)).toBeNaN();
        expect(factorial(0)).toBe(1);
    });

    test('compares values', () => {
        expect(max(5, 3)).toBeGreaterThan(4);
        expect(min(2, 8)).toBeLessThan(3);
        expect(clamp(15, 0, 10)).toBeLessThanOrEqual(10);
        expect(clamp(-5, 0, 10)).toBeGreaterThanOrEqual(0);
    });
});

describe('Object Utils', () => {
    test('deep clones objects', () => {
        const original = { a: 1, b: { c: 2 } };
        const cloned = deepClone(original);
        expect(cloned).toEqual(original);
        expect(cloned).not.toBe(original);
    });

    test('merges objects', () => {
        const result = mergeObjects({ a: 1 }, { b: 2 });
        expect(result).toHaveProperty('a', 1);
        expect(result).toHaveProperty('b', 2);
    });
});

// Test with different assertion styles
it('should handle async operations', async () => {
    await expect(fetchData('https://api.example.com')).resolves.toBeDefined();
    await expect(fetchData('invalid-url')).rejects.toThrow('Network error');
});

it('should validate complex conditions', () => {
    const result = processData({ type: 'user', status: 'active' });
    expect(result).toBeTruthy();
    expect(result.processed).toBe(true);
    expect(result.errors).toBeUndefined();
    expect(result.warnings).toBeNull();
});