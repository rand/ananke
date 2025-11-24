// TypeScript Sample File
// This file tests various TypeScript patterns for constraint extraction

import { Database } from './database';
import * as utils from './utils';

// Interface definition with type annotations
interface User {
    id: number;
    name: string;
    email: string;
    isActive: boolean;
}

// Type alias for complex types
type UserResponse = Promise<User | null>;

// Class with inheritance and implementation
class UserService implements IUserService {
    private db: Database;

    constructor(database: Database) {
        this.db = database;
    }

    // Async function with Promise return type
    async getUser(id: number): Promise<User | null> {
        try {
            const user = await this.db.query('SELECT * FROM users WHERE id = ?', [id]);
            return user as User;
        } catch (error) {
            console.error('Failed to fetch user:', error);
            throw new Error('Database error');
        }
    }

    // Function with type annotations
    async createUser(name: string, email: string): Promise<User> {
        try {
            const result = await this.db.insert('users', { name, email, isActive: true });
            return {
                id: result.insertId,
                name,
                email,
                isActive: true
            };
        } catch (error) {
            throw error;
        } finally {
            console.log('Create user operation completed');
        }
    }

    // Arrow function with type annotations
    updateUser = async (id: number, updates: Partial<User>): Promise<void> => {
        await this.db.update('users', updates, { id });
    };
}

// Decorator (if using experimental decorators)
function Logger(target: any) {
    console.log('Class:', target);
}

@Logger
class LoggedService {
    async doSomething(): Promise<string> {
        return 'done';
    }
}

// Export statements
export { UserService, User };
export default UserService;
