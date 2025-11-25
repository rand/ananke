// Authentication Module Test Fixture
// Tests constraint extraction for:
// - Interface definitions
// - Async functions
// - Error handling patterns
// - Type guards

interface User {
    id: number;
    email: string;
    username: string;
    role: 'admin' | 'user' | 'guest';
    createdAt: Date;
    lastLogin?: Date;
}

interface AuthCredentials {
    email: string;
    password: string;
    rememberMe?: boolean;
}

interface AuthResponse {
    user: User | null;
    token?: string;
    error?: string;
}

// Type guard with constraints
function isValidEmail(email: string): boolean {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email) && email.length <= 255;
}

// Authentication function with validation constraints
async function authenticate(credentials: AuthCredentials): Promise<AuthResponse> {
    // Constraint: Email and password are required
    if (!credentials.email || !credentials.password) {
        throw new Error('Email and password are required');
    }

    // Constraint: Email must be valid format
    if (!isValidEmail(credentials.email)) {
        return {
            user: null,
            error: 'Invalid email format'
        };
    }

    // Constraint: Password minimum length
    if (credentials.password.length < 8) {
        return {
            user: null,
            error: 'Password must be at least 8 characters'
        };
    }

    // Simulate async authentication
    try {
        const response = await fetch('/api/auth', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(credentials)
        });

        if (!response.ok) {
            throw new Error(`Authentication failed: ${response.status}`);
        }

        const data = await response.json();
        return {
            user: data.user,
            token: data.token
        };
    } catch (error) {
        return {
            user: null,
            error: error instanceof Error ? error.message : 'Unknown error'
        };
    }
}

// Session management with constraints
class SessionManager {
    private token: string | null = null;
    private user: User | null = null;
    private readonly maxSessionDuration = 3600000; // 1 hour in milliseconds

    async login(credentials: AuthCredentials): Promise<boolean> {
        const result = await authenticate(credentials);

        if (result.user && result.token) {
            this.user = result.user;
            this.token = result.token;
            this.startSessionTimer();
            return true;
        }

        return false;
    }

    logout(): void {
        this.token = null;
        this.user = null;
    }

    isAuthenticated(): boolean {
        return this.token !== null && this.user !== null;
    }

    getUser(): User | null {
        return this.user;
    }

    private startSessionTimer(): void {
        setTimeout(() => {
            this.logout();
        }, this.maxSessionDuration);
    }
}

// Permission checking with role-based constraints
function hasPermission(user: User, resource: string, action: string): boolean {
    // Admin has all permissions
    if (user.role === 'admin') {
        return true;
    }

    // User has limited permissions
    if (user.role === 'user') {
        return action === 'read' || (action === 'write' && resource === 'profile');
    }

    // Guest has read-only permissions
    if (user.role === 'guest') {
        return action === 'read' && resource !== 'sensitive';
    }

    return false;
}

export {
    User,
    AuthCredentials,
    AuthResponse,
    authenticate,
    SessionManager,
    hasPermission,
    isValidEmail
};