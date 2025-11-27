// Async Operations Test Fixture
// Tests constraint extraction for:
// - Promise-based operations
// - Async/await patterns
// - Error handling in async contexts
// - Retry logic and timeouts

interface ApiConfig {
    baseUrl: string;
    timeout: number;
    retryCount: number;
    headers?: Record<string, string>;
}

interface ApiResponse<T> {
    data?: T;
    error?: string;
    status: number;
    timestamp: number;
}

// Retry decorator with exponential backoff
function withRetry<T>(
    fn: () => Promise<T>,
    maxRetries: number = 3,
    delay: number = 1000
): Promise<T> {
    return new Promise(async (resolve, reject) => {
        let lastError: Error | undefined;

        for (let i = 0; i < maxRetries; i++) {
            try {
                const result = await fn();
                return resolve(result);
            } catch (error) {
                lastError = error instanceof Error ? error : new Error(String(error));

                if (i < maxRetries - 1) {
                    // Exponential backoff
                    const waitTime = delay * Math.pow(2, i);
                    await new Promise(r => setTimeout(r, waitTime));
                }
            }
        }

        reject(lastError || new Error('Max retries reached'));
    });
}

// Timeout wrapper with constraint
function withTimeout<T>(
    promise: Promise<T>,
    timeoutMs: number
): Promise<T> {
    if (timeoutMs <= 0) {
        throw new Error('Timeout must be positive');
    }

    if (timeoutMs > 30000) {
        throw new Error('Timeout cannot exceed 30 seconds');
    }

    return Promise.race([
        promise,
        new Promise<T>((_, reject) =>
            setTimeout(() => reject(new Error('Operation timed out')), timeoutMs)
        )
    ]);
}

// API client with multiple async constraints
class ApiClient {
    private config: ApiConfig;
    private requestCount = 0;
    private readonly maxRequestsPerSecond = 10;
    private lastRequestTime = 0;

    constructor(config: ApiConfig) {
        // Validate configuration
        if (!config.baseUrl) {
            throw new Error('Base URL is required');
        }

        if (config.timeout < 100 || config.timeout > 30000) {
            throw new Error('Timeout must be between 100ms and 30s');
        }

        if (config.retryCount < 0 || config.retryCount > 5) {
            throw new Error('Retry count must be between 0 and 5');
        }

        this.config = config;
    }

    // Rate limiting constraint
    private async enforceRateLimit(): Promise<void> {
        const now = Date.now();
        const timeSinceLastRequest = now - this.lastRequestTime;

        if (timeSinceLastRequest < 1000 / this.maxRequestsPerSecond) {
            const delay = (1000 / this.maxRequestsPerSecond) - timeSinceLastRequest;
            await new Promise(resolve => setTimeout(resolve, delay));
        }

        this.lastRequestTime = Date.now();
        this.requestCount++;
    }

    async get<T>(endpoint: string): Promise<ApiResponse<T>> {
        await this.enforceRateLimit();

        const url = `${this.config.baseUrl}${endpoint}`;

        const fetchWithRetry = () => withTimeout(
            fetch(url, {
                method: 'GET',
                headers: this.config.headers
            }),
            this.config.timeout
        );

        try {
            const response = await withRetry(
                fetchWithRetry,
                this.config.retryCount,
                1000
            );

            if (!response.ok) {
                return {
                    error: `HTTP ${response.status}: ${response.statusText}`,
                    status: response.status,
                    timestamp: Date.now()
                };
            }

            const data = await response.json();
            return {
                data,
                status: response.status,
                timestamp: Date.now()
            };
        } catch (error) {
            return {
                error: error instanceof Error ? error.message : 'Unknown error',
                status: 0,
                timestamp: Date.now()
            };
        }
    }

    async post<T>(endpoint: string, body: unknown): Promise<ApiResponse<T>> {
        await this.enforceRateLimit();

        const url = `${this.config.baseUrl}${endpoint}`;

        const fetchWithRetry = () => withTimeout(
            fetch(url, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    ...this.config.headers
                },
                body: JSON.stringify(body)
            }),
            this.config.timeout
        );

        try {
            const response = await withRetry(
                fetchWithRetry,
                this.config.retryCount,
                1000
            );

            if (!response.ok) {
                return {
                    error: `HTTP ${response.status}: ${response.statusText}`,
                    status: response.status,
                    timestamp: Date.now()
                };
            }

            const data = await response.json();
            return {
                data,
                status: response.status,
                timestamp: Date.now()
            };
        } catch (error) {
            return {
                error: error instanceof Error ? error.message : 'Unknown error',
                status: 0,
                timestamp: Date.now()
            };
        }
    }
}

// Concurrent request handler with limits
class ConcurrentRequestHandler {
    private readonly maxConcurrent = 5;
    private activeRequests = 0;
    private queue: Array<() => void> = [];

    async execute<T>(fn: () => Promise<T>): Promise<T> {
        // Wait if we're at max concurrent requests
        while (this.activeRequests >= this.maxConcurrent) {
            await new Promise<void>(resolve => {
                this.queue.push(resolve);
            });
        }

        this.activeRequests++;

        try {
            return await fn();
        } finally {
            this.activeRequests--;

            // Process queue
            const next = this.queue.shift();
            if (next) {
                next();
            }
        }
    }

    async batch<T>(requests: Array<() => Promise<T>>): Promise<T[]> {
        return Promise.all(
            requests.map(req => this.execute(req))
        );
    }
}

// Data fetcher with caching constraints
class DataFetcher {
    private cache = new Map<string, { data: unknown; timestamp: number }>();
    private readonly cacheTimeout = 60000; // 1 minute
    private readonly maxCacheSize = 100;

    async fetch<T>(key: string, fetcher: () => Promise<T>): Promise<T> {
        // Check cache
        const cached = this.cache.get(key);
        if (cached && Date.now() - cached.timestamp < this.cacheTimeout) {
            return cached.data as T;
        }

        // Enforce cache size limit
        if (this.cache.size >= this.maxCacheSize) {
            // Remove oldest entry
            const oldestKey = Array.from(this.cache.entries())
                .sort((a, b) => a[1].timestamp - b[1].timestamp)[0][0];
            this.cache.delete(oldestKey);
        }

        // Fetch and cache
        const data = await fetcher();
        this.cache.set(key, { data, timestamp: Date.now() });
        return data;
    }

    clearCache(): void {
        this.cache.clear();
    }
}

export {
    ApiConfig,
    ApiResponse,
    withRetry,
    withTimeout,
    ApiClient,
    ConcurrentRequestHandler,
    DataFetcher
};