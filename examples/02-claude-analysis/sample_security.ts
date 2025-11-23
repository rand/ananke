/**
 * Security-critical authentication and authorization module
 * Demonstrates patterns requiring semantic analysis to understand security constraints
 *
 * Key security constraints that Claude can identify:
 * - Rate limiting on authentication attempts
 * - Session expiration policies
 * - Token rotation requirements
 * - Audit logging requirements
 * - Role-based access control semantics
 */

import { createHash, randomBytes } from 'crypto';
import { EventEmitter } from 'events';

// Security constraint: Password must never be stored in plain text
interface User {
    id: string;
    email: string;
    passwordHash: string; // Semantic: "Hash" suffix indicates secure storage
    salt: string;
    role: UserRole;
    mfaEnabled: boolean;
    mfaSecret?: string;
    failedLoginAttempts: number; // Semantic: Track for rate limiting
    lastLoginAttempt?: Date;
    accountLockedUntil?: Date; // Semantic: Temporary lockout
    sessionVersion: number; // Semantic: For invalidating all sessions
}

enum UserRole {
    User = 'user',
    Moderator = 'moderator',
    Admin = 'admin',
    SuperAdmin = 'super_admin'
}

// Security constraint: Sessions must expire
interface Session {
    sessionId: string;
    userId: string;
    createdAt: Date;
    expiresAt: Date; // Semantic: Sessions must have expiration
    lastActivityAt: Date; // Semantic: Track for idle timeout
    ipAddress: string; // Semantic: For security auditing
    userAgent: string; // Semantic: For device tracking
    refreshToken: string; // Semantic: For token rotation
    refreshTokenExpiresAt: Date;
}

// Security constraint: Audit all security events
interface SecurityEvent {
    eventType: 'login' | 'logout' | 'failed_login' | 'password_change' | 'role_change' | 'mfa_enabled' | 'session_invalidated';
    userId: string;
    timestamp: Date;
    ipAddress: string;
    userAgent: string;
    details: Record<string, any>;
    severity: 'low' | 'medium' | 'high' | 'critical';
}

/**
 * Secure authentication service with comprehensive security constraints
 *
 * Business rules (semantic constraints requiring Claude analysis):
 * 1. After 5 failed login attempts, lock account for 15 minutes
 * 2. Sessions expire after 1 hour of inactivity
 * 3. Refresh tokens expire after 30 days
 * 4. Password changes invalidate all existing sessions
 * 5. Admin actions must be logged with high severity
 * 6. MFA is required for admin and super_admin roles
 * 7. IP address changes during session require re-authentication
 * 8. Tokens must be rotated on each refresh
 */
export class SecureAuthService extends EventEmitter {
    private readonly MAX_FAILED_ATTEMPTS = 5;
    private readonly LOCKOUT_DURATION_MS = 15 * 60 * 1000; // 15 minutes
    private readonly SESSION_DURATION_MS = 60 * 60 * 1000; // 1 hour
    private readonly IDLE_TIMEOUT_MS = 30 * 60 * 1000; // 30 minutes
    private readonly REFRESH_TOKEN_DURATION_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

    private users: Map<string, User> = new Map();
    private sessions: Map<string, Session> = new Map();
    private auditLog: SecurityEvent[] = [];

    /**
     * Authenticate user with email and password
     *
     * Semantic constraints:
     * - Must check if account is locked
     * - Must increment failed attempts on failure
     * - Must reset failed attempts on success
     * - Must create audit log entry
     * - Must enforce MFA if enabled
     */
    async authenticate(
        email: string,
        password: string,
        ipAddress: string,
        userAgent: string,
        mfaToken?: string
    ): Promise<{ session?: Session; requiresMfa?: boolean; error?: string }> {
        // Security constraint: Log all authentication attempts
        console.log(`Authentication attempt for ${email} from ${ipAddress}`);

        const user = await this.findUserByEmail(email);

        if (!user) {
            // Security constraint: Don't reveal if user exists
            await this.logSecurityEvent({
                eventType: 'failed_login',
                userId: 'unknown',
                timestamp: new Date(),
                ipAddress,
                userAgent,
                details: { email, reason: 'user_not_found' },
                severity: 'medium'
            });
            return { error: 'Invalid credentials' };
        }

        // Semantic constraint: Check if account is locked
        if (user.accountLockedUntil && user.accountLockedUntil > new Date()) {
            const remainingMs = user.accountLockedUntil.getTime() - Date.now();
            const remainingMinutes = Math.ceil(remainingMs / 60000);

            await this.logSecurityEvent({
                eventType: 'failed_login',
                userId: user.id,
                timestamp: new Date(),
                ipAddress,
                userAgent,
                details: { reason: 'account_locked', remaining_minutes: remainingMinutes },
                severity: 'high'
            });

            return { error: `Account locked. Try again in ${remainingMinutes} minutes.` };
        }

        // Security constraint: Verify password using constant-time comparison
        const isValidPassword = await this.verifyPassword(password, user.passwordHash, user.salt);

        if (!isValidPassword) {
            // Semantic constraint: Track failed attempts
            user.failedLoginAttempts += 1;
            user.lastLoginAttempt = new Date();

            // Semantic constraint: Lock account after threshold
            if (user.failedLoginAttempts >= this.MAX_FAILED_ATTEMPTS) {
                user.accountLockedUntil = new Date(Date.now() + this.LOCKOUT_DURATION_MS);

                await this.logSecurityEvent({
                    eventType: 'failed_login',
                    userId: user.id,
                    timestamp: new Date(),
                    ipAddress,
                    userAgent,
                    details: { reason: 'account_locked_due_to_attempts', attempts: user.failedLoginAttempts },
                    severity: 'critical'
                });

                // Security constraint: Notify user of account lockout
                this.emit('account_locked', { userId: user.id, email: user.email });

                return { error: 'Account locked due to multiple failed attempts' };
            }

            await this.logSecurityEvent({
                eventType: 'failed_login',
                userId: user.id,
                timestamp: new Date(),
                ipAddress,
                userAgent,
                details: { attempts: user.failedLoginAttempts },
                severity: 'medium'
            });

            return { error: 'Invalid credentials' };
        }

        // Semantic constraint: MFA required for privileged roles
        if (user.mfaEnabled || this.requiresMfaForRole(user.role)) {
            if (!mfaToken) {
                return { requiresMfa: true };
            }

            const isValidMfa = await this.verifyMfaToken(user.mfaSecret!, mfaToken);
            if (!isValidMfa) {
                await this.logSecurityEvent({
                    eventType: 'failed_login',
                    userId: user.id,
                    timestamp: new Date(),
                    ipAddress,
                    userAgent,
                    details: { reason: 'invalid_mfa' },
                    severity: 'high'
                });
                return { error: 'Invalid MFA token' };
            }
        }

        // Semantic constraint: Reset failed attempts on successful login
        user.failedLoginAttempts = 0;
        user.accountLockedUntil = undefined;

        // Create session with security constraints
        const session = await this.createSession(user, ipAddress, userAgent);

        await this.logSecurityEvent({
            eventType: 'login',
            userId: user.id,
            timestamp: new Date(),
            ipAddress,
            userAgent,
            details: { sessionId: session.sessionId },
            severity: 'low'
        });

        return { session };
    }

    /**
     * Validate existing session
     *
     * Semantic constraints:
     * - Must check session expiration
     * - Must check idle timeout
     * - Must verify IP address hasn't changed
     * - Must update last activity timestamp
     */
    async validateSession(
        sessionId: string,
        ipAddress: string
    ): Promise<{ valid: boolean; user?: User; error?: string }> {
        const session = this.sessions.get(sessionId);

        if (!session) {
            return { valid: false, error: 'Session not found' };
        }

        // Semantic constraint: Check if session expired
        if (session.expiresAt < new Date()) {
            this.sessions.delete(sessionId);
            return { valid: false, error: 'Session expired' };
        }

        // Semantic constraint: Check idle timeout
        const idleTime = Date.now() - session.lastActivityAt.getTime();
        if (idleTime > this.IDLE_TIMEOUT_MS) {
            this.sessions.delete(sessionId);
            return { valid: false, error: 'Session timed out due to inactivity' };
        }

        // Security constraint: Verify IP address matches
        if (session.ipAddress !== ipAddress) {
            await this.logSecurityEvent({
                eventType: 'session_invalidated',
                userId: session.userId,
                timestamp: new Date(),
                ipAddress,
                userAgent: session.userAgent,
                details: {
                    reason: 'ip_mismatch',
                    original_ip: session.ipAddress,
                    new_ip: ipAddress
                },
                severity: 'critical'
            });

            this.sessions.delete(sessionId);
            return { valid: false, error: 'IP address mismatch - please re-authenticate' };
        }

        // Semantic constraint: Update activity timestamp
        session.lastActivityAt = new Date();

        const user = this.users.get(session.userId);
        if (!user) {
            return { valid: false, error: 'User not found' };
        }

        return { valid: true, user };
    }

    /**
     * Refresh session using refresh token
     *
     * Semantic constraints:
     * - Must validate refresh token
     * - Must rotate both session and refresh tokens
     * - Must extend expiration times
     */
    async refreshSession(
        sessionId: string,
        refreshToken: string,
        ipAddress: string
    ): Promise<{ session?: Session; error?: string }> {
        const oldSession = this.sessions.get(sessionId);

        if (!oldSession) {
            return { error: 'Session not found' };
        }

        // Security constraint: Verify refresh token
        if (oldSession.refreshToken !== refreshToken) {
            await this.logSecurityEvent({
                eventType: 'session_invalidated',
                userId: oldSession.userId,
                timestamp: new Date(),
                ipAddress,
                userAgent: oldSession.userAgent,
                details: { reason: 'invalid_refresh_token' },
                severity: 'critical'
            });

            this.sessions.delete(sessionId);
            return { error: 'Invalid refresh token' };
        }

        // Semantic constraint: Check refresh token expiration
        if (oldSession.refreshTokenExpiresAt < new Date()) {
            this.sessions.delete(sessionId);
            return { error: 'Refresh token expired' };
        }

        const user = this.users.get(oldSession.userId);
        if (!user) {
            return { error: 'User not found' };
        }

        // Semantic constraint: Invalidate old session
        this.sessions.delete(sessionId);

        // Semantic constraint: Create new session with rotated tokens
        const newSession = await this.createSession(user, ipAddress, oldSession.userAgent);

        return { session: newSession };
    }

    /**
     * Change user password
     *
     * Semantic constraints:
     * - Must verify old password
     * - Must invalidate all existing sessions
     * - Must create high-severity audit log
     * - Must notify user of password change
     */
    async changePassword(
        userId: string,
        oldPassword: string,
        newPassword: string,
        ipAddress: string
    ): Promise<{ success: boolean; error?: string }> {
        const user = this.users.get(userId);
        if (!user) {
            return { success: false, error: 'User not found' };
        }

        // Security constraint: Verify old password
        const isValid = await this.verifyPassword(oldPassword, user.passwordHash, user.salt);
        if (!isValid) {
            return { success: false, error: 'Invalid current password' };
        }

        // Security constraint: Generate new salt for password
        const salt = this.generateSalt();
        user.salt = salt;
        user.passwordHash = await this.hashPassword(newPassword, salt);

        // Semantic constraint: Increment session version to invalidate all sessions
        user.sessionVersion += 1;

        // Semantic constraint: Delete all existing sessions
        for (const [sessionId, session] of this.sessions.entries()) {
            if (session.userId === userId) {
                this.sessions.delete(sessionId);
            }
        }

        await this.logSecurityEvent({
            eventType: 'password_change',
            userId,
            timestamp: new Date(),
            ipAddress,
            userAgent: '',
            details: { all_sessions_invalidated: true },
            severity: 'high'
        });

        // Security constraint: Notify user of password change
        this.emit('password_changed', { userId, email: user.email });

        return { success: true };
    }

    // Private helper methods

    private async createSession(user: User, ipAddress: string, userAgent: string): Promise<Session> {
        const sessionId = this.generateSecureToken();
        const refreshToken = this.generateSecureToken();

        const session: Session = {
            sessionId,
            userId: user.id,
            createdAt: new Date(),
            expiresAt: new Date(Date.now() + this.SESSION_DURATION_MS),
            lastActivityAt: new Date(),
            ipAddress,
            userAgent,
            refreshToken,
            refreshTokenExpiresAt: new Date(Date.now() + this.REFRESH_TOKEN_DURATION_MS)
        };

        this.sessions.set(sessionId, session);
        return session;
    }

    private requiresMfaForRole(role: UserRole): boolean {
        // Semantic constraint: Privileged roles require MFA
        return role === UserRole.Admin || role === UserRole.SuperAdmin;
    }

    private async verifyPassword(password: string, hash: string, salt: string): Promise<boolean> {
        const computed = await this.hashPassword(password, salt);
        // Security constraint: Use constant-time comparison
        return this.constantTimeEqual(computed, hash);
    }

    private async hashPassword(password: string, salt: string): Promise<string> {
        // Security constraint: Use strong hashing algorithm
        return createHash('sha256').update(password + salt).digest('hex');
        // TODO: Use bcrypt or argon2 in production
    }

    private generateSalt(): string {
        return randomBytes(16).toString('hex');
    }

    private generateSecureToken(): string {
        return randomBytes(32).toString('hex');
    }

    private constantTimeEqual(a: string, b: string): boolean {
        // Security constraint: Prevent timing attacks
        if (a.length !== b.length) return false;
        let result = 0;
        for (let i = 0; i < a.length; i++) {
            result |= a.charCodeAt(i) ^ b.charCodeAt(i);
        }
        return result === 0;
    }

    private async verifyMfaToken(secret: string, token: string): Promise<boolean> {
        // TODO: Implement TOTP verification
        return true;
    }

    private async findUserByEmail(email: string): Promise<User | undefined> {
        for (const user of this.users.values()) {
            if (user.email === email) {
                return user;
            }
        }
        return undefined;
    }

    private async logSecurityEvent(event: SecurityEvent): Promise<void> {
        this.auditLog.push(event);
        // Semantic constraint: High severity events trigger alerts
        if (event.severity === 'high' || event.severity === 'critical') {
            this.emit('security_alert', event);
        }
    }
}
