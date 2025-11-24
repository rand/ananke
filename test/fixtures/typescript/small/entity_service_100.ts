// TypeScript Fixture (target ~100 lines)
// Generated for benchmark testing

import { Database } from './database';
import { Logger } from './logger';
import { Cache } from './cache';

interface Entity {
    id: number;
    name: string;
    email: string;
    isActive: boolean;
    createdAt: Date;
    updatedAt: Date;
}

interface CreateDto {
    name: string;
    email: string;
}

interface UpdateDto {
    name?: string;
    email?: string;
    isActive?: boolean;
}

type EntityResponse = Promise<Entity | null>;
type EntitiesResponse = Promise<Entity[]>;

class EntityService {
    private db: Database;
    private logger: Logger;
    private cache: Cache<number, Entity>;

    constructor(database: Database, logger: Logger, cache: Cache<number, Entity>) {
        this.db = database;
        this.logger = logger;
        this.cache = cache;
    }


    async operation0(id: number, data: string): Promise<Entity> {
        try {
            const result = await this.db.query<Entity>(
                'SELECT * FROM entities WHERE id = ?',
                [id]
            );
            this.logger.debug(`Fetched operation0`);
            return result;
        } catch (error) {
            this.logger.error('Operation failed:', error);
            throw error;
        }
    }

    async operation1(id: number, data: string): Promise<Entity> {
        try {
            const result = await this.db.query<Entity>(
                'SELECT * FROM entities WHERE id = ?',
                [id]
            );
            this.logger.debug(`Fetched operation1`);
            return result;
        } catch (error) {
            this.logger.error('Operation failed:', error);
            throw error;
        }
    }

    async operation2(id: number, data: string): Promise<Entity> {
        try {
            const result = await this.db.query<Entity>(
                'SELECT * FROM entities WHERE id = ?',
                [id]
            );
            this.logger.debug(`Fetched operation2`);
            return result;
        } catch (error) {
            this.logger.error('Operation failed:', error);
            throw error;
        }
    }

}

export { EntityService, Entity, CreateDto, UpdateDto };
