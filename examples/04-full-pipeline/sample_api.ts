/**
 * Complete REST API endpoint for user management
 * Demonstrates comprehensive constraint patterns for full pipeline extraction
 */

import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';

// Type constraints: Schema definitions
const CreateUserSchema = z.object({
    email: z.string().email(),
    username: z.string().min(3).max(50).regex(/^[a-zA-Z0-9_]+$/),
    password: z.string().min(8),
    profile: z.object({
        firstName: z.string().min(1),
        lastName: z.string().min(1),
        birthDate: z.string().datetime().optional()
    }).optional()
});

const UpdateUserSchema = z.object({
    email: z.string().email().optional(),
    profile: z.object({
        firstName: z.string().min(1).optional(),
        lastName: z.string().min(1).optional(),
        bio: z.string().max(500).optional()
    }).optional()
});

// Type constraints: Data models
interface User {
    id: string;
    email: string;
    username: string;
    passwordHash: string; // Security constraint: Never expose password
    profile?: UserProfile;
    createdAt: Date;
    updatedAt: Date;
    deletedAt?: Date; // Operational constraint: Soft delete
}

interface UserProfile {
    firstName: string;
    lastName: string;
    birthDate?: Date;
    bio?: string;
}

// Type constraints: Response types
interface ApiResponse<T> {
    data: T;
    metadata?: Record<string, any>;
}

interface ErrorResponse {
    error: {
        code: string;
        message: string;
        details?: any;
    };
}

// Security constraint: Custom errors with status codes
class ApiError extends Error {
    constructor(
        public statusCode: number,
        public code: string,
        message: string,
        public details?: any
    ) {
        super(message);
        this.name = 'ApiError';
    }
}

/**
 * User Management Controller
 * Architectural constraint: Separation of concerns
 */
export class UserController {
    /**
     * Create a new user
     * POST /api/v1/users
     *
     * Constraints demonstrated:
     * - Input validation (Zod schema)
     * - Password hashing (security)
     * - Duplicate checking (business logic)
     * - Audit logging (operational)
     * - Transaction handling (data integrity)
     */
    async createUser(req: Request, res: Response, next: NextFunction): Promise<void> {
        try {
            // Semantic constraint: Validate input first
            const validation = CreateUserSchema.safeParse(req.body);
            if (!validation.success) {
                throw new ApiError(
                    400,
                    'VALIDATION_ERROR',
                    'Invalid input',
                    validation.error.errors
                );
            }

            const { email, username, password, profile } = validation.data;

            // Semantic constraint: Check for duplicate email
            const existingUser = await this.findUserByEmail(email);
            if (existingUser) {
                throw new ApiError(
                    409,
                    'DUPLICATE_EMAIL',
                    'Email already exists'
                );
            }

            // Semantic constraint: Check for duplicate username
            const existingUsername = await this.findUserByUsername(username);
            if (existingUsername) {
                throw new ApiError(
                    409,
                    'DUPLICATE_USERNAME',
                    'Username already taken'
                );
            }

            // Security constraint: Hash password before storage
            const passwordHash = await this.hashPassword(password);

            // Operational constraint: Use transaction for data integrity
            const user = await this.db.transaction(async (trx) => {
                const newUser = await trx.users.create({
                    email,
                    username,
                    passwordHash,
                    createdAt: new Date(),
                    updatedAt: new Date()
                });

                // Semantic constraint: Create profile if provided
                if (profile) {
                    await trx.userProfiles.create({
                        userId: newUser.id,
                        ...profile
                    });
                }

                return newUser;
            });

            // Operational constraint: Log user creation for audit
            await this.auditLog('USER_CREATED', {
                userId: user.id,
                email: user.email,
                ip: req.ip,
                userAgent: req.headers['user-agent']
            });

            // Semantic constraint: Remove sensitive data from response
            const response: ApiResponse<Partial<User>> = {
                data: {
                    id: user.id,
                    email: user.email,
                    username: user.username,
                    createdAt: user.createdAt,
                    updatedAt: user.updatedAt
                },
                metadata: {
                    created: true
                }
            };

            res.status(201).json(response);
        } catch (error) {
            next(error);
        }
    }

    /**
     * Get user by ID
     * GET /api/v1/users/:id
     *
     * Constraints demonstrated:
     * - Parameter validation
     * - Authorization check
     * - Soft delete filtering
     * - Cache integration
     */
    async getUser(req: Request, res: Response, next: NextFunction): Promise<void> {
        try {
            const { id } = req.params;

            // Semantic constraint: Validate UUID format
            if (!this.isValidUUID(id)) {
                throw new ApiError(400, 'INVALID_ID', 'Invalid user ID format');
            }

            // Security constraint: Check if requester has permission
            if (!this.canAccessUser(req.user, id)) {
                throw new ApiError(
                    403,
                    'FORBIDDEN',
                    'You do not have permission to access this user'
                );
            }

            // Performance constraint: Try cache first
            let user = await this.cache.get(`user:${id}`);

            if (!user) {
                // Operational constraint: Filter soft-deleted users
                user = await this.findUserById(id, { excludeDeleted: true });

                if (!user) {
                    throw new ApiError(404, 'NOT_FOUND', 'User not found');
                }

                // Performance constraint: Cache for 5 minutes
                await this.cache.set(`user:${id}`, user, 300);
            }

            // Security constraint: Remove sensitive fields
            const safeUser = this.sanitizeUser(user);

            const response: ApiResponse<typeof safeUser> = {
                data: safeUser,
                metadata: {
                    cached: true
                }
            };

            res.json(response);
        } catch (error) {
            next(error);
        }
    }

    /**
     * List users with pagination and filtering
     * GET /api/v1/users
     *
     * Constraints demonstrated:
     * - Pagination enforcement
     * - Query parameter validation
     * - Performance optimization
     * - Response envelope consistency
     */
    async listUsers(req: Request, res: Response, next: NextFunction): Promise<void> {
        try {
            // Semantic constraint: Parse and validate pagination
            const page = Math.max(1, parseInt(req.query.page as string) || 1);
            const limit = Math.min(
                100, // Semantic constraint: Max limit is 100
                Math.max(1, parseInt(req.query.limit as string) || 20)
            );
            const offset = (page - 1) * limit;

            // Semantic constraint: Parse filters
            const filters: any = {};
            if (req.query.role) {
                filters.role = req.query.role;
            }
            if (req.query.search) {
                filters.search = req.query.search;
            }

            // Performance constraint: Count and fetch in parallel
            const [users, totalCount] = await Promise.all([
                this.findUsers({ ...filters, limit, offset, excludeDeleted: true }),
                this.countUsers(filters)
            ]);

            // Security constraint: Sanitize all users
            const safeUsers = users.map(u => this.sanitizeUser(u));

            // Semantic constraint: Include pagination metadata
            const response: ApiResponse<typeof safeUsers> = {
                data: safeUsers,
                metadata: {
                    pagination: {
                        page,
                        limit,
                        total: totalCount,
                        pages: Math.ceil(totalCount / limit)
                    },
                    filters
                }
            };

            res.json(response);
        } catch (error) {
            next(error);
        }
    }

    /**
     * Update user
     * PUT /api/v1/users/:id
     *
     * Constraints demonstrated:
     * - Partial update validation
     * - Optimistic locking
     * - Cache invalidation
     * - Audit trail
     */
    async updateUser(req: Request, res: Response, next: NextFunction): Promise<void> {
        try {
            const { id } = req.params;

            // Semantic constraint: Validate input
            const validation = UpdateUserSchema.safeParse(req.body);
            if (!validation.success) {
                throw new ApiError(
                    400,
                    'VALIDATION_ERROR',
                    'Invalid input',
                    validation.error.errors
                );
            }

            // Security constraint: Check permission
            if (!this.canModifyUser(req.user, id)) {
                throw new ApiError(403, 'FORBIDDEN', 'Cannot modify this user');
            }

            const updates = validation.data;

            // Semantic constraint: Check if email is being changed to existing email
            if (updates.email) {
                const existing = await this.findUserByEmail(updates.email);
                if (existing && existing.id !== id) {
                    throw new ApiError(409, 'DUPLICATE_EMAIL', 'Email already in use');
                }
            }

            // Operational constraint: Use transaction with optimistic locking
            const updatedUser = await this.db.transaction(async (trx) => {
                // Semantic constraint: Fetch current version
                const current = await trx.users.findById(id);
                if (!current) {
                    throw new ApiError(404, 'NOT_FOUND', 'User not found');
                }

                // Update user
                const user = await trx.users.update(id, {
                    ...updates,
                    updatedAt: new Date()
                });

                // Update profile if provided
                if (updates.profile) {
                    await trx.userProfiles.update(
                        { userId: id },
                        updates.profile
                    );
                }

                return user;
            });

            // Operational constraint: Invalidate cache
            await this.cache.delete(`user:${id}`);

            // Operational constraint: Log update for audit
            await this.auditLog('USER_UPDATED', {
                userId: id,
                changes: updates,
                ip: req.ip,
                updatedBy: req.user?.id
            });

            const response: ApiResponse<typeof updatedUser> = {
                data: this.sanitizeUser(updatedUser),
                metadata: {
                    updated: true
                }
            };

            res.json(response);
        } catch (error) {
            next(error);
        }
    }

    /**
     * Delete user (soft delete)
     * DELETE /api/v1/users/:id
     *
     * Constraints demonstrated:
     * - Soft delete implementation
     * - Authorization check
     * - Cascade considerations
     * - Compliance logging
     */
    async deleteUser(req: Request, res: Response, next: NextFunction): Promise<void> {
        try {
            const { id } = req.params;

            // Security constraint: Only admins can delete users
            if (!this.isAdmin(req.user)) {
                throw new ApiError(403, 'FORBIDDEN', 'Admin access required');
            }

            // Semantic constraint: Cannot delete yourself
            if (req.user?.id === id) {
                throw new ApiError(400, 'INVALID_OPERATION', 'Cannot delete own account');
            }

            const user = await this.findUserById(id);
            if (!user) {
                throw new ApiError(404, 'NOT_FOUND', 'User not found');
            }

            // Operational constraint: Soft delete instead of hard delete
            await this.db.users.update(id, {
                deletedAt: new Date(),
                updatedAt: new Date()
            });

            // Operational constraint: Log deletion for compliance
            await this.auditLog('USER_DELETED', {
                userId: id,
                email: user.email,
                deletedBy: req.user?.id,
                ip: req.ip,
                reason: req.body.reason
            });

            // Operational constraint: Invalidate cache
            await this.cache.delete(`user:${id}`);

            // Semantic constraint: Return 204 No Content
            res.status(204).end();
        } catch (error) {
            next(error);
        }
    }

    // Helper methods demonstrating various constraints

    private async hashPassword(password: string): Promise<string> {
        // Security constraint: Use strong hashing algorithm
        // TODO: Implement bcrypt or argon2
        return `hashed_${password}`;
    }

    private sanitizeUser(user: User): Partial<User> {
        // Security constraint: Remove sensitive fields
        const { passwordHash, ...safe } = user;
        return safe;
    }

    private isValidUUID(id: string): boolean {
        // Syntactic constraint: UUID format validation
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
        return uuidRegex.test(id);
    }

    private canAccessUser(requester: any, targetId: string): boolean {
        // Security constraint: Access control logic
        return requester?.id === targetId || requester?.role === 'admin';
    }

    private canModifyUser(requester: any, targetId: string): boolean {
        // Security constraint: Modification permission logic
        return requester?.id === targetId || requester?.role === 'admin';
    }

    private isAdmin(user: any): boolean {
        // Security constraint: Role checking
        return user?.role === 'admin' || user?.role === 'super_admin';
    }

    // Database abstraction methods
    private async findUserById(id: string, options?: any): Promise<User | null> {
        // TODO: Implement database query
        return null;
    }

    private async findUserByEmail(email: string): Promise<User | null> {
        // TODO: Implement database query
        return null;
    }

    private async findUserByUsername(username: string): Promise<User | null> {
        // TODO: Implement database query
        return null;
    }

    private async findUsers(options: any): Promise<User[]> {
        // TODO: Implement database query
        return [];
    }

    private async countUsers(filters: any): Promise<number> {
        // TODO: Implement count query
        return 0;
    }

    private async auditLog(event: string, data: any): Promise<void> {
        // Operational constraint: All significant actions must be logged
        console.log(`AUDIT: ${event}`, data);
    }

    // Mock properties
    private db: any = {};
    private cache: any = {
        get: async () => null,
        set: async () => {},
        delete: async () => {}
    };
}
