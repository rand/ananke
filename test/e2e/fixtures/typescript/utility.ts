// Utility Functions Test Fixture
// Tests constraint extraction for:
// - Pure functions
// - Type guards
// - Generic utilities
// - Data transformations

type Result<T, E> = { ok: true; value: T } | { ok: false; error: E };

// Array utilities with type constraints
function chunk<T>(array: T[], size: number): T[][] {
    if (size <= 0) {
        throw new Error('Chunk size must be positive');
    }

    const chunks: T[][] = [];
    for (let i = 0; i < array.length; i += size) {
        chunks.push(array.slice(i, i + size));
    }
    return chunks;
}

function unique<T>(array: T[]): T[] {
    return Array.from(new Set(array));
}

function groupBy<T, K extends string | number>(
    array: T[],
    keyFn: (item: T) => K
): Record<K, T[]> {
    const groups = {} as Record<K, T[]>;
    
    for (const item of array) {
        const key = keyFn(item);
        if (!groups[key]) {
            groups[key] = [];
        }
        groups[key].push(item);
    }
    
    return groups;
}

// String utilities with validation constraints
function sanitizeHtml(input: string): string {
    return input
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#x27;');
}

function truncate(text: string, maxLength: number, suffix: string = '...'): string {
    if (text.length <= maxLength) {
        return text;
    }
    return text.substring(0, maxLength - suffix.length) + suffix;
}

function slugify(text: string): string {
    return text
        .toLowerCase()
        .trim()
        .replace(/[^\w\s-]/g, '')
        .replace(/[\s_-]+/g, '-')
        .replace(/^-+|-+$/g, '');
}

// Type guards
function isString(value: unknown): value is string {
    return typeof value === 'string';
}

function isNumber(value: unknown): value is number {
    return typeof value === 'number' && !isNaN(value);
}

function isObject(value: unknown): value is Record<string, unknown> {
    return typeof value === 'object' && value !== null && !Array.isArray(value);
}

// Result type utilities
function ok<T>(value: T): Result<T, never> {
    return { ok: true, value };
}

function err<E>(error: E): Result<never, E> {
    return { ok: false, error };
}

function tryParse(json: string): Result<any, string> {
    try {
        return ok(JSON.parse(json));
    } catch (e) {
        return err(e instanceof Error ? e.message : 'Parse error');
    }
}

export {
    Result,
    chunk,
    unique,
    groupBy,
    sanitizeHtml,
    truncate,
    slugify,
    isString,
    isNumber,
    isObject,
    ok,
    err,
    tryParse
};
