// TypeScript Small Fixture (target ~100 lines)
// Pattern density: Medium (15-20 constraints)

import { Database } from './database';
import { Logger } from './logger';

interface User {
    id: number;
    name: string;
    email: string;
    isActive: boolean;
    createdAt: Date;
}

interface UserCreateDto {
    name: string;
    email: string;
}

interface UserUpdateDto {
    name?: string;
    email?: string;
    isActive?: boolean;
}

type UserResponse = Promise<User | null>;
type UsersResponse = Promise<User[]>;

class UserService {
    private db: Database;
    private logger: Logger;
    private cache: Map<number, User>;

    constructor(database: Database, logger: Logger) {
        this.db = database;
        this.logger = logger;
        this.cache = new Map();
    }

    async getUser(id: number): UserResponse {
        try {
            // Check cache first
            const cached = this.cache.get(id);
            if (cached) {
                this.logger.debug(`Cache hit for user ${id}`);
                return cached;
            }

            const user = await this.db.query<User>(
                'SELECT * FROM users WHERE id = ?',
                [id]
            );

            if (user) {
                this.cache.set(id, user);
            }

            return user;
        } catch (error) {
            this.logger.error('Failed to fetch user:', error);
            throw new Error('Database error');
        }
    }

    async createUser(dto: UserCreateDto): Promise<User> {
        try {
            const result = await this.db.insert('users', {
                name: dto.name,
                email: dto.email,
                isActive: true,
                createdAt: new Date()
            });

            const user: User = {
                id: result.insertId,
                name: dto.name,
                email: dto.email,
                isActive: true,
                createdAt: new Date()
            };

            this.cache.set(user.id, user);
            this.logger.info(`Created user ${user.id}`);

            return user;
        } catch (error) {
            this.logger.error('Failed to create user:', error);
            throw error;
        }
    }

    async updateUser(id: number, dto: UserUpdateDto): Promise<void> {
        try {
            await this.db.update('users', dto, { id });
            this.cache.delete(id);
            this.logger.info(`Updated user ${id}`);
        } catch (error) {
            this.logger.error('Failed to update user:', error);
            throw error;
        }
    }

    async deleteUser(id: number): Promise<void> {
        await this.db.delete('users', { id });
        this.cache.delete(id);
    }
}

export { UserService, User, UserCreateDto, UserUpdateDto };
