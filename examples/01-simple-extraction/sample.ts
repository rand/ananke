// Sample TypeScript file for constraint extraction
// This demonstrates patterns that Clew can detect

/**
 * User authentication handler
 * Implements JWT-based authentication with role validation
 */
export class AuthHandler {
    private readonly tokenExpiry: number = 3600; // 1 hour

    /**
     * Validates user credentials and returns JWT token
     * @param username - User identifier
     * @param password - User password
     * @returns JWT token or null if invalid
     */
    async authenticate(username: string, password: string): Promise<string | null> {
        // Type constraint: Explicit return type
        // Security constraint: Password parameter suggests sensitive data

        if (!username || !password) {
            throw new Error("Username and password required");
        }

        // Validate credentials
        const user = await this.validateCredentials(username, password);

        if (!user) {
            return null;
        }

        // Generate JWT token
        const token = this.generateToken(user.id, user.role);
        return token;
    }

    /**
     * Validates user role for authorization
     * @param token - JWT token
     * @param requiredRole - Minimum required role
     * @returns True if user has required role
     */
    hasRole(token: string, requiredRole: Role): boolean {
        // Type constraint: Enum usage for roles
        // Syntactic constraint: Explicit boolean return

        const decoded = this.decodeToken(token);

        if (!decoded) {
            return false;
        }

        return decoded.role >= requiredRole;
    }

    private async validateCredentials(username: string, password: string): Promise<User | null> {
        // Security constraint: Never log password
        console.log(`Validating credentials for user: ${username}`);

        // Simulate database lookup
        // TODO: Replace with actual database call
        return null;
    }

    private generateToken(userId: string, role: Role): string {
        // Operational constraint: Token must expire
        const expiresAt = Date.now() + (this.tokenExpiry * 1000);

        // Placeholder for actual JWT generation
        return `token-${userId}-${role}-${expiresAt}`;
    }

    private decodeToken(token: string): { id: string; role: Role } | null {
        // Error handling constraint: Must handle invalid tokens
        try {
            // Placeholder for actual JWT decoding
            return null;
        } catch (error) {
            console.error("Token decode failed:", error);
            return null;
        }
    }
}

enum Role {
    User = 0,
    Admin = 1,
    SuperAdmin = 2
}

interface User {
    id: string;
    username: string;
    role: Role;
    email?: string; // Type constraint: Optional field
}

// Architecture constraint: Separate concerns
export class PasswordHasher {
    /**
     * Hash password using bcrypt
     * @param password - Plain text password
     * @returns Hashed password
     */
    async hash(password: string): Promise<string> {
        // Security constraint: Passwords must be hashed
        // Placeholder for bcrypt
        return `hashed-${password}`;
    }

    /**
     * Compare password with hash
     * @param password - Plain text password
     * @param hash - Stored hash
     * @returns True if password matches
     */
    async compare(password: string, hash: string): Promise<boolean> {
        const computed = await this.hash(password);
        return computed === hash;
    }
}
